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
        
        //MARK: - GET /v0/id
        /// Return IPFS ID
        builder.get("v0", "id") { req async throws -> String in
            return try await self.routeGetID(fromRequest: req)
        }
        
        //MARK: - GET /v0/ping
        /// Simple ping/pong test for authenticated user.
        builder.get("v0", "ping") { req async throws -> String in
            return try await self.routePing(fromRequest: req)
        }
        
        //MARK: - GET /v0/info
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
        
        //MARK: - GET /v0/planets/my
        builder.get("v0", "planets", "my") { req async throws -> Response in
            return try await self.routeGetPlanets(fromRequest: req)
        }

        //MARK: - POST /v0/planets/my
        builder.on(.POST, "v0", "planets", "my", body: .collect(maxSize: "5mb")) { req async throws -> Response in
            return try await self.routeCreatePlanet(fromRequest: req)
        }
        
        //MARK: - GET /v0/planets/my/:uuid
        builder.get("v0", "planets", "my", ":uuid") { req async throws -> Response in
            return try await self.routeGetPlanetInfo(fromRequest: req)
        }
        //MARK: POST /v0/planets/my/:uuid
        builder.on(.POST, "v0", "planets", "my", ":uuid", body: .collect(maxSize: "5mb")) { req async throws -> Response in
            return try await self.routeModifyPlanetInfo(fromRequest: req)
        }
        //MARK: DELETE /v0/planets/my/:uuid
        builder.delete("v0", "planets", "my", ":uuid") { req async throws -> Response in
            return try await self.routeDeletePlanet(fromRequest: req)
        }
        
        //MARK: - POST /v0/planets/my/:uuid/publish
        builder.post("v0", "planets", "my", ":uuid", "publish") { req async throws -> Response in
            return try await self.routePublishPlanet(fromRequest: req)
        }
        
        
        //MARK: - GET /v0/planets/my/:uuid/articles
        builder.get("v0", "planets", "my", ":uuid", "articles") { req async throws -> Response in
            return try await self.routeGetPlanetArticles(fromRequest: req)
        }
        //MARK: POST /v0/planets/my/:uuid/articles
        builder.on(.POST, "v0", "planets", "my", ":uuid", "articles", body: .collect(maxSize: "50mb")) { req async throws -> Response in
            return try await self.routeCreatePlanetArticle(fromRequest: req)
        }

        
        //MARK: GET,POST,DELETE /v0/planets/my/:a/articles/:b
        
        
        //MARK: GET /v0/planets/my/:uuid/public
        app.get("v0", "planets", "my", ":uuid", "public") { req async throws -> Response in
            let planet = try self.getPlanetByUUID(fromRequest: req)
            let redirectURL = URI(string: "/\(planet.id.uuidString)/")
            return req.redirect(to: redirectURL.string, redirectType: .temporary)
        }
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
    
    private func getPlanetByUUID(fromRequest req: Request) throws -> MyPlanetModel {
        guard let uuidString = req.parameters.get("uuid"),
              let uuid = UUID(uuidString: uuidString) else {
            throw Abort(.badRequest, reason: "Invalid UUID format.")
        }
        guard let planet = PlanetAPI.shared.myPlanets.first(where: { $0.id == uuid }) else {
            throw Abort(.notFound, reason: "Planet not found.")
        }
        return planet
    }
    
    private func createResponse<T: Encodable>(from value: T, status: HTTPResponseStatus) throws -> Response {
        let encoder = JSONEncoder()
        let responsePayload = try encoder.encode(value)
        let response = Response(status: status, body: .init(data: responsePayload))
        response.headers.contentType = .json
        return response
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
    
    private func routePing(fromRequest req: Request) async throws -> String {
        return "pong"
    }
    
    private func routeGetServerInfo(fromRequest req: Request) async throws -> Response {
        if let info = IPFSState.shared.serverInfo {
            return try self.createResponse(from: info, status: .ok)
        }
        throw Abort(.notFound)
    }
    
    private func routeGetPlanets(fromRequest req: Request) async throws -> Response {
        let planets = PlanetAPI.shared.myPlanets
        return try self.createResponse(from: planets, status: .ok)
    }
    
    private func routeCreatePlanet(fromRequest req: Request) async throws -> Response {
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
        try await MainActor.run {
            if let avatarData = p.avatar, let avatarImage = NSImage(data: avatarData) {
                do {
                    try planet.uploadAvatar(image: avatarImage)
                } catch {
                    throw error
                }
            }
        }
        try planet.save()
        try await planet.savePublic()
        defer {
            Task.detached(priority: .utility) {
                Task { @MainActor in
                    PlanetStore.shared.myPlanets.insert(planet, at: 0)
                    PlanetStore.shared.selectedView = .myPlanet(planet)
                }
            }
        }
        return try self.createResponse(from: planet, status: .created)
    }
    
    private func routeGetPlanetInfo(fromRequest req: Request) async throws -> Response {
        let planet = try getPlanetByUUID(fromRequest: req)
        return try self.createResponse(from: planet, status: .created)
    }
    
    private func routeModifyPlanetInfo(fromRequest req: Request) async throws -> Response {
        let planet = try getPlanetByUUID(fromRequest: req)
        let p: APIModifyPlanet = try req.content.decode(APIModifyPlanet.self)
        let planetName = p.name ?? ""
        let planetAbout = p.about ?? ""
        let planetTemplateName = p.template ?? ""
        try await MainActor.run {
            if planetName != "" {
                planet.name = planetName
            }
            if planetAbout != "" {
                planet.about = planetAbout
            }
            if planetTemplateName != "" {
                planet.templateName = planetTemplateName
            }
            if let avatarData = p.avatar, let avatarImage = NSImage(data: avatarData) {
                do {
                    try planet.uploadAvatar(image: avatarImage)
                } catch {
                    throw error
                }
            }
        }
        try planet.save()
        try planet.copyTemplateAssets()
        try planet.articles.forEach { try $0.savePublic() }
        try await planet.savePublic()
        defer {
            Task.detached(priority: .utility) {
                Task { @MainActor in
                    NotificationCenter.default.post(name: .loadArticle, object: nil)
                }
                try? await planet.publish()
            }
        }
        return try self.createResponse(from: planet, status: .ok)
    }
    
    private func routeDeletePlanet(fromRequest req: Request) async throws -> Response {
        let planet = try getPlanetByUUID(fromRequest: req)
        try planet.delete()
        defer {
            Task.detached(priority: .utility) {
                Task { @MainActor in
                    if case .myPlanet(let selectedPlanet) = PlanetStore.shared.selectedView,
                       planet == selectedPlanet
                    {
                        PlanetStore.shared.selectedView = nil
                    }
                    PlanetStore.shared.myPlanets.removeAll { $0.id == planet.id }
                }
            }
        }
        return try self.createResponse(from: planet, status: .ok)
    }
    
    private func routePublishPlanet(fromRequest req: Request) async throws -> Response {
        let planet = try getPlanetByUUID(fromRequest: req)
        defer {
            Task.detached(priority: .utility) {
                try? await planet.publish()
            }
        }
        return try self.createResponse(from: planet, status: .accepted)
    }
    
    private func routeGetPlanetArticles(fromRequest req: Request) async throws -> Response {
        let planet = try getPlanetByUUID(fromRequest: req)
        guard let articles = planet.articles, articles.count > 0 else {
            throw Abort(.notFound)
        }
        return try self.createResponse(from: articles, status: .ok)
    }
    
    private func routeCreatePlanetArticle(fromRequest req: Request) async throws -> Response {
        let planet = try getPlanetByUUID(fromRequest: req)
        let article: APIPlanetArticle = try req.content.decode(APIPlanetArticle.self)
        let articleTitle = article.title ?? ""
        let articleContent = article.content ?? ""
        let articleDateString = article.date ?? ""
        if articleTitle == "" && articleContent == "" {
            throw Abort(.badRequest, reason: "Planet article title and content are empty.")
        }
        let draft = try DraftModel.create(for: planet)
        draft.title = articleTitle
        if articleDateString == "" {
            draft.date = Date()
        } else {
            draft.date = PlanetAPI.dateFormatter().date(from: articleDateString) ?? Date()
        }
        draft.content = articleContent
        for attachment in article.attachments ?? [] {
            guard let attachmentData = attachment.data else { continue }
            guard let attachmentFileName = attachment.filename else { continue }
            guard let attachmentContentType = attachment.contentType else { continue }
            try draft.addAttachmentFromData(data: attachmentData, fileName: attachmentFileName, forContentType: attachmentContentType)
        }
        try await MainActor.run {
            try draft.saveToArticle()
        }
        return try self.createResponse(from: draft, status: .created)
    }
}
