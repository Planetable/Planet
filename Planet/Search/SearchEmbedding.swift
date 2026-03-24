//
//  SearchEmbedding.swift
//  Planet
//

import Accelerate
import Foundation
import GRDB
import NaturalLanguage
import os

final class SearchEmbedding: Sendable {
    static let shared = SearchEmbedding()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SearchEmbedding")
    private var db: DatabasePool? { SearchDatabase.shared.pool }

    /// Cached sentence embedding model. Loaded once on first use.
    /// `nonisolated(unsafe)` because NLEmbedding is thread-safe but not marked Sendable.
    nonisolated(unsafe) private var cachedModel: NLEmbedding?
    nonisolated(unsafe) private var modelLoaded = false
    private let modelLock = NSLock()

    private init() {
        // Tables are created by SearchDatabase.migrate() — accessed via `db` property.
    }

    private func sentenceEmbedding() -> NLEmbedding? {
        modelLock.lock()
        defer { modelLock.unlock() }
        if modelLoaded { return cachedModel }
        cachedModel = NLEmbedding.sentenceEmbedding(for: .english)
        modelLoaded = true
        if cachedModel == nil {
            logger.warning("NLEmbedding.sentenceEmbedding not available")
            PlanetLogger.log("NLEmbedding.sentenceEmbedding not available", level: .warning)
        }
        return cachedModel
    }

    // MARK: - Embedding

