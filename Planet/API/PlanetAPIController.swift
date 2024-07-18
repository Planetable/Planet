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

    private var bonjourService: PlanetAPIService?

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
                Task { @MainActor in
                    self.startServer()
                }
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
        } catch {
            stopServer()
        }
        startBonjourService()
    }

    func stopServer() {
        globalApp?.shutdown()
        globalApp = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.serverIsRunning = false
        }
        stopBonjourService()
    }
    
    func startBonjourService() {
        if bonjourService == nil {
            if let portString = UserDefaults.standard.string(forKey: .settingsAPIPort), let p = Int(portString) {
                bonjourService = PlanetAPIService(p)
            }
        }
    }
    
    func stopBonjourService() {
        bonjourService?.stopService()
        bonjourService = nil
    }

    // MARK: -
    
    private func routes(_ app: Application) throws {
        // GET route
        if let auth = authMiddleware() {
            app.grouped(auth).get("v0", "info") { req async throws -> [String: String] in
                let dateFormatter = ISO8601DateFormatter()
                let timestamp = dateFormatter.string(from: Date())
                try await Task.sleep(nanoseconds: 1_000_000_000)
                return ["timestamp": timestamp]
            }
        } else {
            app.get("v0", "info") { req async throws -> [String: String] in
                let dateFormatter = ISO8601DateFormatter()
                let timestamp = dateFormatter.string(from: Date())
                try await Task.sleep(nanoseconds: 1_000_000_000)
                return ["timestamp": timestamp]
            }
        }
        
        // GET /v0/id
        
        // GET /v0/info
        
        // GET /v0/ping
        
        // GET,POST /v0/planets/my
        
        // GET,POST,DELETE /v0/planets/my/:a
        
        // POST /v0/planets/my/:a/publish
        
        // GET,POST /v0/planets/my/:a/articles
        
        // GET,POST,DELETE /v0/planets/my/:a/articles/:b
    }
    
    private func configure(_ app: Application) throws {
        let defaults = UserDefaults.standard
        let port: Int = {
            if let portString = defaults.string(forKey: .settingsAPIPort), let p = Int(portString) {
                return p
            }
            defaults.set("8086", forKey: .settingsAPIPort)
            return 8086
        }()
        app.http.server.configuration.port = port
        
        if let authMiddleware = authMiddleware() {
            app.middleware.use(authMiddleware)
        }

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
    
    private func authMiddleware() -> PlanetAPIAuthMiddleware? {
        if UserDefaults.standard.bool(forKey: .settingsAPIUsesPasscode) {
            if let username = UserDefaults.standard.string(forKey: .settingsAPIUsername), username != "", let password = try? KeychainHelper.shared.loadValue(forKey: .settingsAPIPasscode) {
                return PlanetAPIAuthMiddleware(username: username, password: password)
            }
        }
        return nil
    }
}
