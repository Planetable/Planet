//
//  SearchIndex.swift
//  Planet
//

import Foundation
import GRDB
import NaturalLanguage
import os

final class SearchIndex: Sendable {
    static let shared = SearchIndex()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SearchIndex")
    private var db: DatabasePool? { SearchDatabase.shared.pool }

    private init() {
        // Tables are created by SearchDatabase.migrate() — accessed via `db` property.
    }

    // MARK: - Indexing
    // IMPORTANT: All mutation methods (upsert, remove, rebuild) must be called
    // exclusively from SearchDatabase.writeQueue to prevent interleaving.
    // GRDB provides transaction-level isolation, but the diff-based rebuild in
    // `rebuild(snapshots:)` relies on serial ordering to avoid deleting rows
    // that a concurrent upsert just inserted.

    @discardableResult
    func upsert(snapshot: SearchArticleSnapshot) -> Bool {
        guard let db else { return false }
        do {
            try db.write { db in
                try Self.upsertInTransaction(db, snapshot: snapshot)
            }
            return true
        } catch {
            logger.error("SearchIndex.upsert failed: \(error.localizedDescription)")
            PlanetLogger.log("SearchIndex.upsert failed: \(error.localizedDescription)", level: .error)
            return false
        }
    }

    /// Insert or update a snapshot within an existing transaction.
    private static func upsertInTransaction(_ db: Database, snapshot: SearchArticleSnapshot) throws {
        let tags = snapshot.tags.joined(separator: ",")
        let contentHash = SearchDatabase.contentHash(
            title: snapshot.title,
            content: snapshot.content,
            tags: tags,
            slug: snapshot.slug ?? ""
        )

        let existingHash = try String.fetchOne(
            db,
            sql: "SELECT content_hash FROM articles WHERE article_id = ?",
            arguments: [snapshot.articleID.uuidString]
        )

        if existingHash == contentHash {
            return
        }

        let attachments = snapshot.attachments.joined(separator: ",")
        let planetKind: Int = snapshot.planetKind == .my ? 0 : 1

        // Check if this is an insert or update so we can sync FTS manually.
        let existingRowID = try Int64.fetchOne(
            db,
            sql: "SELECT rowid FROM articles WHERE article_id = ?",
            arguments: [snapshot.articleID.uuidString]
        )

        // Store original text in the articles table (clean for display).
        try db.execute(
            sql: """
                INSERT INTO articles (article_id, planet_id, planet_name, planet_kind,
                                      title, content, preview_text, slug, tags, attachments,
                                      created_at, content_hash)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(article_id) DO UPDATE SET
                    planet_id = excluded.planet_id,
                    planet_name = excluded.planet_name,
                    planet_kind = excluded.planet_kind,
                    title = excluded.title,
                    content = excluded.content,
                    preview_text = excluded.preview_text,
                    slug = excluded.slug,
                    tags = excluded.tags,
                    attachments = excluded.attachments,
                    created_at = excluded.created_at,
                    content_hash = excluded.content_hash
                """,
            arguments: [
                snapshot.articleID.uuidString,
                snapshot.planetID.uuidString,
                snapshot.planetName,
                planetKind,
                snapshot.title,
                snapshot.content,
                snapshot.previewText,
                snapshot.slug,
                tags,
                attachments,
                snapshot.articleCreated.timeIntervalSinceReferenceDate,
                contentHash,
            ]
        )

        // Sync FTS with NLTokenizer-segmented content for CJK matching.
        guard let rowID = try Int64.fetchOne(
            db,
            sql: "SELECT rowid FROM articles WHERE article_id = ?",
            arguments: [snapshot.articleID.uuidString]
        ) else { return }

        let ftsTitle = SearchDatabase.tokenizeForFTS(snapshot.title)
        let ftsContent = SearchDatabase.tokenizeForFTS(snapshot.content)

        if existingRowID != nil {
            try db.execute(
                sql: "DELETE FROM articles_fts WHERE rowid = ?",
                arguments: [rowID]
            )
        }
        try db.execute(
            sql: "INSERT INTO articles_fts(rowid, title, content, tags, slug) VALUES (?, ?, ?, ?, ?)",
            arguments: [rowID, ftsTitle, ftsContent, tags, snapshot.slug]
        )
    }

    @discardableResult
    func remove(articleID: UUID) -> Bool {
        guard let db else { return false }
        do {
            try db.write { db in
                if let rowID = try Int64.fetchOne(
                    db,
                    sql: "SELECT rowid FROM articles WHERE article_id = ?",
                    arguments: [articleID.uuidString]
                ) {
                    try db.execute(sql: "DELETE FROM articles_fts WHERE rowid = ?", arguments: [rowID])
                }
                try db.execute(
                    sql: "DELETE FROM articles WHERE article_id = ?",
                    arguments: [articleID.uuidString]
                )
            }
            return true
        } catch {
            logger.error("SearchIndex.remove failed: \(error.localizedDescription)")
            PlanetLogger.log("SearchIndex.remove failed: \(error.localizedDescription)", level: .error)
            return false
        }
    }

