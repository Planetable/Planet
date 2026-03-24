//
//  SearchDatabase.swift
//  Planet
//

import Foundation
import GRDB
import os

/// Shared database for the search index and vector embeddings.
/// Both SearchIndex and SearchEmbedding use this single DatabasePool
/// to avoid WAL contention from multiple connections to the same file.
final class SearchDatabase: Sendable {
    static let shared = SearchDatabase()

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
            let openedPool = try DatabasePool(path: dbPath, configuration: config)
            try Self.migrate(openedPool)
            pool = openedPool
            logger.info("SearchDatabase opened at \(dbPath)")
            PlanetLogger.log("SearchDatabase opened at \(dbPath)", level: .info)
        } catch {
            pool = nil
            logger.error("SearchDatabase: failed to open at \(dbPath): \(error)")
            PlanetLogger.log("SearchDatabase: failed to open at \(dbPath): \(error)", level: .error)
        }
    }

    /// Run all migrations for every table in search.sqlite.
    /// Called once during init so that table creation order is guaranteed
    /// regardless of which singleton (SearchIndex / SearchEmbedding) is accessed first.
    private static func migrate(_ pool: DatabasePool) throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_create_tables") { db in
            // -- articles + FTS (used by SearchIndex) --
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

            try db.execute(sql: """
                CREATE VIRTUAL TABLE IF NOT EXISTS articles_fts USING fts5(
                    title, content, tags, slug,
                    content='articles',
                    content_rowid='rowid',
                    tokenize='unicode61 remove_diacritics 2'
                )
                """)

            try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS articles_ai AFTER INSERT ON articles BEGIN
                    INSERT INTO articles_fts(rowid, title, content, tags, slug)
                    VALUES (new.rowid, new.title, new.content, new.tags, new.slug);
                END
                """)

            try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS articles_ad AFTER DELETE ON articles BEGIN
                    INSERT INTO articles_fts(articles_fts, rowid, title, content, tags, slug)
                    VALUES ('delete', old.rowid, old.title, old.content, old.tags, old.slug);
                END
                """)

            try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS articles_au AFTER UPDATE ON articles BEGIN
                    INSERT INTO articles_fts(articles_fts, rowid, title, content, tags, slug)
                    VALUES ('delete', old.rowid, old.title, old.content, old.tags, old.slug);
                    INSERT INTO articles_fts(rowid, title, content, tags, slug)
                    VALUES (new.rowid, new.title, new.content, new.tags, new.slug);
                END
                """)

            // -- vectors (used by SearchEmbedding) --
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS vectors (
                    article_id TEXT PRIMARY KEY,
                    embedding BLOB NOT NULL,
                    content_hash TEXT NOT NULL
                )
                """)
        }

        try migrator.migrate(pool)
    }

    /// Serial queue for visibility-critical SearchIndex mutations.
    /// Embedding work is intentionally decoupled so semantic updates never
    /// block fresher add/delete visibility in keyword search.
    static let writeQueue = DispatchQueue(label: "xyz.planetable.SearchMutations", qos: .utility)

    /// Shared hash function for content-change detection.
    static func contentHash(title: String, content: String) -> String {
        let combined = title + "\n" + content
        var hash: UInt64 = 5381
        for byte in combined.utf8 {
            let b: UInt64 = numericCast(byte)
            hash = (hash &* 33) &+ b
        }
        return String(hash, radix: 16)
    }
}
