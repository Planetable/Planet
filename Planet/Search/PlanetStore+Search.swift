//
//  PlanetStore+Search.swift
//  Planet
//
//  Created by Xin Liu on 12/6/23.
//

import Foundation

private let searchPreviewLength = 180
private let searchPreviewLeadingContext = 48
private let searchPreviewTrailingContext = 112
private let searchResultLimit = 200
private let searchYieldInterval = 64
private let searchMinimumChunkSize = 64

struct SearchArticleSnapshot: Sendable {
    let articleID: UUID
    let articleCreated: Date
    let title: String
    let content: String
    let previewText: String?
    let slug: String?
    let tags: [String]
    let attachments: [String]
    let planetID: UUID
    let planetName: String
    let planetKind: PlanetKind

    func matches(_ query: String) -> Bool {
        contains(title, query: query)
            || contains(slug, query: query)
            || tags.contains(where: { contains($0, query: query) })
            || attachments.contains(where: { contains($0, query: query) })
            || contains(content, query: query)
    }

    func makeResult(matching query: String) -> SearchResult {
        SearchResult(
            articleID: articleID,
            articleCreated: articleCreated,
            title: title,
            preview: makePreview(matching: query),
            planetID: planetID,
            planetName: planetName,
            planetKind: planetKind
        )
    }

    private func makePreview(matching query: String) -> String {
        if let previewText, let snippet = previewSnippet(in: previewText, matching: query) {
            return snippet
        }
        if let snippet = previewSnippet(in: content, matching: query) {
            return snippet
        }
        if let previewText, !previewText.isEmpty {
            return truncate(previewText)
        }
        return truncate(content)
    }

    private func previewSnippet(in text: String, matching query: String) -> String? {
        let normalizedText = normalize(text)
        guard !normalizedText.isEmpty else {
            return nil
        }
        guard let match = normalizedText.range(
            of: query,
            options: [.caseInsensitive, .diacriticInsensitive]
        ) else {
            return nil
        }

        var start = normalizedText.index(
            match.lowerBound,
            offsetBy: -searchPreviewLeadingContext,
            limitedBy: normalizedText.startIndex
        ) ?? normalizedText.startIndex
        var end = normalizedText.index(
            match.upperBound,
            offsetBy: searchPreviewTrailingContext,
            limitedBy: normalizedText.endIndex
        ) ?? normalizedText.endIndex

        // Snap to word boundaries to avoid cutting words in half
        if start > normalizedText.startIndex,
           normalizedText[normalizedText.index(before: start)] != " " {
            if let nextSpace = normalizedText[start...].firstIndex(of: " ") {
                start = normalizedText.index(after: nextSpace)
            }
        }
        if end < normalizedText.endIndex,
           normalizedText[end] != " " {
            if let prevSpace = normalizedText[start..<end].lastIndex(of: " ") {
                end = prevSpace
            }
        }

        var snippet = String(normalizedText[start..<end])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if start > normalizedText.startIndex {
            snippet = "…" + snippet
        }
        if end < normalizedText.endIndex {
            snippet += "…"
        }
        return snippet
    }