    @discardableResult
    func rebuild(snapshots: [SearchArticleSnapshot]) -> Bool {
        guard let db else { return false }
        let start = CFAbsoluteTimeGetCurrent()
        do {
            // Diff-based sync: upsert every snapshot in batches, then delete rows
            // that no longer appear in the snapshot set.  Batching keeps each
            // transaction short so the WAL stays bounded, FTS5 change sets stay
            // small, and per-article upserts queued behind this rebuild aren't
            // starved.  The serial writeQueue still prevents interleaving.
            let currentIDs = Set(snapshots.map { $0.articleID.uuidString })

            let batchSize = 500
            for batchStart in stride(from: 0, to: snapshots.count, by: batchSize) {
                let batchEnd = min(batchStart + batchSize, snapshots.count)
                try db.write { db in
                    for index in batchStart..<batchEnd {
                        try Self.upsertInTransaction(db, snapshot: snapshots[index])
                    }
                }
            }

            // Remove stale articles in a separate transaction.
            // Safe: the serial writeQueue prevents interleaving with per-article
            // upserts, so no concurrent insert can land between our SELECT and DELETE.
            try db.write { db in
                let existing = try String.fetchAll(
                    db,
                    sql: "SELECT article_id FROM articles"
                )
                let staleIDs = existing.filter { !currentIDs.contains($0) }
                if !staleIDs.isEmpty {
                    let placeholders = staleIDs.map { _ in "?" }.joined(separator: ",")
                    let staleRowIDs = try Int64.fetchAll(
                        db,
                        sql: "SELECT rowid FROM articles WHERE article_id IN (\(placeholders))",
                        arguments: StatementArguments(staleIDs)
                    )
                    if !staleRowIDs.isEmpty {
                        let ftsPlaceholders = staleRowIDs.map { _ in "?" }.joined(separator: ",")
                        try db.execute(
                            sql: "DELETE FROM articles_fts WHERE rowid IN (\(ftsPlaceholders))",
                            arguments: StatementArguments(staleRowIDs.map { $0 })
                        )
                    }
                    try db.execute(
                        sql: "DELETE FROM articles WHERE article_id IN (\(placeholders))",
                        arguments: StatementArguments(staleIDs)
                    )
                }
            }

            let elapsed = String(format: "%.2f", CFAbsoluteTimeGetCurrent() - start)
            logger.info("SearchIndex rebuilt with \(snapshots.count) articles in \(elapsed)s")
            PlanetLogger.log("SearchIndex rebuilt with \(snapshots.count) articles in \(elapsed)s", level: .info)
            return true
        } catch {
            logger.error("SearchIndex.rebuild failed: \(error.localizedDescription)")
            PlanetLogger.log("SearchIndex.rebuild failed: \(error.localizedDescription)", level: .error)
            return false
        }
    }

    // MARK: - FTS5 Search

    func search(query: String, limit: Int = 200) -> [SearchResult] {
        guard let db else { return [] }
        let ftsQuery = sanitizeFTSQuery(query)
        PlanetLogger.log("BM25: query='\(query)' ftsQuery='\(ftsQuery)'", level: .info)
        guard !ftsQuery.isEmpty else { return [] }

        // Try the query as-is. If it fails (e.g. unclosed quotes in passthrough mode),
        // retry with a forcibly sanitized version that strips FTS syntax.
        if let results = executeFTSQuery(db: db, ftsQuery: ftsQuery, rawQuery: query, limit: limit) {
            PlanetLogger.log("BM25: returned \(results.count) results", level: .info)
            return results
        }

        let fallbackQuery = forceSanitize(query)
        guard !fallbackQuery.isEmpty, fallbackQuery != ftsQuery else { return [] }

        PlanetLogger.log("BM25: retrying with fallback='\(fallbackQuery)'", level: .info)
        let results = executeFTSQuery(db: db, ftsQuery: fallbackQuery, rawQuery: query, limit: limit) ?? []
        PlanetLogger.log("BM25: fallback returned \(results.count) results", level: .info)
        return results
    }

