//
//  PlanetAPIController.swift
//  Planet
//

import Foundation
import SwiftUI
import Vapor


class PlanetAPIController: NSObject, ObservableObject {
    static let shared = PlanetAPIController()
    
    var globalApp: Application?
    
    @Published var serverIsRunning: Bool = false
    
    private(set) var apiPort: String
    private(set) var apiEnabled: Bool
    private(set) var apiUsername: String
    private(set) var apiUsesPasscode: Bool

    override init() {
        debugPrint("Planet API Controller Init.")
        let defaults = UserDefaults.standard
        if defaults.value(forKey: .settingsAPIPort) == nil {
            defaults.set("8086", forKey: .settingsAPIPort)
        }
        if defaults.value(forKey: .settingsAPIEnabled) == nil {
            defaults.set(false, forKey: .settingsAPIEnabled)
        }
        if defaults.value(forKey: .settingsAPIUsername) == nil {
            defaults.set("Planet", forKey: .settingsAPIUsername)
        }
        // Disable api authentication if no passcode found.
        do {
            let passcode = try KeychainHelper.shared.loadValue(forKey: .settingsAPIPasscode)
            if passcode == "" {
                defaults.set(false, forKey: .settingsAPIUsesPasscode)
            }
        } catch {
            defaults.set(false, forKey: .settingsAPIUsesPasscode)
        }
        apiPort = defaults.string(forKey: .settingsAPIPort) ?? "8086"
        apiEnabled = defaults.bool(forKey: .settingsAPIEnabled)
        apiUsername = defaults.string(forKey: .settingsAPIUsername) ?? "Planet"
        apiUsesPasscode = defaults.bool(forKey: .settingsAPIUsesPasscode)
    }
    
    func startServer() {
        guard globalApp == nil else { return }
        do {
            let env = try Environment.detect()
            let app = Application(env)
            globalApp = app
            try configure(app)
            DispatchQueue.global().async {
                do {
                    try app.run()
                } catch {
                    self.stopServer()
                }
            }
            DispatchQueue.main.async {
                self.serverIsRunning = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.saveServerSettings()
            }
        } catch {
            stopServer()
        }
    }

    func stopServer() {
        globalApp?.shutdown()
        globalApp = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.serverIsRunning = false
        }
    }

    // MARK: -
    
    private func saveServerSettings() {
        guard serverIsRunning else { return }
        // update server info
    }
    
    private func routes(_ app: Application) throws {
        // GET route
        app.get("v0", "info") { req async throws -> [String: String] in
            let dateFormatter = ISO8601DateFormatter()
            let timestamp = dateFormatter.string(from: Date())
            try await Task.sleep(nanoseconds: 1_000_000_000)
            return ["timestamp": timestamp]
        }
    }
    
    private func configure(_ app: Application) throws {
        let port: Int = {
            if let p = Int(apiPort) {
                return p
            }
            return 9191
        }()
        app.http.server.configuration.port = port
        
        let repoPath: String = {
            if #available(macOS 13.0, *) {
                return URLUtils.repoPath().appendingPathComponent("Public", conformingTo: .folder).path()
            } else {
                return URLUtils.repoPath().appendingPathComponent("Public", conformingTo: .folder).path
            }
        }()
        let fileMiddleware = FileMiddleware(publicDirectory: repoPath, defaultFile: "index.html")
        app.middleware.use(fileMiddleware)

        try routes(app)
    }
}
