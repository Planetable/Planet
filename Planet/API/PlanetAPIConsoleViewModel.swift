//
//  PlanetAPIConsoleViewModel.swift
//  Planet
//

import Foundation
import SwiftUI
import Blackbird


class PlanetAPIConsoleViewModel: ObservableObject {
    static let shared = PlanetAPIConsoleViewModel()
    static let maxLength: Int = 2000
    static let baseFontKey: String = "APIConsoleBaseFontSizeKey"
    
    var database: Blackbird.Database?

    @Published var isShowingConsoleWindow = false
    @Published private(set) var baseFontSize: CGFloat {
        didSet {
            UserDefaults.standard.set(baseFontSize, forKey: Self.baseFontKey)
        }
    }
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var keyword: String

    init() {
        var fontSize = CGFloat(UserDefaults.standard.float(forKey: Self.baseFontKey))
        if fontSize == 0 {
            fontSize = 12
        }
        baseFontSize = fontSize
        
        let planetPath = URLUtils.documentsPath.appendingPathComponent("Planet")
        try? FileManager.default.createDirectory(at: planetPath, withIntermediateDirectories: true)
        let apiPath = planetPath.appendingPathComponent("API")
        try? FileManager.default.createDirectory(at: apiPath, withIntermediateDirectories: true)
        let dbURL = apiPath.appendingPathComponent("log.sqlite")
        do {
            database = try Blackbird.Database(path: dbURL.path)
            debugPrint("API console database loaded at: \(dbURL.path)")
        } catch {
            debugPrint("Failed to load API console database: \(error)")
        }
        
        keyword = ""
    }

    func addLog(statusCode: UInt, originIP: String, requestURL: String, errorDescription: String = "") async {
        guard let database = self.database else { return }
        let now = Date()
        let entry: PlanetAPILogEntry = PlanetAPILogEntry(timestamp: now, statusCode: Int(statusCode), originIP: originIP, requestURL: requestURL, errorDescription: errorDescription)
        do {
            try await entry.write(to: database)
            await MainActor.run {
                self.lastUpdated = now
            }
        } catch {
            debugPrint("Failed to save API log entry: \(error)")
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
    func updateKeyword(_ k: String) {
        keyword = k
    }
    
    func clearLogs() {
        guard let database else { return }
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
        Task(priority: .utility) {
            do {
                try await PlanetAPILogEntry.delete(from: database, matching: .all)
                await MainActor.run {
                    self.lastUpdated = Date()
                }
            } catch {
                debugPrint("Failed to delete API log entries: \(error)")
            }
        }
    }
}