    func embedArticle(snapshot: SearchArticleSnapshot) {
        guard let db else { return }
        let articleID = snapshot.articleID.uuidString
        let tags = snapshot.tags.joined(separator: ",")
        let articleContentHash = SearchDatabase.contentHash(
            title: snapshot.title,
            content: snapshot.content,
            tags: tags,
            slug: snapshot.slug ?? ""
        )
        let contentHash = SearchDatabase.contentHash(title: snapshot.title, content: snapshot.content)

        do {
            let existingHash = try db.read { db -> String? in
                try String.fetchOne(
                    db,
                    sql: "SELECT content_hash FROM vectors WHERE article_id = ?",
                    arguments: [articleID]
                )
            }

            guard existingHash != contentHash else { return }

            guard let vector = generateEmbedding(title: snapshot.title, content: snapshot.content)
            else {
                return
            }

            let blob = vectorToBlob(vector)
            // The EXISTS guard prevents writing an orphaned vector if the article
            // was concurrently removed, and the content_hash check prevents a stale
            // embedding from overwriting a fresher one when multiple embedArticle
            // calls for the same article execute out of order.
            try db.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO vectors (article_id, embedding, content_hash)
                        SELECT ?, ?, ?
                        WHERE EXISTS (
                            SELECT 1 FROM articles
                            WHERE article_id = ? AND content_hash = ?
                        )
                        ON CONFLICT(article_id) DO UPDATE SET
                            embedding = excluded.embedding,
                            content_hash = excluded.content_hash
                        """,
                    arguments: [articleID, blob, contentHash, articleID, articleContentHash]
                )
            }
        } catch {
            logger.error("embedArticle failed: \(error.localizedDescription)")
            PlanetLogger.log("embedArticle failed: \(error.localizedDescription)", level: .error)
        }
    }

    func removeEmbedding(articleID: UUID) {
        guard let db else { return }
        do {
            try db.write { db in
                try db.execute(
                    sql: "DELETE FROM vectors WHERE article_id = ?",
                    arguments: [articleID.uuidString]
                )
            }
        } catch {
            logger.error("removeEmbedding failed: \(error.localizedDescription)")
            PlanetLogger.log("removeEmbedding failed: \(error.localizedDescription)", level: .error)
        }
    }

    func rebuildEmbeddings(snapshots: [SearchArticleSnapshot]) {
        let start = CFAbsoluteTimeGetCurrent()
        for (index, snapshot) in snapshots.enumerated() {
            if Task.isCancelled {
                logger.info("Rebuild embeddings cancelled after \(index) articles")
                PlanetLogger.log("Rebuild embeddings cancelled after \(index) articles", level: .info)
                return
            }

            let articleID = snapshot.articleID.uuidString
            let contentHash = SearchDatabase.contentHash(title: snapshot.title, content: snapshot.content)

            let existingHash: String?
            do {
                existingHash = try db?.read { db in
                    try String.fetchOne(
                        db,
                        sql: "SELECT content_hash FROM vectors WHERE article_id = ?",
                        arguments: [articleID]
                    )
                }
            } catch {
                continue
            }

            // Already up to date — skip.
            if existingHash == contentHash { continue }

            // Generate and write with compare-and-swap.
            // CAS prevents overwriting a concurrent per-article save that may
            // insert an embedding between our read above and the write below.
            guard let vector = generateEmbedding(title: snapshot.title, content: snapshot.content)
            else {
                continue
            }

            let blob = vectorToBlob(vector)
            do {
                try db?.write { db in
                    try db.execute(
                        sql: """
                            INSERT INTO vectors (article_id, embedding, content_hash)
                            SELECT ?, ?, ?
                            WHERE EXISTS (SELECT 1 FROM articles WHERE article_id = ?)
                            ON CONFLICT(article_id) DO UPDATE SET
                                embedding = excluded.embedding,
                                content_hash = excluded.content_hash
                            WHERE vectors.content_hash IS ?
                            """,
                        arguments: [articleID, blob, contentHash, articleID, existingHash]
                    )
                }
            } catch {
                logger.error("rebuildEmbeddings write failed: \(error.localizedDescription)")
                PlanetLogger.log("rebuildEmbeddings write failed: \(error.localizedDescription)", level: .error)
            }
        }

        // Stale-embedding cleanup is deferred to the writeQueue (after
        // SearchIndex.rebuild commits) so the articles table is fully
        // populated — see PlanetStore.rebuildSearchSnapshots().
        let elapsed = String(format: "%.2f", CFAbsoluteTimeGetCurrent() - start)
        logger.info("Rebuilt embeddings for \(snapshots.count) articles in \(elapsed)s")
        PlanetLogger.log("Rebuilt embeddings for \(snapshots.count) articles in \(elapsed)s", level: .info)
    }

    // MARK: - Vector Search

    func search(query: String, limit: Int = 50) -> [SearchResult] {
        guard let db else { return [] }
        guard !Task.isCancelled else { return [] }

        guard let queryVectorDouble = generateQueryEmbedding(query) else {
            return []
        }
        let queryVector = queryVectorDouble.map { Float($0) }

        guard !Task.isCancelled else { return [] }

        do {
            // Phase 1: Stream embeddings via cursor with bounded memory.
            // Join on article_id only (not content_hash) because the embedding and
            // FTS lanes update independently; a temporary hash mismatch is expected.
            var topK: [(articleID: String, similarity: Double)] = []
            var minSimilarity: Float = 0.3  // also serves as the absolute threshold

            try db.read { db in
                let cursor = try Row.fetchCursor(
                    db,
                    sql: """
                        SELECT v.article_id, v.embedding
                        FROM vectors v
                        JOIN articles a ON a.article_id = v.article_id
                        """
                )

                var index = 0
                while let row = try cursor.next() {
                    if index % 64 == 0, Task.isCancelled { return }
                    index += 1

                    guard let articleID = row["article_id"] as? String,
                          let blob = row["embedding"] as? Data
                    else {
                        continue
                    }

                    let storedVector = blobToFloatVector(blob)
                    guard storedVector.count == queryVector.count else { continue }

                    let similarity = cosineSimilarityFloat(queryVector, storedVector)
                    guard similarity > minSimilarity else { continue }

                    topK.append((articleID, Double(similarity)))

                    // Compact when the buffer exceeds 2× limit to bound memory.
                    if topK.count >= limit * 2 {
                        topK.sort { $0.similarity > $1.similarity }
                        topK.removeSubrange(limit...)
                        minSimilarity = Float(topK.last?.similarity ?? 0.3)
                    }
                }
            }

            guard !topK.isEmpty, !Task.isCancelled else { return [] }

            topK.sort { $0.similarity > $1.similarity }
            if topK.count > limit {
                topK.removeSubrange(limit...)
            }

            // Phase 2: Fetch metadata only for top-K results.
            let topIDs = topK.map(\.articleID)
            let similarityByID = Dictionary(uniqueKeysWithValues: topK.map { ($0.articleID, $0.similarity) })

            let placeholders = topIDs.map { _ in "?" }.joined(separator: ",")
            let metadataRows = try db.read { db in
                try Row.fetchAll(
                    db,
                    sql: """
                        SELECT article_id, planet_id, planet_name, planet_kind,
                               title, content, preview_text, created_at
                        FROM articles
                        WHERE article_id IN (\(placeholders))
                        """,
                    arguments: StatementArguments(topIDs)
                )
            }

            var results: [SearchResult] = metadataRows.compactMap { row -> SearchResult? in
                guard let articleIDString = row["article_id"] as? String,
                      let articleID = UUID(uuidString: articleIDString),
                      let planetIDString = row["planet_id"] as? String,
                      let planetID = UUID(uuidString: planetIDString),
                      let planetName = row["planet_name"] as? String,
                      let planetKindInt = row["planet_kind"] as? Int,
                      let title = row["title"] as? String,
                      let content = row["content"] as? String,
                      let createdAt = row["created_at"] as? Double,
                      let similarity = similarityByID[articleIDString]
                else {
                    return nil
                }

                let planetKind: PlanetKind = planetKindInt == 0 ? .my : .following
                let created = Date(timeIntervalSinceReferenceDate: createdAt)
                let preview = row["preview_text"] as? String
                let snippet = SearchIndex.makeSnippet(
                    content: content,
                    previewText: preview,
                    query: query
                )

                return SearchResult(
                    articleID: articleID,
                    articleCreated: created,
                    title: title,
                    preview: snippet,
                    planetID: planetID,
                    planetName: planetName,
                    planetKind: planetKind,
                    relevanceScore: similarity
                )
            }

            results.sort { ($0.relevanceScore ?? 0) > ($1.relevanceScore ?? 0) }
            return results
        } catch {
            logger.error("SearchEmbedding.search failed: \(error.localizedDescription)")
            PlanetLogger.log("SearchEmbedding.search failed: \(error.localizedDescription)", level: .error)
            return []
        }
    }

    // MARK: - NLEmbedding

    private func generateEmbedding(title: String, content: String) -> [Double]? {
        guard let embedding = sentenceEmbedding() else { return nil }

        let maxContentLength = 2000
        let truncatedContent = content.count > maxContentLength
            ? String(content.prefix(maxContentLength))
            : content
        let text = title + ". " + truncatedContent

        return embedding.vector(for: text)
    }

    private func generateQueryEmbedding(_ query: String) -> [Double]? {
        guard let embedding = sentenceEmbedding() else { return nil }
        return embedding.vector(for: query)
    }

    // MARK: - Vector Math

    /// Cosine similarity using vDSP-accelerated dot products on Float vectors.
    private func cosineSimilarityFloat(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        let n = vDSP_Length(a.count)
        var dot: Float = 0
        var normA: Float = 0
        var normB: Float = 0
        vDSP_dotpr(a, 1, b, 1, &dot, n)
        vDSP_dotpr(a, 1, a, 1, &normA, n)
        vDSP_dotpr(b, 1, b, 1, &normB, n)
        let denom = sqrtf(normA) * sqrtf(normB)
        guard denom > 0 else { return 0 }
        return dot / denom
    }

    private func vectorToBlob(_ vector: [Double]) -> Data {
        var floats = vector.map { Float($0) }
        return Data(bytes: &floats, count: floats.count * MemoryLayout<Float>.size)
    }

    /// Decode stored blob directly to [Float] — avoids the Float→Double allocation.
    private func blobToFloatVector(_ data: Data) -> [Float] {
        let count = data.count / MemoryLayout<Float>.size
        var floats = [Float](repeating: 0, count: count)
        _ = floats.withUnsafeMutableBytes { data.copyBytes(to: $0) }
        return floats
    }

    /// Remove vectors whose article no longer exists in the index.
    /// Only checks article_id presence — NOT content_hash — because
    /// the embedding and FTS lanes update independently, so a temporary
    /// hash mismatch is normal and must not trigger deletion.
    /// Hash-based staleness is handled by embedArticle's ON CONFLICT DO UPDATE.
    ///
    /// Must be called on `SearchDatabase.writeQueue` (or after the index rebuild
    /// transaction commits) so the `articles` table is fully populated.
    func cleanupStaleEmbeddings() {
        guard let db else { return }
        do {
            try db.write { db in
                try db.execute(
                    sql: """
                        DELETE FROM vectors
                        WHERE NOT EXISTS (
                            SELECT 1
                            FROM articles
                            WHERE articles.article_id = vectors.article_id
                        )
                        """
                )
            }
        } catch {
            logger.error("cleanupStaleEmbeddings failed: \(error.localizedDescription)")
            PlanetLogger.log("cleanupStaleEmbeddings failed: \(error.localizedDescription)", level: .error)
        }
    }
}
