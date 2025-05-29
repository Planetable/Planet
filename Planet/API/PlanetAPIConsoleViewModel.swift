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

    @Published private(set) var logs: [
        (
            timestamp: Date,
            statusCode: UInt,
            originIP: String,
            requestURL: String,
            errorDescription: String
        )
    ] = []

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
            guard let database else { return }
            Task.detached(priority: .utility) {
                let savedLogs: [PlanetAPILogEntry] = try! await PlanetAPILogEntry.read(from: database)
                Task { @MainActor in
                    self.logs = savedLogs.map { l in
                        return (
                            timestamp: l.timestamp,
                            statusCode: UInt(l.statusCode),
                            originIP: l.originIP,
                            requestURL: l.requestURL,
                            errorDescription: l.errorDescription
                        )
                    }
                    if self.logs.count > Self.maxLength {
                        self.logs = Array(self.logs.suffix(Self.maxLength))
                    }
                }
            }
        } catch {
            debugPrint("Failed to load API console database: \(error)")
        }
    }

    @MainActor
    func addLog(statusCode: UInt, originIP: String, requestURL: String, errorDescription: String = "") {
        let now = Date()
        let logEntry = (timestamp: now, statusCode: statusCode, originIP: originIP, requestURL: requestURL, errorDescription: errorDescription)
        logs.append(logEntry)
        if logs.count > Self.maxLength {
            logs = Array(logs.suffix(Self.maxLength))
        }
        Task.detached(priority: .background) {
            guard let database = self.database else { return }
            let entry: PlanetAPILogEntry = PlanetAPILogEntry(timestamp: now, statusCode: Int(statusCode), originIP: originIP, requestURL: requestURL, errorDescription: errorDescription)
            do {
                try await entry.write(to: database)
                debugPrint("Saved log entry: \(entry) to API console database")
            } catch {
                debugPrint("Failed to save API log entry: \(error)")
            }
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
    }
}
