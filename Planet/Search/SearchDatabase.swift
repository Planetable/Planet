//
//  SearchDatabase.swift
//  Planet
//

import Foundation
import GRDB
import NaturalLanguage
import os

/// Shared database for the search index and vector embeddings.
/// Both SearchIndex and SearchEmbedding use this single DatabasePool
/// to avoid WAL contention from multiple connections to the same file.
final class SearchDatabase: Sendable {
    static let shared = SearchDatabase()

    /// Bump this whenever the schema or indexing strategy changes.
    /// On mismatch the database is recreated and a full rebuild happens automatically.
    private static let schemaVersion = 8

    /// `nil` when the database could not be opened (corrupted file, migration failure, etc.).
    /// Callers must handle `nil` gracefully — search degrades to in-memory fallback.
    let pool: DatabasePool?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SearchDatabase")

    private init() {
        let configDir = URLUtils.repoPath()
        let dbPath = configDir.appendingPathComponent("search.sqlite").path

        var config = Configuration()
        config.journalMode = .wal
        config.busyMode = .timeout(5)
        do {
            var openedPool = try DatabasePool(path: dbPath, configuration: config)
            var needsRebuild: Bool
            do {
                needsRebuild = try Self.ensureSchema(openedPool)
            } catch {
                // Schema migration failed (e.g. can't drop FTS table with missing
                // custom tokenizer).  Delete the database and start fresh.
                logger.warning("SearchDatabase: schema migration failed, recreating: \(error)")
                PlanetLogger.log("SearchDatabase: schema migration failed, recreating", level: .warning)
                try openedPool.close()
                for suffix in ["", "-wal", "-shm"] {
                    try? FileManager.default.removeItem(atPath: dbPath + suffix)
                }
                openedPool = try DatabasePool(path: dbPath, configuration: config)
                needsRebuild = try Self.ensureSchema(openedPool)
            }
            pool = openedPool
            if needsRebuild {
                logger.info("SearchDatabase: schema version changed, will rebuild")
                PlanetLogger.log("SearchDatabase: schema version changed, will rebuild", level: .info)
            }
            logger.info("SearchDatabase opened at \(dbPath)")
            PlanetLogger.log("SearchDatabase opened at \(dbPath)", level: .info)
        } catch {
            pool = nil
            logger.error("SearchDatabase: failed to open at \(dbPath): \(error)")
            PlanetLogger.log("SearchDatabase: failed to open at \(dbPath): \(error)", level: .error)
        }
    }

    /// Check the stored schema version. If it doesn't match, drop everything
    /// and recreate.  Returns `true` when tables were recreated (caller should
    /// trigger a full rebuild).
    private static func ensureSchema(_ pool: DatabasePool) throws -> Bool {
        var needsRebuild = false

        try pool.write { db in
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS schema_version (
                    id INTEGER PRIMARY KEY CHECK (id = 1),
                    version INTEGER NOT NULL
                )
                """)

            let storedVersion = try Int.fetchOne(
                db, sql: "SELECT version FROM schema_version WHERE id = 1"
            )

            if storedVersion != schemaVersion {
                for table in ["articles_fts", "articles", "vectors"] {
                    try db.execute(sql: "DROP TABLE IF EXISTS \(table)")
                }
                for trigger in ["articles_ai", "articles_ad", "articles_au"] {
                    try db.execute(sql: "DROP TRIGGER IF EXISTS \(trigger)")
                }

                try createTables(db)

                try db.execute(sql: """
                    INSERT INTO schema_version (id, version) VALUES (1, \(schemaVersion))
                    ON CONFLICT(id) DO UPDATE SET version = excluded.version
                    """)

                needsRebuild = true
            }
        }

        return needsRebuild
    }

    /// Create all data tables, FTS virtual table, triggers, and indexes.
    private static func createTables(_ db: Database) throws {
        try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS articles (
                rowid INTEGER PRIMARY KEY,
                article_id TEXT UNIQUE NOT NULL,
                planet_id TEXT NOT NULL,
                planet_name TEXT NOT NULL,
                planet_kind INTEGER NOT NULL,
                title TEXT NOT NULL,
                content TEXT NOT NULL,
                preview_text TEXT,
                slug TEXT,
                tags TEXT,
                attachments TEXT,
                created_at REAL NOT NULL,
                content_hash TEXT NOT NULL
            )
            """)

        // Standalone FTS table — we manually sync tokenized content so the
        // articles table keeps clean original text for display while FTS
        // gets NLTokenizer-segmented CJK words appended for matching.
        try db.execute(sql: """
            CREATE VIRTUAL TABLE IF NOT EXISTS articles_fts USING fts5(
                title, content, tags, slug,
                content_rowid='rowid',
                tokenize='unicode61 remove_diacritics 2'
            )
            """)

        try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS vectors (
                article_id TEXT PRIMARY KEY,
                embedding BLOB NOT NULL,
                content_hash TEXT NOT NULL,
                language TEXT
            )
            """)

        try db.execute(sql: """
            CREATE INDEX IF NOT EXISTS idx_vectors_language ON vectors(language)
            """)
    }

    /// Serial queue for visibility-critical SearchIndex mutations.
    /// Embedding work is intentionally decoupled so semantic updates never
    /// block fresher add/delete visibility in keyword search.
    static let writeQueue = DispatchQueue(label: "xyz.planetable.SearchMutations", qos: .utility)

    /// Append NLTokenizer-segmented CJK words to the text so FTS5's
    /// unicode61 tokenizer can match them as individual tokens.
    static func tokenizeForFTS(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        guard text.unicodeScalars.contains(where: isCJKIdeograph) else { return text }

        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        var cjkTokens: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let token = String(text[range])
            if token.unicodeScalars.contains(where: isCJKIdeograph) {
                cjkTokens.append(token)
            }
            return true
        }
        guard !cjkTokens.isEmpty else { return text }
        return text + " " + cjkTokens.joined(separator: " ")
    }

    private static func isCJKIdeograph(_ scalar: Unicode.Scalar) -> Bool {
        let v = scalar.value
        return (0x4E00...0x9FFF).contains(v)
            || (0x3400...0x4DBF).contains(v)
            || (0x20000...0x2A6DF).contains(v)
            || (0x2A700...0x2B73F).contains(v)
            || (0x2B740...0x2B81F).contains(v)
            || (0xF900...0xFAFF).contains(v)
            || (0x2F800...0x2FA1F).contains(v)
    }

    /// Shared hash function for content-change detection.
    static func contentHash(title: String, content: String, tags: String = "", slug: String = "") -> String {
        var combined = title + "\n" + content
        if !tags.isEmpty || !slug.isEmpty {
            combined += "\n" + tags + "\n" + slug
        }
        var hash: UInt64 = 5381
        for byte in combined.utf8 {
            let b: UInt64 = numericCast(byte)
            hash = (hash &* 33) &+ b
        }
        return String(hash, radix: 16)
    }
}