    private func executeFTSQuery(
        db: DatabasePool,
        ftsQuery: String,
        rawQuery: String,
        limit: Int
    ) -> [SearchResult]? {
        do {
            return try db.read { db in
                // Debug: count how many rows match
                let matchCount = try Int.fetchOne(
                    db,
                    sql: "SELECT count(*) FROM articles_fts WHERE articles_fts MATCH ?",
                    arguments: [ftsQuery]
                ) ?? 0
                PlanetLogger.log("BM25: MATCH '\(ftsQuery)' → \(matchCount) rows", level: .info)

                let rows = try Row.fetchAll(
                    db,
                    sql: """
                        SELECT
                            a.article_id,
                            a.planet_id,
                            a.planet_name,
                            a.planet_kind,
                            a.title,
                            a.content,
                            a.preview_text,
                            a.created_at,
                            bm25(articles_fts, 10.0, 1.0, 5.0, 3.0) AS rank
                        FROM articles_fts
                        JOIN articles a ON a.rowid = articles_fts.rowid
                        WHERE articles_fts MATCH ?
                        ORDER BY rank
                        LIMIT ?
                        """,
                    arguments: [ftsQuery, limit]
                )

                return rows.compactMap { row -> SearchResult? in
                    guard let articleIDString = row["article_id"] as? String,
                          let articleID = UUID(uuidString: articleIDString),
                          let planetIDString = row["planet_id"] as? String,
                          let planetID = UUID(uuidString: planetIDString),
                          let planetName = row["planet_name"] as? String,
                          let planetKindRaw = row["planet_kind"] as? Int64,
                          let title = row["title"] as? String,
                          let content = row["content"] as? String,
                          let createdAt = row["created_at"] as? Double,
                          let rank = row["rank"] as? Double
                    else {
                        return nil
                    }

                    let planetKind: PlanetKind = planetKindRaw == 0 ? .my : .following
                    let created = Date(timeIntervalSinceReferenceDate: createdAt)
                    let preview = row["preview_text"] as? String
                    let snippet = Self.makeSnippet(
                        content: content,
                        previewText: preview,
                        query: rawQuery
                    )

                    return SearchResult(
                        articleID: articleID,
                        articleCreated: created,
                        title: title,
                        preview: snippet,
                        planetID: planetID,
                        planetName: planetName,
                        planetKind: planetKind,
                        relevanceScore: -rank
                    )
                }
            }
        } catch {
            logger.error("SearchIndex.search failed: \(error.localizedDescription)")
            PlanetLogger.log("SearchIndex.search failed: \(error.localizedDescription)", level: .error)
            return nil
        }
    }

    /// Strip all FTS syntax and produce a plain prefix-match query.
    /// Used as fallback when the passthrough query fails to parse.
    private func forceSanitize(_ raw: String) -> String {
        let words = raw.split(whereSeparator: \.isWhitespace)
        var parts: [String] = []
        for word in words {
            let upper = word.uppercased()
            if Self.ftsOperators.contains(upper) {
                parts.append(upper)
            } else {
                let cleaned = word.filter { $0 != "\"" && $0 != "*" && $0 != "-" }
                guard !cleaned.isEmpty else { continue }
                parts.append("\"\(cleaned)\"*")
            }
        }
        // A query with only operators (e.g. "or not") is invalid FTS5.
        guard parts.contains(where: { !Self.ftsOperators.contains($0) }) else { return "" }
        return parts.joined(separator: " ")
    }

    // MARK: - Query Sanitization

    private static let ftsOperators: Set<String> = ["OR", "NOT", "AND"]

    private func sanitizeFTSQuery(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        // If the user typed explicit FTS5 syntax AND there are actual word
        // characters, pass through as-is. Bare punctuation like `"`, `*`, or `-`
        // alone is not a valid FTS5 query.
        let hasFTSSyntax = trimmed.contains("\"")
            || trimmed.contains("*")
            || trimmed.hasPrefix("-")
            || trimmed.contains(" -")

        let hasWordChars = trimmed.unicodeScalars.contains(where: CharacterSet.alphanumerics.contains)

        if hasFTSSyntax && hasWordChars {
            return trimmed
        }

        // Pre-tokenize with NLTokenizer so CJK words become separate AND
        // terms rather than a phrase.  Consecutive single-char CJK tokens
        // are merged into bigrams because NLTokenizer may segment query text
        // differently from document text (e.g. query "持币" → [持, 币] but
        // indexed "持币人数" → [持币人, 数]).  Merging gives "持币"* which
        // prefix-matches the indexed token "持币人".
        let nlTokenizer = NLTokenizer(unit: .word)
        nlTokenizer.string = trimmed
        var rawTokens: [String] = []
        nlTokenizer.enumerateTokens(in: trimmed.startIndex..<trimmed.endIndex) { range, _ in
            rawTokens.append(String(trimmed[range]))
            return true
        }

        // Merge consecutive single-char CJK tokens into bigrams.
        var tokens: [String] = []
        var singleCharRun: [String] = []
        func flushRun() {
            if singleCharRun.count >= 2 {
                for j in 0..<(singleCharRun.count - 1) {
                    tokens.append(singleCharRun[j] + singleCharRun[j + 1])
                }
            } else if singleCharRun.count == 1 {
                tokens.append(singleCharRun[0])
            }
            singleCharRun.removeAll()
        }
        for token in rawTokens {
            if token.count == 1, token.unicodeScalars.allSatisfy(Self.isCJK) {
                singleCharRun.append(token)
            } else {
                flushRun()
                tokens.append(token)
            }
        }
        flushRun()

        var parts: [String] = []
        for token in tokens {
            let upper = token.uppercased()
            if Self.ftsOperators.contains(upper) {
                parts.append(upper)
            } else {
                let cleaned = token.replacingOccurrences(of: "\"", with: "")
                guard !cleaned.isEmpty else { continue }
                parts.append("\"\(cleaned)\"*")
            }
        }

        // A query with only operators (e.g. "or not") is invalid FTS5.
        guard parts.contains(where: { !Self.ftsOperators.contains($0) }) else { return "" }

        return parts.joined(separator: " ")
    }

