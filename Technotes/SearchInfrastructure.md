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
| `Planet/Search/SearchDatabase.swift` | Shared `DatabasePool`, schema versioning, CJK tokenization, content hash |
| `Planet/Search/SearchIndex.swift` | FTS5 indexing with manual FTS sync, BM25 search, query sanitization, snippet extraction |
| `Planet/Search/SearchEmbedding.swift` | NLEmbedding vectors, multi-language support, cosine similarity search |
| `Planet/Search/HybridSearch.swift` | Reciprocal Rank Fusion of BM25 + vector results |
| `Planet/Search/PlanetStore+Search.swift` | Lifecycle hooks, search entry point, in-memory fallback |
| `Planet/Entities/SearchResult.swift` | `SearchResult` struct with optional `relevanceScore`, `bm25Score`, `vectorScore` |

## Dependencies

| Dependency | What | License |
|-----------|------|---------|
| [GRDB.swift](https://github.com/groue/GRDB.swift) 7.5+ | SQLite wrapper with FTS5 and `DatabasePool` | MIT |
| `NaturalLanguage.framework` | Apple's on-device `NLEmbedding` for sentence vectors, `NLTokenizer` for CJK word segmentation, `NLLanguageRecognizer` for language detection | macOS system framework |

No network calls, no model downloads, no API keys. Everything runs on-device.

## Database

Single SQLite file at `~/.config/Planet/search.sqlite`, opened as a `DatabasePool` in WAL mode.

### Schema Versioning

Instead of incremental migrations, the search database uses a simple integer version check. A `schema_version` table stores the current version. On startup, `ensureSchema()` compares the stored version against `schemaVersion` in the code:

- **Match:** no action needed.
- **Mismatch:** all data tables are dropped and recreated. The next startup rebuild repopulates everything.
- **Drop failure** (e.g. FTS table references a missing custom tokenizer from a prior schema): the entire database file is deleted and recreated from scratch.

Bump `schemaVersion` whenever the schema or indexing strategy changes. This is safe because all search data is machine-generated from the article source of truth.

### Tables

**`articles`** — content table mirroring article metadata for search. Stores clean, original text for display.

| Column | Type | Notes |
|--------|------|-------|
| `rowid` | INTEGER PRIMARY KEY | Auto-increment, used by FTS5 `content_rowid` |
| `article_id` | TEXT UNIQUE NOT NULL | UUID string |
| `planet_id` | TEXT NOT NULL | UUID string |
| `planet_name` | TEXT NOT NULL | |
| `planet_kind` | INTEGER NOT NULL | 0 = my, 1 = following |
| `title` | TEXT NOT NULL | Original, unsegmented |
| `content` | TEXT NOT NULL | Full markdown body, original |
| `preview_text` | TEXT | Article summary, nullable |
| `slug` | TEXT | |
| `tags` | TEXT | Comma-separated |
| `attachments` | TEXT | Comma-separated |
| `created_at` | REAL NOT NULL | `timeIntervalSinceReferenceDate` |
| `content_hash` | TEXT NOT NULL | DJB2 hash of `title + "\n" + content + tags + slug` — skip re-index when unchanged |

**`articles_fts`** — standalone FTS5 virtual table for full-text search.

```sql
CREATE VIRTUAL TABLE articles_fts USING fts5(
    title, content, tags, slug,
    content_rowid='rowid',
    tokenize='unicode61 remove_diacritics 2'
)
```

This is a **standalone** FTS table (no `content='articles'`), not an external content table. Content is manually synced during upsert/remove so that FTS receives NLTokenizer-segmented CJK text while the `articles` table retains clean original text for display. Column order matters for `bm25()` weight arguments.

**`vectors`** — embedding storage for semantic search.

| Column | Type | Notes |
|--------|------|-------|
| `article_id` | TEXT PRIMARY KEY | UUID string, references `articles.article_id` |
| `embedding` | BLOB NOT NULL | 512 x Float32 = 2048 bytes per article |
| `content_hash` | TEXT NOT NULL | DJB2 hash of `title + "\n" + content` (without tags/slug) |
| `language` | TEXT | BCP 47 language tag (e.g. `en`, `zh-Hans`). Indexed. |

## CJK Search Support

FTS5's default `unicode61` tokenizer doesn't perform Chinese/Japanese/Korean word segmentation — it treats runs of CJK characters as single tokens. To support CJK search, the indexing pipeline appends NLTokenizer-segmented words to the FTS content.

### Indexing

`SearchDatabase.tokenizeForFTS()` processes text containing CJK characters:

1. Runs `NLTokenizer(unit: .word)` over the text
2. Collects all tokens containing CJK ideographs
3. Appends them space-separated after the original text

Example: `"以下为昨日摘要"` → `"以下为昨日摘要 以下 为 昨日 摘要"`

The original text is preserved (so `unicode61` also indexes whatever tokens it can extract), and the appended words provide granular CJK matching. Only the FTS table receives this augmented text; the `articles` table stores the original.

### Query Processing

`sanitizeFTSQuery()` pre-tokenizes CJK queries with NLTokenizer so that CJK words become separate AND terms rather than a phrase:

1. Runs `NLTokenizer(unit: .word)` over the query
2. Merges consecutive single-character CJK tokens into bigrams (because NLTokenizer may segment differently at query time vs index time due to context differences)
3. Each resulting token becomes a `"token"*` prefix term

Example: `"昨日持币"` → NLTokenizer: `[昨日, 持, 币]` → merge single chars: `[昨日, 持币]` → FTS query: `"昨日"* "持币"*`

### Why Not a Custom FTS5 Tokenizer?

FTS5's prefix matching (`*`) operates on whole tokens, not character substrings. A custom tokenizer that segments `持币人数` as `持币人` + `数` would not match the query token `持币` via prefix — FTS5 requires the query to produce an exact token or a token that is a prefix of an indexed token as output by the tokenizer. Since NLTokenizer segments differently depending on surrounding context, the same characters produce different tokens at index time vs query time. The standalone FTS approach with appended tokens avoids this fundamental limitation.

## SearchIndex — BM25 Full-Text Search

### Indexing

`SearchIndex.upsert(snapshot:)` checks the `content_hash` — if unchanged, skips the write entirely. Otherwise:

1. Inserts/updates the `articles` table with original text
2. Manually syncs the `articles_fts` table with NLTokenizer-augmented text (delete old FTS row if updating, then insert new)

`SearchIndex.rebuild(snapshots:)` runs a diff-based sync in batches of 500 articles per transaction, then deletes stale rows. Both `articles` and `articles_fts` are kept in sync.

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

Plain queries are transformed for type-ahead: each word becomes `"word"*` (quoted prefix match with implicit AND). CJK words are pre-tokenized with NLTokenizer and single-char runs are merged into bigrams.

FTS5 syntax is passed through when detected (and the query contains alphanumeric characters) — users can type `"exact phrase"`, `prefix*`, `-negation`, or `term1 OR term2`. Bare punctuation (`"`, `*`, `-`) without word characters is rejected to prevent FTS5 syntax errors. Operator-only queries (`or not`, `and`) are also rejected.

If the primary query fails (e.g. malformed FTS5 syntax that passed the passthrough check), a `forceSanitize` fallback strips all FTS syntax and retries with clean prefix terms.

### Snippet Extraction

`SearchIndex.makeSnippet()` finds the best 300-character window in the content by sliding a window (50-char step) and scoring query term density via case-insensitive, diacritic-insensitive matching. The window with the highest term count wins. Output is snapped to word boundaries with `…` ellipsis.

## SearchEmbedding — Vector Semantic Search

### Language Handling

Each article's language is detected via `NLLanguageRecognizer` on the article text (title + first 1000 chars of content). Key behaviors:

- **Confidence threshold:** 0.3 for articles, 0.2 for CJK queries (CJK scripts are unambiguous), 0.5 for Latin-script queries
- **Language normalization:** `zh-Hant` (Traditional Chinese) is normalized to `zh-Hans` (Simplified Chinese) since Apple uses the same NLEmbedding model for both
- **Re-embedding trigger:** Articles with `zh-Hant` language tags are re-embedded to normalize to `zh-Hans`
- **Model caching:** Sentence embedding models are cached per-language with NSLock. Each language is probed once; if no model is available, the language is skipped permanently for the session

### Embedding Generation

Uses `NLEmbedding.sentenceEmbedding(for:)` from Apple's NaturalLanguage framework. Input is `title + ". " + content` (truncated to 2000 chars). Returns a 512-dimensional `[Double]` vector, stored as `[Float32]` blob (2048 bytes per article).

### Search — Two-Phase

1. **Phase 1:** Stream `article_id` + `embedding` blob from `vectors` table via cursor, filtered by `WHERE language = ?`. Compute cosine similarity against the query embedding. Filter by minimum threshold (0.3). Sort and keep top-K with bounded memory (compact at 2× limit).
2. **Phase 2:** Fetch full metadata (`title`, `content`, `preview_text`, etc.) from `articles` table only for the top-K article IDs.

### Cosine Similarity

Standard dot-product / (norm_a * norm_b). Computed via vDSP-accelerated dot products on `[Float]` arrays.

## HybridSearch — Reciprocal Rank Fusion

```swift
HybridSearch.fuse(bm25Results: [...], vectorResults: [...])
```

Each result list contributes a score per article:

```
score(article) = Σ weight / (k + rank)
```

Where `k = 60`, BM25 weight = 1.5, vector weight = 1.0. Articles appearing in both lists get the sum of their contributions. BM25's keyword-aware snippet is preferred when an article appears in both. Per-source scores (`bm25Score`, `vectorScore`) are tracked and passed through to the result.

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

## Log Viewer

The in-app log viewer (`AppLogView`) monitors log files using `DispatchSource.makeFileSystemObjectSource` for real-time streaming. All four loggers (Planet, IPFS, SSH Rsync, Cloudflare Pages) use `truncateFile(atOffset: 0)` for their `clear()` method instead of `removeItem` — this preserves the file inode so the DispatchSource file descriptor remains valid and continues receiving write events after clearing.

## AI Tool — `search_articles`

Added to the AI chat tool definitions in `ArticleAIChatView.swift`. Allows the AI assistant to discover articles by searching.

**Parameters:**
- `query` (string, required) — search text
- `limit` (integer, optional) — max results, default 10, max 50
- `planet_id` (string, optional) — restrict to a specific planet

**Returns:** JSON with `results` array containing `article_id`, `title`, `preview`, `relevance_score`, `planet_name`, `planet_id`. The `article_id` can be passed to `read_article` for full content.

## REST API — `GET /v0/search`

**Endpoint:** `GET /v0/search?q=<query>&limit=<n>`

Uses hybrid search and returns scoring details in the response. The `limit` parameter (default 20, max 200) controls article result count. Planet matching is unchanged (substring on name/about). Results include both My and Following planet articles.

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
      "relevanceScore": 0.024,
      "bm25Score": 0.024,
      "vectorScore": null,
      "source": "bm25"
    }
  ]
}
```

The `source` field indicates where the result came from: `"bm25"`, `"vector"`, `"both"`, or `"fallback"`.

## Logging

All search infrastructure errors and lifecycle events are logged through `PlanetLogger` (to `tmp/planet.log` in the app sandbox), visible in the app's Log window under the "Planet" tab. Also logged via `os.Logger` for Console.app.

## Content Hash

Both `articles.content_hash` and `vectors.content_hash` use the same DJB2 hash (`SearchDatabase.contentHash(title:content:)`). The articles table hash includes tags and slug; the vectors table hash covers only title and content. This is a fast, non-cryptographic hash used solely to skip redundant writes when content hasn't changed.

## Known Tradeoffs

1. **Standalone FTS table requires manual sync.** Because FTS stores NLTokenizer-augmented text while the articles table stores clean original text, the FTS table cannot use external content (`content='articles'`) with triggers. Instead, `SearchIndex.upsertInTransaction` manually syncs FTS rows during insert/update, and `remove`/`rebuild` clean up FTS rows explicitly.

2. **NLTokenizer context sensitivity.** NLTokenizer may segment the same CJK characters differently depending on surrounding context (e.g. `持币人数` → `持币人 + 数` but `持币` alone → `持 + 币`). The query sanitizer mitigates this by merging consecutive single-character CJK tokens into bigrams.

3. **Embedding rebuild is not a single transaction.** Each article's embedding is computed by NLEmbedding (CPU-intensive) and written individually. During rebuild, vector search may return incomplete results. FTS search is unaffected and covers keyword queries correctly during this window.

4. **Language detection drives embedding model selection.** Different language models produce vectors in different vector spaces, so query-time vector search filters by `WHERE language = ?`. Languages without an available sentence embedding model fall back to BM25 keyword search.

5. **Brute-force cosine similarity.** All vectors for the query language are loaded and compared sequentially. This is fast for typical Planet usage (hundreds to low-thousands of articles) but would need an ANN index (e.g. sqlite-vec) for tens of thousands.
