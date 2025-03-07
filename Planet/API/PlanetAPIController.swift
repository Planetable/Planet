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

    @Published private(set) var isOperating: Bool = false
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
        Task.detached(priority: .utility) {
            await MainActor.run {
                self.isOperating = true
            }
        }
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
        Task.detached(priority: .utility) {
            try? await Task.sleep(nanoseconds: 200_000_000)
            await MainActor.run {
                self.isOperating = false
            }
        }
    }

    func stopServer() {
        Task.detached(priority: .utility) {
            await MainActor.run {
                self.isOperating = true
            }
        }
        globalApp?.shutdown()
        globalApp = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.serverIsRunning = false
        }
        stopBonjourService()
        Task.detached(priority: .utility) {
            try? await Task.sleep(nanoseconds: 200_000_000)
            await MainActor.run {
                self.isOperating = false
            }
        }
    }

    func pauseServerForSleep() {
        globalApp?.shutdown()
        globalApp = nil
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

        //MARK: - Planet Public API -
        //MARK: GET /v0/id
        //MARK: Get IPFS ID -
        /// Return IPFS ID, String
        builder.get("v0", "id") { req async throws -> String in
            return try await self.routeGetID(fromRequest: req)
        }

        //MARK: GET /v0/ping
        //MARK: Simple ping/pong test for authenticated user -
        builder.get("v0", "ping") { req async throws -> String in
            return try await self.routePing(fromRequest: req)
        }

        //MARK: GET /v0/info
        //MARK: Get ServerInfo -
        /// Return ServerInfo, Struct
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

        //MARK: GET /v0/planets/my
        //MARK: List all my Planets -
        /// Return Array<MyPlanetModel>
        builder.get("v0", "planets", "my") { req async throws -> Response in
            return try await self.routeGetPlanets(fromRequest: req)
        }

        //MARK: POST /v0/planets/my
        //MARK: Create a new Planet -
        /// Return MyPlanetModel, Struct
        builder.on(.POST, "v0", "planets", "my", body: .collect(maxSize: "5mb")) { req async throws -> Response in
            return try await self.routeCreatePlanet(fromRequest: req)
        }

        //MARK: GET /v0/planets/my/:uuid
        //MARK: Info of a specific My Planet -
        /// Return MyPlanetModel, Struct
        builder.get("v0", "planets", "my", ":uuid") { req async throws -> Response in
            return try await self.routeGetPlanetInfo(fromRequest: req)
        }

        //MARK: POST /v0/planets/my/:uuid
        //MARK: Modify my Planet -
        /// Return MyPlanetModel, Struct
        builder.on(.POST, "v0", "planets", "my", ":uuid", body: .collect(maxSize: "5mb")) { req async throws -> Response in
            return try await self.routeModifyPlanetInfo(fromRequest: req)
        }
        //MARK: DELETE /v0/planets/my/:uuid
        //MARK: Delete my Planet -
        /// Return MyPlanetModel, Struct
        builder.delete("v0", "planets", "my", ":uuid") { req async throws -> Response in
            return try await self.routeDeletePlanet(fromRequest: req)
        }

        //MARK: POST /v0/planets/my/:uuid/publish
        //MARK: Publish My Planet -
        /// Return MyPlanetModel, Struct
        builder.post("v0", "planets", "my", ":uuid", "publish") { req async throws -> Response in
            return try await self.routePublishPlanet(fromRequest: req)
        }

        //MARK: GET /v0/planets/my/:uuid/public
        //MARK: Expose the content built -
        /// Return index.html
        app.get("v0", "planets", "my", ":uuid", "public") { req async throws -> Response in
            let planet = try await self.getPlanetByUUID(fromRequest: req)
            let redirectURL = URI(string: "/\(planet.id.uuidString)/")
            return req.redirect(to: redirectURL.string, redirectType: .temporary)
        }

        //MARK: GET /v0/planets/my/:uuid/articles
        //MARK: List articles under My Planet -
        /// Return Array<MyArticleModel>
        builder.get("v0", "planets", "my", ":uuid", "articles") { req async throws -> Response in
            return try await self.routeGetPlanetArticles(fromRequest: req)
        }

        //MARK: POST /v0/planets/my/:uuid/articles
        //MARK: Create a new Article -
        /// Return MyArticleModel, Struct
        builder.on(.POST, "v0", "planets", "my", ":uuid", "articles", body: .collect(maxSize: "50mb")) { req async throws -> Response in
            return try await self.routeCreatePlanetArticle(fromRequest: req)
        }

        //MARK: GET /v0/planets/my/:planet_uuid/articles/:article_uuid
        //MARK: Get an article by planet and article UUID -
        /// Return MyArticleModel, Struct
        builder.get("v0", "planets", "my", "**") { req async throws -> Response in
            return try await self.routeGetPlanetArticle(fromRequest: req)
        }

        //MARK: POST /v0/planets/my/:planet_uuid/articles/:article_uuid
        //MARK: Modify an article by planet and article UUID -
        /// Return MyArticleModel, Struct
        builder.on(.POST, "v0", "planets", "my", "**", body: .collect(maxSize: "50mb")) { req async throws -> Response in
            return try await self.routeModifyPlanetArticle(fromRequest: req)
        }

        //MARK: DELETE /v0/planets/my/:planet_uuid/articles/:article_uuid
        //MARK: Delete an article by planet and article UUID -
        /// Return MyArticleModel, Struct
        builder.delete("v0", "planets", "my", "**") { req async throws -> Response in
            return try await self.routeDeletePlanetArticle(fromRequest: req)
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
        app.http.server.configuration.hostname = "0.0.0.0"

        let repoPath: String = {
            if #available(macOS 13.0, *) {
                return URLUtils.repoPath().appendingPathComponent("Public", conformingTo: .folder).path()
            } else {
                return URLUtils.repoPath().appendingPathComponent("Public", conformingTo: .folder).path
            }
        }()
        let fileMiddleware = FileMiddleware(publicDirectory: repoPath, defaultFile: "index.html")
        app.middleware.use(fileMiddleware)

        let logMiddleware = PlanetAPILogMiddleware()
        app.middleware.use(logMiddleware)

        app.routes.caseInsensitive = true

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

    private func getPlanetByUUID(fromRequest req: Request) async throws -> MyPlanetModel {
        guard let uuidString = req.parameters.get("uuid"),
              let uuid = UUID(uuidString: uuidString) else {
            throw Abort(.badRequest, reason: "Invalid UUID format.")
        }
        return try await MainActor.run {
            let myPlanets = PlanetStore.shared.myPlanets
            guard let planet = myPlanets.first(where: { $0.id == uuid }) else {
                throw Abort(.notFound, reason: "Planet not found.")
            }
            return planet
        }
    }

    private func getPlanetAndArticleByUUID(fromRequest req: Request) async throws -> (planet: MyPlanetModel, article: MyArticleModel) {
        let parameters = req.parameters.getCatchall()
        guard parameters.count == 3 && parameters.contains("articles") else {
            throw Abort(.badRequest, reason: "Invalid request parameters.")
        }
        guard
            let planetUUIDString = parameters.first,
            let planetUUID = UUID(uuidString: planetUUIDString) else {
            throw Abort(.badRequest, reason: "Invalid planet UUID format.")
        }
        return try await MainActor.run {
            guard let planet = PlanetStore.shared.myPlanets.first(where: { $0.id == planetUUID }) else {
                throw Abort(.notFound, reason: "Planet not found.")
            }
            guard
                let articleUUIDString = parameters.last,
                let articleUUID = UUID(uuidString: articleUUIDString) else {
                throw Abort(.badRequest, reason: "Invalid article UUID format.")
            }
            guard let article = planet.articles.first(where: { $0.id == articleUUID }) else {
                throw Abort(.badRequest, reason: "Article not found.")
            }
            return (planet, article)
        }
    }

    private func getDateFromString(_ dateString: String) -> Date {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            return date
        }
        return Date()
    }

    private func saveAttachment(_ file: File, forPlanet planetID: UUID) throws -> URL {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
        let planetURL = tmp.appendingPathComponent(planetID.uuidString)
        try? FileManager.default.createDirectory(at: planetURL, withIntermediateDirectories: true)
        let targetURL = planetURL.appendingPathComponent(file.filename)
        try? FileManager.default.removeItem(at: targetURL)
        do {
            try Data(buffer: file.data).write(to: targetURL)
        } catch {
            throw Abort(.internalServerError)
        }
        return targetURL
    }

    private func saveAttachment(_ data: Data, filename: String, forPlanet planetID: UUID) throws -> URL {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
        let planetURL = tmp.appendingPathComponent(planetID.uuidString)
        try FileManager.default.createDirectory(at: planetURL, withIntermediateDirectories: true, attributes: nil)
        let targetURL = planetURL.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: targetURL.path) {
            try FileManager.default.removeItem(at: targetURL)
        }
        try data.write(to: targetURL)
        return targetURL
    }

    private func createResponse<T: Encodable>(from value: T, status: HTTPResponseStatus) throws -> Response {
        let encoder = JSONEncoder()
        let responsePayload = try encoder.encode(value)
        let response = Response(status: status, body: .init(data: responsePayload))
        response.headers.contentType = .json
        return response
    }

    private func createRequest(from vaporRequest: Vapor.Request) -> HttpRequest {
        let httpRequest = HttpRequest()

        // Set the path
        httpRequest.path = vaporRequest.url.path

        // Set the query parameters
        httpRequest.queryParams = vaporRequest.url.query?.split(separator: "&").compactMap { param in
            let components = param.split(separator: "=")
            guard components.count == 2 else { return nil }
            return (String(components[0]), String(components[1]))
        } ?? []

        // Set the method
        httpRequest.method = vaporRequest.method.rawValue

        // Set the headers
        for (name, values) in vaporRequest.headers {
            httpRequest.headers[name.lowercased()] = values
        }

        // Set the body (as [UInt8])
        if let bodyBuffer = vaporRequest.body.data {
            httpRequest.body = [UInt8](bodyBuffer.readableBytesView)
        }

        // Set the address (remote peer address)
        httpRequest.address = vaporRequest.remoteAddress?.description

        return httpRequest
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
        return try await MainActor.run {
            let planets = PlanetStore.shared.myPlanets
            return try self.createResponse(from: planets, status: .ok)
        }
    }

    private func routeCreatePlanet(fromRequest req: Request) async throws -> Response {
        let p: APIPlanet = try req.content.decode(APIPlanet.self)
        let planetName: String = {
            if let name = p.name, name != "" {
                return name
            } else {
                return ""
            }
        }()
        if planetName == "" {
            throw Abort(.badRequest, reason: "Planet name is empty.")
        }
        let planetAbout: String = {
            if let about = p.about {
                return about
            }
            return ""
        }()
        let planetTemplateName: String = {
            let template: String = p.template ?? ""
            if TemplateStore.shared.hasTemplate(named: template) {
                return template
            }
            return TemplateStore.shared.templates.first!.name
        }()
        let planet = try await MyPlanetModel.create(
            name: planetName,
            about: planetAbout,
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
        let planet = try await getPlanetByUUID(fromRequest: req)
        return try self.createResponse(from: planet, status: .created)
    }

    private func routeModifyPlanetInfo(fromRequest req: Request) async throws -> Response {
        let planet = try await getPlanetByUUID(fromRequest: req)
        let p: APIPlanet = try req.content.decode(APIPlanet.self)
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
            if planetTemplateName != "", TemplateStore.shared.hasTemplate(named: planetTemplateName) {
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
        let planet = try await getPlanetByUUID(fromRequest: req)
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
        let planet = try await getPlanetByUUID(fromRequest: req)
        defer {
            Task.detached(priority: .utility) {
                try? await planet.publish()
            }
        }
        return try self.createResponse(from: planet, status: .accepted)
    }

    private func routeGetPlanetArticles(fromRequest req: Request) async throws -> Response {
        let planet = try await getPlanetByUUID(fromRequest: req)
        guard let articles = planet.articles, articles.count > 0 else {
            throw Abort(.notFound)
        }
        return try self.createResponse(from: articles, status: .ok)
    }

    private func routeCreatePlanetArticle(fromRequest req: Request) async throws -> Response {
        let planet = try await getPlanetByUUID(fromRequest: req)
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
            draft.date = getDateFromString(articleDateString)
        }
        draft.content = articleContent
        if let attachments = article.attachments {
            for attachment in attachments {
                let savedURL = try self.saveAttachment(attachment, forPlanet: planet.id)
                let attachmentType = AttachmentType.from(savedURL)
                try draft.addAttachment(path: savedURL, type: attachmentType)
                Task.detached(priority: .background) {
                    try? FileManager.default.removeItem(at: savedURL)
                }
            }
        } else {
            let r: HttpRequest = self.createRequest(from: req)
            let multipartDatas = r.parseMultiPartFormData()
            for multipartData in multipartDatas {
                guard let propertyName = multipartData.name else { continue }
                switch propertyName {
                    case "attachment":
                        let fileData = Data(bytes: multipartData.body, count: multipartData.body.count)
                        if let fileName = multipartData.fileName, fileData.count > 0 {
                            let savedURL =  try self.saveAttachment(fileData, filename: fileName, forPlanet: planet.id)
                            let attachmentType = AttachmentType.from(savedURL)
                            try draft.addAttachment(path: savedURL, type: attachmentType)
                            Task.detached(priority: .background) {
                                try? FileManager.default.removeItem(at: savedURL)
                            }
                        }
                    default:
                        break
                }
            }
        }
        // TODO: What if the saveToArticle operation is a Task.detached?
        try await MainActor.run {
            try draft.saveToArticle()
        }
        if let a = planet.articles.first {
            return try self.createResponse(from: a, status: .created)
        }
        return try self.createResponse(from: draft, status: .created)
    }

    private func routeGetPlanetArticle(fromRequest req: Request) async throws -> Response {
        let result = try await getPlanetAndArticleByUUID(fromRequest: req)
        let article = result.article
        return try self.createResponse(from: article, status: .ok)
    }

    private func routeModifyPlanetArticle(fromRequest req: Request) async throws -> Response {
        let result = try await getPlanetAndArticleByUUID(fromRequest: req)
        let planet = result.planet
        let article = result.article
        let draft = try DraftModel.create(from: article)
        let updateArticle: APIPlanetArticle = try req.content.decode(APIPlanetArticle.self)
        if let articleTitle = updateArticle.title, articleTitle != "" {
            draft.title = articleTitle
        }
        if let articleDateString = updateArticle.date, articleDateString != "" {
            draft.date = getDateFromString(articleDateString)
        } else {
            draft.date = article.created
        }
        if let articleContent = updateArticle.content, articleContent != "" {
            draft.content = articleContent
        }
        if let attachments = updateArticle.attachments {
            for existingAttachment in draft.attachments {
                draft.deleteAttachment(name: existingAttachment.name)
            }
            for attachment in attachments {
                let savedURL = try self.saveAttachment(attachment, forPlanet: planet.id)
                let attachmentType = AttachmentType.from(savedURL)
                try draft.addAttachment(path: savedURL, type: attachmentType)
                Task.detached(priority: .background) {
                    try? FileManager.default.removeItem(at: savedURL)
                }
            }
        } else {
            let r: HttpRequest = self.createRequest(from: req)
            let multipartDatas = r.parseMultiPartFormData()
            if multipartDatas.count > 0 {
                for multipartData in multipartDatas {
                    if let propertyName = multipartData.name, propertyName == "attachment" {
                        for existingAttachment in draft.attachments {
                            draft.deleteAttachment(name: existingAttachment.name)
                        }
                        break
                    }
                }
                for multipartData in multipartDatas {
                    guard let propertyName = multipartData.name else { continue }
                    switch propertyName {
                        case "attachment":
                            let fileData = Data(bytes: multipartData.body, count: multipartData.body.count)
                            if let fileName = multipartData.fileName, fileData.count > 0 {
                                let savedURL = try self.saveAttachment(fileData, filename: fileName, forPlanet: planet.id)
                                let attachmentType = AttachmentType.from(savedURL)
                                try draft.addAttachment(path: savedURL, type: attachmentType)
                                Task.detached(priority: .background) {
                                    try? FileManager.default.removeItem(at: savedURL)
                                }
                            }
                        default:
                            break
                    }
                }
            }
        }
        try await MainActor.run {
            try draft.saveToArticle()
        }
        return try self.createResponse(from: article, status: .accepted)
    }

    private func routeDeletePlanetArticle(fromRequest req: Request) async throws -> Response {
        let result = try await getPlanetAndArticleByUUID(fromRequest: req)
        let planet = result.planet
        let article = result.article
        await MainActor.run {
            article.delete()
            planet.updated = Date()
        }
        try await MainActor.run {
            try planet.save()
        }
        Task.detached {
            try await planet.savePublic()
        }
        defer {
            Task.detached(priority: .utility) {
                await MainActor.run {
                    if PlanetStore.shared.selectedArticle == article {
                        PlanetStore.shared.selectedArticle = nil
                    }
                    if let selectedArticles = PlanetStore.shared.selectedArticleList,
                       selectedArticles.contains(article) {
                        PlanetStore.shared.refreshSelectedArticles()
                    }
                }
            }
        }
        return try self.createResponse(from: article, status: .accepted)
    }
}