    private func truncate(_ text: String, maxLength: Int = searchPreviewLength) -> String {
        let normalizedText = normalize(text)
        guard normalizedText.count > maxLength else {
            return normalizedText
        }

        var end = normalizedText.index(normalizedText.startIndex, offsetBy: maxLength)
        // Snap to word boundary to avoid cutting words in half
        if normalizedText[end] != " " {
            if let prevSpace = normalizedText[..<end].lastIndex(of: " ") {
                end = prevSpace
            }
        }
        return String(normalizedText[..<end]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    private func normalize(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private func contains(_ text: String?, query: String) -> Bool {
        guard let text, !text.isEmpty else {
            return false
        }
        return text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}

extension SearchArticleSnapshot {
    init(article: MyArticleModel) {
        self.init(
            articleID: article.id,
            articleCreated: article.created,
            title: article.title,
            content: article.content,
            previewText: article.summary,
            slug: article.slug,
            tags: article.tags.map { Array($0.keys) } ?? [],
            attachments: article.attachments ?? [],
            planetID: article.planet.id,
            planetName: article.planet.name,
            planetKind: .my
        )
    }

    init(article: FollowingArticleModel) {
        self.init(
            articleID: article.id,
            articleCreated: article.created,
            title: article.title,
            content: article.content,
            previewText: article.summary,
            slug: nil,
            tags: [],
            attachments: article.attachments ?? [],
            planetID: article.planet.id,
            planetName: article.planet.name,
            planetKind: .following
        )
    }
}

private func searchSnapshots(
    _ snapshots: [SearchArticleSnapshot],
    matching query: String
) async -> [SearchResult] {
    guard !snapshots.isEmpty else {
        return []
    }

    let workerCount = max(1, min(ProcessInfo.processInfo.activeProcessorCount, snapshots.count))
    let chunkSize = max(
        searchMinimumChunkSize,
        (snapshots.count + workerCount - 1) / workerCount
    )

    return await withTaskGroup(of: [SearchResult].self, returning: [SearchResult].self) { group in
        for start in stride(from: 0, to: snapshots.count, by: chunkSize) {
            let end = min(start + chunkSize, snapshots.count)
            group.addTask {
                var partialResults: [SearchResult] = []
                partialResults.reserveCapacity(min(searchResultLimit, end - start))

                for index in start..<end {
                    if Task.isCancelled {
                        return []
                    }
                    if index > start, (index - start).isMultiple(of: searchYieldInterval) {
                        await Task.yield()
                    }

                    let snapshot = snapshots[index]
                    if snapshot.matches(query) {
                        partialResults.append(snapshot.makeResult(matching: query))
                    }
                }

                return partialResults
            }
        }

        var results: [SearchResult] = []
        results.reserveCapacity(min(searchResultLimit, snapshots.count))

        for await partialResults in group {
            if Task.isCancelled {
                group.cancelAll()
                return []
            }
            results.append(contentsOf: partialResults)
        }

        results.sort(by: { $0.articleCreated > $1.articleCreated })
        if results.count > searchResultLimit {
            results.removeSubrange(searchResultLimit...)
        }
        return results
    }
}

private func buildSearchSnapshots(
    myPlanets: [MyPlanetModel],
    followingPlanets: [FollowingPlanetModel]
) -> [SearchArticleSnapshot] {
    let totalArticleCount = myPlanets.reduce(into: 0) { count, planet in
        count += planet.articles.count
    } + followingPlanets.reduce(into: 0) { count, planet in
        count += planet.articles.count
    }

    var snapshots: [SearchArticleSnapshot] = []
    snapshots.reserveCapacity(totalArticleCount)

    for planet in myPlanets {
        for article in planet.articles {
            snapshots.append(SearchArticleSnapshot(article: article))
        }
    }

    for planet in followingPlanets {
        for article in planet.articles {
            snapshots.append(SearchArticleSnapshot(article: article))
        }
    }

    return snapshots
}

extension PlanetStore {
    nonisolated static func requestSearchSnapshotRebuild() {
        guard isSharedReady else {
            return
        }
        Task { @MainActor in
            PlanetStore.shared.scheduleSearchSnapshotRebuild()
        }
    }

    nonisolated static func upsertSearchSnapshotIfReady(for article: MyArticleModel) {
        guard isSharedReady else {
            return
        }
        let snapshot = SearchArticleSnapshot(article: article)
        Task.detached(priority: .utility) {
            SearchEmbedding.shared.embedArticle(snapshot: snapshot)
        }
        Task { @MainActor in
            PlanetStore.shared.upsertSearchSnapshot(for: article)
            PlanetStore.shared.pendingIndexUpdates += 1
            SearchDatabase.writeQueue.async {
                SearchIndex.shared.upsert(snapshot: snapshot)
                Task { @MainActor in
                    PlanetStore.shared.pendingIndexUpdates -= 1
                }
            }
        }
    }

    nonisolated static func upsertSearchSnapshotIfReady(for article: FollowingArticleModel) {
        guard isSharedReady else {
            return
        }
        let snapshot = SearchArticleSnapshot(article: article)
        Task.detached(priority: .utility) {
            SearchEmbedding.shared.embedArticle(snapshot: snapshot)
        }
        Task { @MainActor in
            PlanetStore.shared.upsertSearchSnapshot(for: article)
            PlanetStore.shared.pendingIndexUpdates += 1
            SearchDatabase.writeQueue.async {
                SearchIndex.shared.upsert(snapshot: snapshot)
                Task { @MainActor in
                    PlanetStore.shared.pendingIndexUpdates -= 1
                }
            }
        }
    }

    nonisolated static func removeSearchSnapshotIfReady(articleID: UUID) {
        guard isSharedReady else {
            return
        }
        Task.detached(priority: .utility) {
            SearchEmbedding.shared.removeEmbedding(articleID: articleID)
        }
        Task { @MainActor in
            PlanetStore.shared.removeSearchSnapshot(articleID: articleID)
            PlanetStore.shared.pendingIndexUpdates += 1
            SearchDatabase.writeQueue.async {
                SearchIndex.shared.remove(articleID: articleID)
                Task { @MainActor in
                    PlanetStore.shared.pendingIndexUpdates -= 1
                }
            }
        }
    }

    func searchAllArticles(text: String) async -> [SearchResult] {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return []
        }

        let pendingRebuildTask = searchSnapshotRebuildTask
        await pendingRebuildTask?.value

        if cachedSearchSnapshots.isEmpty {
            rebuildSearchSnapshots()
        }

        // Fall back to in-memory search only on cold start (index never built).
        // Once built, use the (slightly stale) index so queries stay ranked and fast.
        if pendingIndexUpdates > 0, !searchIndexBuiltOnce {
            return await searchSnapshots(cachedSearchSnapshots, matching: query)
        }

        // withTaskGroup child tasks inherit cancellation but run off MainActor,
        // so typeahead cancellation propagates and search runs in background.
        let (bm25Results, vectorResults) = await withTaskGroup(
            of: (bm25: [SearchResult], vector: [SearchResult]).self,
            returning: ([SearchResult], [SearchResult]).self
        ) { group in
            group.addTask { (SearchIndex.shared.search(query: query), []) }
            group.addTask { ([], SearchEmbedding.shared.search(query: query)) }

            var bm25: [SearchResult] = []
            var vector: [SearchResult] = []
            for await result in group {
                if Task.isCancelled {
                    group.cancelAll()
                    return ([], [])
                }
                if !result.bm25.isEmpty { bm25 = result.bm25 }
                if !result.vector.isEmpty { vector = result.vector }
            }
            return (bm25, vector)
        }

        guard !Task.isCancelled else { return [] }

        if !bm25Results.isEmpty || !vectorResults.isEmpty {
            return HybridSearch.fuse(
                bm25Results: bm25Results,
                vectorResults: vectorResults
            )
        }

        return await searchSnapshots(cachedSearchSnapshots, matching: query)
    }

    func scheduleSearchSnapshotRebuild() {
        searchSnapshotRebuildTask?.cancel()
        searchSnapshotRebuildTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else {
                return
            }
            rebuildSearchSnapshots()
            searchSnapshotRebuildTask = nil
        }
    }

    func rebuildSearchSnapshots() {
        cachedSearchSnapshots = buildSearchSnapshots(
            myPlanets: myPlanets,
            followingPlanets: followingPlanets
        )
        let snapshots = cachedSearchSnapshots

        embeddingRebuildTask?.cancel()
        embeddingRebuildTask = Task.detached(priority: .utility) {
            SearchEmbedding.shared.rebuildEmbeddings(snapshots: snapshots)
        }

        pendingIndexUpdates += 1
        SearchDatabase.writeQueue.async {
            SearchIndex.shared.rebuild(snapshots: snapshots)
            // Clean up orphaned vectors now that the articles table is fully
            // populated — safe because we're on the serial writeQueue.
            SearchEmbedding.shared.cleanupStaleEmbeddings()
            Task { @MainActor in
                PlanetStore.shared.pendingIndexUpdates -= 1
                PlanetStore.shared.searchIndexBuiltOnce = true
            }
        }
    }

    func upsertSearchSnapshot(for article: MyArticleModel) {
        upsertSearchSnapshot(SearchArticleSnapshot(article: article))
    }

    func upsertSearchSnapshot(for article: FollowingArticleModel) {
        upsertSearchSnapshot(SearchArticleSnapshot(article: article))
    }

    func removeSearchSnapshot(articleID: UUID) {
        cachedSearchSnapshots.removeAll(where: { $0.articleID == articleID })
    }

    private func upsertSearchSnapshot(_ snapshot: SearchArticleSnapshot) {
        if let index = cachedSearchSnapshots.firstIndex(where: { $0.articleID == snapshot.articleID }) {
            cachedSearchSnapshots[index] = snapshot
        } else {
            cachedSearchSnapshots.append(snapshot)
        }
    }
}
