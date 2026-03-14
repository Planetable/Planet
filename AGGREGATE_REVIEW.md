# Review: MyPlanetModel Aggregate Logic

## Summary

A review of `MyPlanetModel+Aggregate.swift` and `PlanetStore+Timer.swift` identified several bugs, race conditions, and reliability issues in the aggregation pipeline.

## Issues

### 1. Blocking synchronous network I/O

**File**: `MyPlanetModel+Aggregate.swift`, lines 471, 574, 595

`fetchHTTPSite` uses `Data(contentsOf: feedURL)` which performs a **synchronous blocking network fetch**. This is called inside an `async` function, blocking a cooperative thread pool thread. The same pattern appears in `fetchSocialImage` (line 574) and `fetchYouTubeThumbnail` (line 595).

**Fix**: Replace with `URLSession.shared.data(from:)` to use async networking.

### 2. Unreachable `catch` block in `fetchHTTPSite`

**File**: `MyPlanetModel+Aggregate.swift`, lines 471-473, 551

Both the feed data fetch (`try? Data(contentsOf:)`) and feed parsing (`try? await FeedUtils.parseFeed(...)`) use `try?`, silently swallowing errors. The `catch` block at line 551 is only reachable if `newArticle.save()` throws — feed fetch/parse failures are silently ignored with no logging.

**Fix**: Use `try` instead of `try?` so errors are caught and logged.

### 3. HTTP feed articles are never updated or cleaned up

**File**: `MyPlanetModel+Aggregate.swift`, `fetchHTTPSite`

Unlike `fetchPlanetSite`, `fetchHTTPSite` only adds new articles. It **never updates** existing articles when the source content changes, and **never deletes** articles that have been removed from the source feed. Over time this causes stale content and orphaned articles to accumulate.

### 4. Race condition: concurrent mutation of `articles` array

**File**: `MyPlanetModel+Aggregate.swift`, lines 442-451

In `fetchPlanetSite`, the deletion loop iterates over `self.articles` on a background thread while `article.delete()` dispatches `removeAll` on `@MainActor` asynchronously. New articles are also appended on `@MainActor` (line 436). This creates a data race — reading `@Published var articles` from a non-main thread while it's being mutated on MainActor.

### 5. `PlanetStore.aggregate()` returns immediately without waiting

**File**: `PlanetStore+Timer.swift`, lines 15-23

```swift
func aggregate() async {
    Task {  // <-- unnecessary Task wrapper
        await withTaskGroup(of: Void.self) { ... }
    }
}
```

The `Task { }` wrapper causes the `async` function to return immediately. Callers awaiting `aggregate()` get a result before aggregation has actually finished. The `Task` wrapper should be removed so `withTaskGroup` is awaited directly.

### 6. `batchDeletePosts` doesn't wait for async array removals

**File**: `MyPlanetModel+Aggregate.swift`, lines 81-94

`article.delete()` dispatches array removal to `@MainActor` asynchronously via `Task { @MainActor in ... }`. The code then immediately calls `consolidateTags()` and `save()` — but articles may not have been removed from the array yet, so tags are consolidated against stale data.

### 7. No timeout on network fetches

All `URLSession.shared.data(from:)` and `Data(contentsOf:)` calls lack timeout configuration. A slow or unresponsive aggregation source blocks the entire sequential aggregation pipeline indefinitely.

### 8. Brittle IPNS key length check

**File**: `MyPlanetModel+Aggregate.swift`, line 24

```swift
if s.hasPrefix("k51"), s.count == 62 {
```

CIDv1 keys encoded in base36 can vary in length. Hard-coding exactly 62 characters means valid IPNS keys of slightly different length are classified as `.unknown`.

## Minor Issues

- **Inconsistent task priority**: `fetchPlanetSite` uses `.utility` for `savePublic()` while `fetchHTTPSite` uses `.background`.
- **`try?` on feed parsing** (line 473): Makes it impossible to diagnose parsing failures.
