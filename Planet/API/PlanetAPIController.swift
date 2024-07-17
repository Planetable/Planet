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
    
    @Published var serverIsRunning: Bool = false {
        didSet {
            UserDefaults.standard.set(serverIsRunning, forKey: .settingsAPIEnabled)
        }
    }

    override init() {
        super.init()
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
        if defaults.value(forKey: .settingsAPIUsesPasscode) == nil {
            defaults.set(false, forKey: .settingsAPIUsesPasscode)
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
        if defaults.bool(forKey: .settingsAPIEnabled) {
            Task.detached(priority: .background) {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                self.startServer()
            }
        }
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
            if let portString = UserDefaults.standard.string(forKey: .settingsAPIPort), let p = Int(portString) {
                return p
            }
            UserDefaults.standard.set("8086", forKey: .settingsAPIPort)
            return 8086
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
