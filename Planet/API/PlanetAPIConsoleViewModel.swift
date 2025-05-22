//
//  PlanetAPIConsoleViewModel.swift
//  Planet
//

import Foundation
import SwiftUI
import Blackbird


class PlanetAPIConsoleViewModel: ObservableObject {
    static let shared = PlanetAPIConsoleViewModel()
    static let maxLength = 5000
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
            Task {
                await loadLogs()
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
        Task(priority: .utility) {
            await saveLog(entry)
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

    // MARK: ‑
    
    private func saveLog(_ entry: (timestamp: Date, statusCode: UInt, originIP: String, requestURL: String, errorDescription: String)) async {
        guard let db else { return }
        let ts = ISO8601DateFormatter().string(from: entry.timestamp)
        do {
            try await db.execute("""
                INSERT INTO things (type, date_created) VALUES ('log', '\(ts)');
            """)
            let idRow = try await db.query("SELECT last_insert_rowid() AS id;")
            guard let thingID = idRow.first?["id"]?.intValue else { return }

            let attributes: [String:String] = [
                "statusCode": String(entry.statusCode),
                "originIP": entry.originIP,
                "requestURL": entry.requestURL,
                "errorDescription": entry.errorDescription
            ]

            for (key, value) in attributes {
                let k = sqlEscape(key)
                let v = sqlEscape(value)
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
            debugPrint("Error saving log entry: \(error)")
        }
    }

    private func loadLogs() async {
        guard let db else { return }
        do {
            let rows = try await db.query("""
                SELECT t.date_created,
                       MAX(CASE WHEN d.key='statusCode'      THEN d.value END) AS statusCode,
                       MAX(CASE WHEN d.key='originIP'        THEN d.value END) AS originIP,
                       MAX(CASE WHEN d.key='requestURL'      THEN d.value END) AS requestURL,
                       MAX(CASE WHEN d.key='errorDescription' THEN d.value END) AS errorDescription
                FROM things t
                JOIN data d ON d.thing_id = t.id
                WHERE t.type='log'
                GROUP BY t.id
                ORDER BY t.date_created DESC
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
            
            let updatedLogs = buffer
            await MainActor.run {
                logs = updatedLogs
            }
        } catch {
            debugPrint("Failed to load logs: \(error)")
        }
    }
    
    private func sqlEscape(_ string: String) -> String {
        string.replacingOccurrences(of: "'", with: "''")
    }
}
