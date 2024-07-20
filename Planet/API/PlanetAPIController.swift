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
        let builder: RoutesBuilder = {
            let auth = authMiddleware()
            if let auth {
                return app.grouped(auth)
            } else {
                return app
            }
        }()

        //MARK: GET /v0/id
        /// Return IPFS ID
        builder.get("v0", "id") { req async throws -> String in
            return try await self.routeGetID(fromRequest: req)
        }
        
        //MARK: GET /v0/ping
        /// Simple ping/pong test for authenticated user.
        builder.get("v0", "ping") { req async throws -> String in
            return try await self.routeGetPing(fromRequest: req)
        }
        
        //MARK: GET /v0/info
        /// Return ServerInfo
        ///
        /// ### Contents of ServerInfo
        ///
        /// - ``hostName``: String
        /// - ``version``: String
        /// - ``ipfsPeerID``: String
        /// - ``ipfsPeerCount``: Int
        /// - ``ipfsVersion``: String
        builder.get("v0", "info") { req async throws -> Response in
            return try await self.routeGetServerInfo(fromRequest: req)
        }

        // GET,POST /v0/planets/my
        builder.get("v0", "planets", "my") { req async throws -> Response in
            return try await self.routeGetPlanets(fromRequest: req)
        }
        builder.on(.POST, "v0", "planets", "my", body: .collect(maxSize: "5mb")) { req async throws -> Response in
            return try await self.routePostCreatePlanet(fromRequest: req)
        }
        
        // GET,POST,DELETE /v0/planets/my/:a


        // POST /v0/planets/my/:a/publish


        // GET,POST /v0/planets/my/:a/articles


        // GET,POST,DELETE /v0/planets/my/:a/articles/:b


        // MARK: TODO: use body steam to handle large size payloads
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
    
    // MARK: -
    
    private func routeGetID(fromRequest req: Request) async throws -> String {
        let data = try await IPFSDaemon.shared.api(path: "id")
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        var id: String?
        if let dict = json as? [String: Any] {
            id = dict["ID"] as? String
        } else if let dict = json as? [String: String] {
            id = dict["ID"]
        }
        if let id {
            return id
        }
        throw Abort(.notFound)
    }
    
    private func routeGetPing(fromRequest req: Request) async throws -> String {
        return "pong"
    }
    
    private func routeGetServerInfo(fromRequest req: Request) async throws -> Response {
        if let info = IPFSState.shared.serverInfo {
            let encoder = JSONEncoder()
            let data = try encoder.encode(info)
            let response = Response(status: .ok, body: .init(data: data))
            response.headers.contentType = .json
            return response
        }
        throw Abort(.notFound)
    }
    
    private func routeGetPlanets(fromRequest req: Request) async throws -> Response {
        let planets = PlanetAPI.shared.myPlanets
        let encoder = JSONEncoder()
        let data = try encoder.encode(planets)
        let response = Response(status: .ok, body: .init(data: data))
        response.headers.contentType = .json
        return response
    }
    
    private func routePostCreatePlanet(fromRequest req: Request) async throws -> Response {
        let p: APIPlanet = try req.content.decode(APIPlanet.self)
        guard p.name != "" else {
            throw Abort(.badRequest, reason: "Parameter 'name' is empty.")
        }
        let planetTemplateName: String = {
            if !TemplateStore.shared.templates.contains(where: { t in
                return t.name.lowercased() == p.template.lowercased()
            }) {
                return TemplateStore.shared.templates.first!.name
            }
            return p.template
        }()
        let planet = try await MyPlanetModel.create(
            name: p.name,
            about: p.about,
            templateName: planetTemplateName
        )
        if let avatarData = p.avatar, let avatarImage = NSImage(data: avatarData) {
            try planet.uploadAvatar(image: avatarImage)
        }
        try planet.save()
        try await planet.savePublic()
        let encoder = JSONEncoder()
        let responsePayload = try encoder.encode(planet)
        let response = Response(status: .created, body: .init(data: responsePayload))
        response.headers.contentType = .json
        defer {
            Task { @MainActor in
                PlanetStore.shared.myPlanets.insert(planet, at: 0)
                PlanetStore.shared.selectedView = .myPlanet(planet)
            }
        }
        return response
    }
}
