# Search Infrastructure

Planet's search system combines three retrieval strategies — BM25 full-text search, vector semantic search, and the original in-memory substring fallback — fused into a single ranked result list via Reciprocal Rank Fusion. All indexing runs off the main thread; all data lives in a single WAL-mode SQLite database.

## Architecture Overview

```
User Query
    |
    +---> SearchIndex (FTS5 / BM25)  ----+
    |          db.read                   |
    |                                    +---> HybridSearch.fuse() ---> [SearchResult]
    +---> SearchEmbedding (NLEmbedding) -+
    |          db.read
    |
    +---> (fallback) in-memory snapshot search
               if both FTS5 and vector return empty
```

BM25 and vector search run concurrently via `async let` + `Task.detached`. Results are fused by `HybridSearch.fuse()`. If both return empty (e.g. first launch before index is built), the original in-memory `cachedSearchSnapshots` path is used as fallback.

## Files

| File | Role |
|------|------|
| `Planet/Search/SearchDatabase.swift` | Shared `DatabasePool`, schema migrations, content hash |
| `Planet/Search/SearchIndex.swift` | FTS5 indexing, BM25 search, query sanitization, snippet extraction |
| `Planet/Search/SearchEmbedding.swift` | NLEmbedding vectors, cosine similarity search |
| `Planet/Search/HybridSearch.swift` | Reciprocal Rank Fusion of BM25 + vector results |
| `Planet/Search/PlanetStore+Search.swift` | Lifecycle hooks, search entry point, in-memory fallback |
| `Planet/Entities/SearchResult.swift` | `SearchResult` struct with optional `relevanceScore` |

## Dependencies

