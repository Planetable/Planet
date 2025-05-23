//
//  PlanetAPIConsoleViewModel.swift
//  Planet
//

import Foundation
import SwiftUI
import Blackbird


class PlanetAPIConsoleViewModel: ObservableObject {
    static let shared = PlanetAPIConsoleViewModel()
    static let maxLength = 2000     // Maximum number of log output lines to display (does not affect export).
    static let baseFontKey = "APIConsoleBaseFontSizeKey"

    var db: Blackbird.Database?

    @Published var isShowingConsoleWindow = false
    @Published private(set) var baseFontSize: CGFloat {
        didSet {
            UserDefaults.standard.set(baseFontSize, forKey: Self.baseFontKey)
        }
    }

    @Published private(set) var logs: [(
        timestamp: Date,
        statusCode: UInt,
        originIP: String,
        requestURL: String,
        errorDescription: String
    )] = []

    init() {
        // Font size
        let savedSize = CGFloat(UserDefaults.standard.float(forKey: Self.baseFontKey))
        baseFontSize = savedSize == 0 ? 12 : savedSize

        let planetPath = URLUtils.documentsPath.appendingPathComponent("Planet")
        try? FileManager.default.createDirectory(at: planetPath, withIntermediateDirectories: true)
        let apiPath = planetPath.appendingPathComponent("API")
        try? FileManager.default.createDirectory(at: apiPath, withIntermediateDirectories: true)
        let dbURL = apiPath.appendingPathComponent("log.sqlite")
        do {
            db = try Blackbird.Database(path: dbURL.path)
            debugPrint("API console database loaded at: \(dbURL.path)")
            Task.detached(priority: .utility) {
                await self.initSchema()
                guard let savedLogs = await self.loadLogs() else { return }
                await MainActor.run {
                    self.logs = savedLogs
                }
            }
        } catch {
            debugPrint("Failed to load API console database: \(error)")
        }
    }

    @MainActor
    func addLog(statusCode: UInt, originIP: String, requestURL: String, errorDescription: String = "") {
        let now = Date()
        let entry = (timestamp: now, statusCode: statusCode, originIP: originIP, requestURL: requestURL, errorDescription: errorDescription)
        logs.append(entry)
        if logs.count > Self.maxLength { logs = Array(logs.suffix(Self.maxLength)) }
        Task.detached(priority: .background) {
            await self.saveLog(entry)
        }
    }
    
    @MainActor
    func decreaseFontSize() {
        if baseFontSize > 9 {
            baseFontSize -= 1
        }
    }

    @MainActor
    func increaseFontSize() {
        baseFontSize += 1
    }
    
    @MainActor
    func resetFontSize() {
        baseFontSize = 12
    }
    
    @MainActor
    func clearLogs() {
        logs.removeAll()
        Task.detached(priority: .utility) {
            guard let db = self.db else { return }
            do {
                try await db.execute("DELETE FROM data WHERE thing_id IN (SELECT id FROM things WHERE type='log');")
                try await db.execute("DELETE FROM things WHERE type='log';")
            } catch {
                debugPrint("Error clearing logs in DB: \(error)")
            }
        }
    }
    
    @MainActor
    func exportLogs() {
        // MARK: TODO: Export logs loaded from database, ask user to choose a save destination, save as logs_[from_date]_[end_date].txt
    }

    // MARK: ‑
    
    private func initSchema() async {
        guard let db else { return }
        do {
            try await db.execute("""
                CREATE TABLE IF NOT EXISTS things (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    type TEXT NOT NULL,
                    date_created TEXT NOT NULL
                );
            """)
            try await db.execute("""
                CREATE TABLE IF NOT EXISTS data (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    thing_id INTEGER NOT NULL REFERENCES things(id),
                    key TEXT NOT NULL,
                    value TEXT,
                    UNIQUE(thing_id, key)
                );
            """)
        } catch {
            debugPrint("Failed to create schema for database: \(error)")
        }
    }

    private func saveLog(_ entry: (timestamp: Date, statusCode: UInt, originIP: String, requestURL: String, errorDescription: String)) async {
        guard let db else { return }
        let ts = ISO8601DateFormatter().string(from: entry.timestamp)
        do {
            try await db.execute("""
                INSERT INTO things (type, date_created) VALUES ('log', '\(ts)');
            """)
            let lastRowID = try await db.query("SELECT last_insert_rowid() AS id;")
            guard let thingID = lastRowID.first?["id"]?.intValue else { return }

            let attributes: [String: String] = [
                "statusCode": String(entry.statusCode),
                "originIP": entry.originIP,
                "requestURL": entry.requestURL,
                "errorDescription": entry.errorDescription
            ]

            for (key, value) in attributes {
                let k = key.sqlEscaped()
                let v = value.sqlEscaped()
                try await db.execute("""
                    INSERT INTO data (thing_id, key, value) VALUES (\(thingID), '\(k)', '\(v)');
                """)
            }

            try await db.execute("""
                DELETE FROM things WHERE id IN (
                    SELECT id FROM things WHERE type = 'log' ORDER BY date_created DESC LIMIT -1 OFFSET \(Self.maxLength)
                );
            """)
        } catch {
            debugPrint("Failed to save log to database: \(error)")
        }
    }

    private func loadLogs() async -> [(timestamp: Date, statusCode: UInt, originIP: String, requestURL: String, errorDescription: String)]? {
        guard let db else { return nil }
        do {
            let rows = try await db.query("""
                SELECT t.date_created,
                       MAX(CASE WHEN d.key='statusCode' THEN d.value END) AS statusCode,
                       MAX(CASE WHEN d.key='originIP' THEN d.value END) AS originIP,
                       MAX(CASE WHEN d.key='requestURL' THEN d.value END) AS requestURL,
                       MAX(CASE WHEN d.key='errorDescription' THEN d.value END) AS errorDescription
                FROM things t
                JOIN data d ON d.thing_id = t.id
                WHERE t.type='log'
                GROUP BY t.id
                ORDER BY t.date_created
                LIMIT \(Self.maxLength);
            """)

            var buffer: [(
                timestamp: Date,
                statusCode: UInt,
                originIP: String,
                requestURL: String,
                errorDescription: String
            )] = []

            let iso = ISO8601DateFormatter()
            for row in rows {
                guard
                    let tsStr = row["date_created"]?.stringValue,
                    let ts = iso.date(from: tsStr),
                    let scStr = row["statusCode"]?.stringValue,
                    let sc = UInt(scStr),
                    let ip = row["originIP"]?.stringValue,
                    let url = row["requestURL"]?.stringValue,
                    let err = row["errorDescription"]?.stringValue
                else { continue }
                buffer.append((ts, sc, ip, url, err))
            }
            return buffer
        } catch {
            debugPrint("Failed to load logs: \(error)")
        }
        return nil
    }
}