    // MARK: - Snippet Extraction

    /// Lowercased FTS5 boolean operators — excluded from snippet term scoring
    /// since they are query syntax, not content terms.
    private static let ftsStopWords: Set<String> = ["or", "not", "and"]

    static func makeSnippet(
        content: String,
        previewText: String?,
        query: String,
        windowSize: Int = 300
    ) -> String {
        let queryTerms = query.lowercased()
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { !$0.hasPrefix("-") && !ftsStopWords.contains($0) }
            .map { $0.replacingOccurrences(of: "\"", with: "") }
            .filter { !$0.isEmpty }

        let normalized = content
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")

        guard !normalized.isEmpty, !queryTerms.isEmpty else {
            if let preview = previewText, !preview.isEmpty {
                return truncateSnippet(preview, maxLength: 180)
            }
            return truncateSnippet(normalized, maxLength: 180)
        }

        var bestStart = normalized.startIndex
        var bestScore = 0

        var windowStart = normalized.startIndex
        while windowStart < normalized.endIndex {
            let windowEnd = normalized.index(
                windowStart,
                offsetBy: windowSize,
                limitedBy: normalized.endIndex
            ) ?? normalized.endIndex

            let windowText = normalized[windowStart..<windowEnd]
            var score = 0
            for term in queryTerms {
                var searchStart = windowText.startIndex
                while let range = windowText.range(
                    of: term,
                    options: [.caseInsensitive, .diacriticInsensitive],
                    range: searchStart..<windowText.endIndex
                ) {
                    score += 1
                    searchStart = range.upperBound
                }
            }

            if score > bestScore {
                bestScore = score
                bestStart = windowStart
            }

            guard let next = normalized.index(
                windowStart,
                offsetBy: 50,
                limitedBy: normalized.endIndex
            ) else { break }
            windowStart = next
        }

        if bestScore == 0 {
            if let preview = previewText, !preview.isEmpty {
                return truncateSnippet(preview, maxLength: 180)
            }
            return truncateSnippet(normalized, maxLength: 180)
        }

        var start = bestStart
        var end = normalized.index(
            start,
            offsetBy: windowSize,
            limitedBy: normalized.endIndex
        ) ?? normalized.endIndex

        if start > normalized.startIndex,
           normalized[normalized.index(before: start)] != " " {
            if let nextSpace = normalized[start...].firstIndex(of: " ") {
                start = normalized.index(after: nextSpace)
            }
        }
        if start < end, end < normalized.endIndex, normalized[end] != " " {
            if let prevSpace = normalized[start..<end].lastIndex(of: " ") {
                end = prevSpace
            }
        }

        if start > end { start = end }
        var snippet = String(normalized[start..<end])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if start > normalized.startIndex {
            snippet = "…" + snippet
        }
        if end < normalized.endIndex {
            snippet += "…"
        }

        return snippet
    }

    private static func truncateSnippet(_ text: String, maxLength: Int) -> String {
        let normalized = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard normalized.count > maxLength else { return normalized }

        var end = normalized.index(normalized.startIndex, offsetBy: maxLength)
        if normalized[end] != " " {
            if let prevSpace = normalized[..<end].lastIndex(of: " ") {
                end = prevSpace
            }
        }
        return String(normalized[..<end]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    private static func isCJK(_ scalar: Unicode.Scalar) -> Bool {
        let v = scalar.value
        return (0x4E00...0x9FFF).contains(v)
            || (0x3400...0x4DBF).contains(v)
            || (0x20000...0x2A6DF).contains(v)
            || (0x2A700...0x2B73F).contains(v)
            || (0x2B740...0x2B81F).contains(v)
            || (0xF900...0xFAFF).contains(v)
            || (0x2F800...0x2FA1F).contains(v)
    }
}