| Dependency | What | License |
|-----------|------|---------|
| [GRDB.swift](https://github.com/groue/GRDB.swift) 7.5+ | SQLite wrapper with FTS5 and `DatabasePool` | MIT |
| `NaturalLanguage.framework` | Apple's on-device `NLEmbedding` for sentence vectors | macOS system framework |

No network calls, no model downloads, no API keys. Everything runs on-device.

## Database

Single SQLite file at `~/.config/Planet/search.sqlite`, opened as a `DatabasePool` in WAL mode.

### Tables

**`articles`** — content table mirroring article metadata for search.

| Column | Type | Notes |
|--------|------|-------|
| `rowid` | INTEGER PRIMARY KEY | Auto-increment, used by FTS5 `content_rowid` |
| `article_id` | TEXT UNIQUE NOT NULL | UUID string |
| `planet_id` | TEXT NOT NULL | UUID string |
| `planet_name` | TEXT NOT NULL | |
| `planet_kind` | INTEGER NOT NULL | 0 = my, 1 = following |
| `title` | TEXT NOT NULL | |
| `content` | TEXT NOT NULL | Full markdown body |
| `preview_text` | TEXT | Article summary, nullable |
| `slug` | TEXT | |
| `tags` | TEXT | Comma-separated |
| `attachments` | TEXT | Comma-separated |
| `created_at` | REAL NOT NULL | `timeIntervalSinceReferenceDate` |
| `content_hash` | TEXT NOT NULL | DJB2 hash of `title + "\n" + content` — skip re-index when unchanged |

**`articles_fts`** — FTS5 virtual table for full-text search.

```sql
CREATE VIRTUAL TABLE articles_fts USING fts5(
    title, content, tags, slug,
    content='articles',
    content_rowid='rowid',
    tokenize='unicode61 remove_diacritics 2'
)
```

Kept in sync via `AFTER INSERT/UPDATE/DELETE` triggers on `articles`. Column order matters for `bm25()` weight arguments.

**`vectors`** — embedding storage for semantic search.

| Column | Type | Notes |
|--------|------|-------|
| `article_id` | TEXT PRIMARY KEY | UUID string, references `articles.article_id` |
| `embedding` | BLOB NOT NULL | 512 x Float32 = 2048 bytes per article |
| `content_hash` | TEXT NOT NULL | Same hash as `articles.content_hash` |

### Migration

All tables, triggers, and virtual tables are created in a single `v1_create_tables` migration inside `SearchDatabase.migrate()`. This runs once during `SearchDatabase.init()`, before either `SearchIndex` or `SearchEmbedding` is accessed. This guarantees table existence regardless of singleton initialization order.

## SearchIndex — BM25 Full-Text Search

### Indexing

`SearchIndex.upsert(snapshot:)` checks the `content_hash` — if unchanged, skips the write entirely. Otherwise performs an `INSERT ... ON CONFLICT DO UPDATE` which fires the FTS5 sync triggers.

`SearchIndex.rebuild(snapshots:)` runs the full clear + re-insert in a **single `db.write` transaction**. This means concurrent `db.read` calls (from search) see either the complete old index or the complete new index — never a partially rebuilt state. WAL snapshot isolation guarantees this.

### Search

```swift
SearchIndex.shared.search(query: "connection pool")
```

Runs an FTS5 `MATCH` query with `bm25()` ranking. Column weights:

| Column | Weight | Rationale |
|--------|--------|-----------|
| title | 10.0 | Title matches are highest signal |
| content | 1.0 | Body text, baseline weight |
| tags | 5.0 | Tag matches are strong signal |
| slug | 3.0 | URL-friendly title, moderate signal |

Results are ordered by BM25 rank (lower = better match, negated to positive for `relevanceScore`).

### Query Sanitization

Plain queries are transformed for type-ahead: each word becomes `"word"*` (quoted prefix match with implicit AND). FTS5 syntax is passed through when detected — users can type `"exact phrase"`, `prefix*`, `-negation`, or `term1 OR term2`.

### Snippet Extraction

`SearchIndex.makeSnippet()` finds the best 300-character window in the content by sliding a window (50-char step) and scoring query term density via case-insensitive, diacritic-insensitive matching. The window with the highest term count wins. Output is snapped to word boundaries with `…` ellipsis.

## SearchEmbedding — Vector Semantic Search

### Embedding Generation

Uses `NLEmbedding.sentenceEmbedding(for: .english)` from Apple's NaturalLanguage framework. Input is `title + ". " + content` (truncated to 2000 chars). Returns a 512-dimensional `[Double]` vector, stored as `[Float32]` blob (2048 bytes per article).

### Search — Two-Phase

1. **Phase 1:** Load only `article_id` + `embedding` blob from `vectors` table. Compute cosine similarity against the query embedding in memory. Filter by minimum threshold (0.3). Sort and keep top-K.
2. **Phase 2:** Fetch full metadata (`title`, `content`, `preview_text`, etc.) from `articles` table only for the top-K article IDs.

This avoids loading megabytes of article content for articles that will be discarded by the similarity threshold.

### Cosine Similarity

Standard dot-product / (norm_a * norm_b). Computed in plain Swift over `[Double]` arrays. For thousands of 512-dim vectors this is fast (< 10ms).

## HybridSearch — Reciprocal Rank Fusion

```swift
HybridSearch.fuse(bm25Results: [...], vectorResults: [...])
```

Each result list contributes a score per article:

```
score(article) = Σ weight / (k + rank)
```

Where `k = 60`, BM25 weight = 1.5, vector weight = 1.0. Articles appearing in both lists get the sum of their contributions. BM25's keyword-aware snippet is preferred when an article appears in both.

## Lifecycle Integration

### App Launch

`PlanetStore.init()` calls `rebuildSearchSnapshots()` which:
1. Builds `cachedSearchSnapshots` from all planets (MainActor)
2. Enqueues a full FTS + embedding rebuild on the serial write queue

### Article Save

`MyArticleModel.save()` and `FollowingArticleModel.save()` call `PlanetStore.upsertSearchSnapshotIfReady(for:)` which:
1. Creates a `SearchArticleSnapshot` (value type, `Sendable`)
2. Enqueues FTS upsert + embedding on the serial write queue — does not block `save()`
3. Updates in-memory `cachedSearchSnapshots` on MainActor

### Article Delete

`MyArticleModel.delete()` and `FollowingArticleModel.delete()` call `PlanetStore.removeSearchSnapshotIfReady(articleID:)` which:
1. Enqueues FTS + embedding removal on the serial write queue
2. Removes from in-memory cache on MainActor

### Planet Change

`myPlanets.didSet` and `followingPlanets.didSet` trigger `rebuildSearchSnapshots()` which enqueues a full index rebuild.

## Write Ordering

All index mutations — upsert, remove, and full rebuild — are dispatched to `SearchDatabase.writeQueue`, a serial `DispatchQueue`. This guarantees FIFO execution: a removal dispatched after a rebuild always executes after the rebuild completes, preventing deleted articles from being silently re-inserted.

The rebuild reads `cachedSearchSnapshots` from MainActor at **execution time** (via `DispatchQueue.main.sync`), not at dispatch time. This ensures the rebuild sees the latest in-memory state, including any articles deleted between when the rebuild was enqueued and when it actually runs.

## Threading Model

| Operation | Thread | Mechanism |
|-----------|--------|-----------|
| Index/embedding upsert on save | Serial write queue | `SearchDatabase.writeQueue.async` |
| Index/embedding removal on delete | Serial write queue | `SearchDatabase.writeQueue.async` |
| Full index rebuild | Serial write queue | `SearchDatabase.writeQueue.async` |
| BM25 search | Background | `Task.detached` via `async let` |
| Vector search | Background | `Task.detached` via `async let` |
| Hybrid fusion | Caller (MainActor) | Pure computation, fast |
| In-memory snapshot update | MainActor | `Task { @MainActor in ... }` |

All index mutations go through `SearchDatabase.writeQueue` (serial DispatchQueue, `.utility` QoS) for FIFO ordering. Within each mutation, `DatabasePool.write` provides transactional guarantees. All reads go through `DatabasePool.read` which allows concurrent readers via WAL snapshots. A read never sees a partially committed write transaction.

## AI Tool — `search_articles`

Added to the AI chat tool definitions in `ArticleAIChatView.swift`. Allows the AI assistant to discover articles by searching.

**Parameters:**
- `query` (string, required) — search text
- `limit` (integer, optional) — max results, default 10, max 50
- `planet_id` (string, optional) — restrict to a specific planet

**Returns:** JSON with `results` array containing `article_id`, `title`, `preview`, `relevance_score`, `planet_name`, `planet_id`. The `article_id` can be passed to `read_article` for full content.

## REST API — `GET /v0/search`

**Endpoint:** `GET /v0/search?q=<query>&limit=<n>`

Enhanced to use hybrid search and return `relevance_score` in the response. The `limit` parameter (default 20, max 200) controls article result count. Planet matching is unchanged (substring on name/about). Response remains backward-compatible — `relevance_score` is an added field.

**Response shape:**
```json
{
  "planets": [
    { "id": "...", "name": "...", "about": "...", "created": "...", "updated": "..." }
  ],
  "articles": [
    {
      "articleID": "...",
      "articleCreated": "...",
      "title": "...",
      "preview": "...",
      "planetID": "...",
      "planetName": "...",
      "relevanceScore": 0.024
    }
  ]
}
```

## Logging

All search infrastructure errors and lifecycle events are logged through `PlanetLogger` (to `/tmp/planet.log`), visible in the app's Log window under the "Planet" tab. Also logged via `os.Logger` for Console.app.

## Content Hash

Both `articles.content_hash` and `vectors.content_hash` use the same DJB2 hash (`SearchDatabase.contentHash(title:content:)`). This is a fast, non-cryptographic hash used solely to skip redundant writes when content hasn't changed. It's not used for security purposes.

## Known Tradeoffs

1. **Embedding rebuild is not a single transaction.** Each article's embedding is computed by NLEmbedding (CPU-intensive) and written individually. During rebuild, vector search may return incomplete results. FTS search is unaffected and covers keyword queries correctly during this window.

2. **NLEmbedding is English-only by default.** `NLEmbedding.sentenceEmbedding(for: .english)` provides the built-in macOS sentence embedding model. Non-English content will have lower-quality semantic matching but still works via BM25 keyword search.

3. **Brute-force cosine similarity.** All vectors are loaded and compared sequentially. This is fast for typical Planet usage (hundreds to low-thousands of articles) but would need an ANN index (e.g. sqlite-vec) for tens of thousands.
