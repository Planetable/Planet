//
//  PlanetAPIConsoleViewModel.swift
//  Planet
//

import Foundation
import SwiftUI
import Blackbird


class PlanetAPIConsoleViewModel: ObservableObject {
    static let shared = PlanetAPIConsoleViewModel()
    static let maxLength = 2000         // Maximum number of log output lines to display (does not affect export).
    static let maxStorageDays = 30      // Maximum days of log
    static let baseFontKey = "APIConsoleBaseFontSizeKey"
    
    var db: Blackbird.Database?
    
    private var lastCleanup = Date.distantPast
    
    @Published var isShowingConsoleWindow = false
    @Published private(set) var baseFontSize: CGFloat {
        didSet {
            UserDefaults.standard.set(baseFontSize, forKey: Self.baseFontKey)
        }
    }
    @Published private(set) var logs: [APILogEntry] = []
    
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
        let alert = NSAlert()
        alert.messageText = "Clear All Logs"
        alert.informativeText = "This will permanently delete all console logs and saved log data. This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear Logs")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else {
            return
        }
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
        Task.detached(priority: .utility) {
            guard let allLogs = await self.loadLogs() else {
                await MainActor.run {
                    let alert = NSAlert()
                    alert.messageText = "Export Failed"
                    alert.informativeText = "Unable to load logs from database."
                    alert.alertStyle = .warning
                    alert.runModal()
                }
                return
            }
            
            guard !allLogs.isEmpty else {
                await MainActor.run {
                    let alert = NSAlert()
                    alert.messageText = "No Logs to Export"
                    alert.informativeText = "There are no logs available to export."
                    alert.alertStyle = .informational
                    alert.runModal()
                }
                return
            }
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let fromDate = allLogs.first?.timestamp ?? Date()
            let toDate = allLogs.last?.timestamp ?? Date()
            let fromStr = dateFormatter.string(from: fromDate)
            let toStr = dateFormatter.string(from: toDate)
            let baseFilename = "logs_\(fromStr)_\(toStr).txt"
            
            await MainActor.run {
                let savePanel = NSSavePanel()
                savePanel.nameFieldStringValue = baseFilename
                savePanel.allowedContentTypes = [.plainText]
                savePanel.canCreateDirectories = true
                savePanel.title = "Export Logs"
                let response = savePanel.runModal()
                guard response == .OK, let url = savePanel.url else { return }
                Task.detached(priority: .utility) {
                    await self.writeLogsToFile(allLogs, url: url)
                }
            }
        }
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
            // Add indexes for better query performance
            try await db.execute("""
                CREATE INDEX IF NOT EXISTS idx_things_type_date ON things(type, date_created);
            """)
            try await db.execute("""
                CREATE INDEX IF NOT EXISTS idx_data_thing_key ON data(thing_id, key);
            """)
        } catch {
            debugPrint("Failed to create schema for database: \(error)")
        }
    }
    
    private func validateLogEntry(_ entry: APILogEntry) -> Bool {
        guard entry.statusCode >= 100 && entry.statusCode < 600 else { return false }
        guard !entry.requestURL.isEmpty else { return false }
        return true
    }
    
    private func saveLog(_ entry: APILogEntry) async {
        guard let db else { return }
        guard validateLogEntry(entry) else { return }
        let ts = ISO8601DateFormatter().string(from: entry.timestamp)
        do {
            try await db.query(
                "INSERT INTO things (type, date_created) VALUES (?, ?)",
                "log",
                ts
            )
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
                try await db.query(
                    "INSERT INTO data (thing_id, key, value) VALUES (?, ?, ?)",
                    thingID,
                    k,
                    v
                )
            }
            
            Task.detached(priority: .background) {
                await self.cleanupOldLogs()
            }
        } catch {
            debugPrint("Failed to save log to database: \(error)")
        }
    }
    
    private func loadLogs() async -> [APILogEntry]? {
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
            var buffer: [APILogEntry] = []
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
    
    private func writeLogsToFile(_ logs: [APILogEntry], url: URL) async {
        do {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            var content = "API Console Logs\n"
            content += "Exported on: \(dateFormatter.string(from: Date()))\n"
            content += "Total entries: \(logs.count)\n"
            content += String(repeating: "=", count: 50) + "\n\n"
            for log in logs {
                content += "[\(dateFormatter.string(from: log.timestamp))] "
                content += "Status: \(log.statusCode) | "
                content += "IP: \(log.originIP) | "
                content += "URL: \(log.requestURL)"
                if !log.errorDescription.isEmpty {
                    content += " | Error: \(log.errorDescription)"
                }
                content += "\n"
            }
            try content.write(to: url, atomically: true, encoding: .utf8)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            await MainActor.run {
                let alert = NSAlert()
                alert.messageText = "Export Failed"
                alert.informativeText = "Failed to write logs to file: \(error.localizedDescription)"
                alert.alertStyle = .critical
                alert.runModal()
            }
        }
    }
    
    private func cleanupOldLogs() async {
        let now = Date()
        guard now.timeIntervalSince(lastCleanup) > 3600 else { return }
        lastCleanup = now
        guard let db else { return }
        do {
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -Self.maxStorageDays, to: now)!
            let cutoffString = ISO8601DateFormatter().string(from: cutoffDate)
            try await db.execute("""
                DELETE FROM data WHERE thing_id IN (
                    SELECT id FROM things 
                    WHERE type = 'log' AND date_created < '\(cutoffString)'
                );
            """)
            try await db.execute("""
                DELETE FROM things 
                WHERE type = 'log' AND date_created < '\(cutoffString)';
            """)
            debugPrint("Cleaned up old logs (older than \(Self.maxStorageDays) days)")
        } catch {
            debugPrint("Failed to cleanup old logs: \(error)")
        }
    }
}
