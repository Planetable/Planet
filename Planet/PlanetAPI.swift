//
//  PlanetAPI.swift
//  Planet
//
//  Created by Kai on 1/12/23.
//

import Foundation
import Swifter
import KeychainSwift


class PlanetAPI: NSObject {
    static let shared = PlanetAPI()
    
    private(set) var myPlanets: [MyPlanetModel] = []
    private(set) var myArticles: [MyArticleModel] = []
    
    private var server: HttpServer
    
    override init() {
        server = HttpServer()
        let defaults = UserDefaults.standard
        if defaults.value(forKey: .settingsAPIPort) == nil {
            defaults.set("9191", forKey: .settingsAPIPort)
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
        super.init()
        self.updateServerSettings()
    }
    
    // MARK: -
    
    func launch() throws {
        guard UserDefaults.standard.bool(forKey: .settingsAPIEnabled) else { return }
        server["/v0/planets/my"] = { [weak self] r in
            switch r.method {
            case "GET":
                return self?.getPlanets(forRequest: r) ?? .error()
            case "POST":
                return self?.createPlanet(forRequest: r) ?? .error()
            default:
                return .error()
            }
        }
        server["/v0/planets/my/:a"] = { [weak self] r in
            switch r.method {
            case "GET":
                return self?.getPlanetInfo(forRequest: r) ?? .error()
            case "POST":
                return self?.modifyPlanetInfo(forRequest: r) ?? .error()
            default:
                return .error()
            }
        }
        server["/v0/planets/my/:a/publish"] = { [weak self] r in
            switch r.method {
            case "POST":
                return self?.publishPlanet(forRequest: r) ?? .error()
            default:
                return .error()
            }
        }
        server["/v0/planets/my/:a/articles"] = { [weak self] r in
            switch r.method {
            case "GET":
                return self?.getPlanetArticles(forRequest: r) ?? .error()
            case "POST":
                return self?.createPlanetArticle(forRequest: r) ?? .error()
            default:
                return .error()
            }
        }
        server["/v0/planets/my/:a/articles/:b"] = { [weak self] r in
            switch r.method {
            case "GET":
                return self?.getPlanetArticle(forRequest: r) ?? .error()
            case "POST":
                return self?.modifyPlanetArticle(forRequest: r) ?? .error()
            case "DELETE":
                return self?.deletePlanetArticle(forRequest: r) ?? .error()
            default:
                return .error()
            }
        }
        if let portString = UserDefaults.standard.string(forKey: .settingsAPIPort), let port = Int(portString) {
            try server.start(in_port_t(port), forceIPv4: false, priority: .utility)
            debugPrint("Planet api server started at port: \(portString)")
        } else {
            throw PlanetError.PublicAPIError
        }
    }
    
    func relaunch() throws {
        shutdown()
        updateServerSettings()
        try launch()
    }

    func shutdown() {
        server.stop()
    }
    
    func updateMyPlanets(_ planets: [MyPlanetModel]) {
        myPlanets = planets
        var articles: [MyArticleModel] = []
        for planet in planets {
            articles.append(contentsOf: planet.articles)
        }
        myArticles = articles
        try? relaunch()
    }
}


// MARK: - API Functions -

extension PlanetAPI {
    // MARK: GET /v0/planets/my
    private func getPlanets(forRequest r: HttpRequest) -> HttpResponse {
        guard validateRequest(r) else { return .unauthorized(nil) }
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(myPlanets)
            let jsonObject = try JSONSerialization.jsonObject(with: data)
            return .ok(.json(jsonObject))
        } catch {
            return .error(error.localizedDescription)
        }
    }
    
    // MARK: POST /v0/planets/my
    private func createPlanet(forRequest r: HttpRequest) -> HttpResponse {
        guard validateRequest(r) else { return .unauthorized(nil) }
        let params = r.parseUrlencodedForm()
        var name: String = ""
        var about: String = ""
        var templateName: String = ""
        for param in params {
            switch param.0 {
            case "name":
                name = param.1
            case "about":
                about = param.1
            case "template":
                templateName = param.1
            default:
                break
            }
        }
        if name == "" {
            return .error("'name' is empty.")
        }
        if !TemplateStore.shared.templates.contains(where: { t in
            return t.name.lowercased() == templateName.lowercased()
        }) {
            templateName = TemplateStore.shared.templates.first!.name
        }
        let planetName = name
        let planetAbout = about
        let planetTemplateName = templateName
        Task { @MainActor in
            do {
                let planet = try await MyPlanetModel.create(
                    name: planetName,
                    about: planetAbout,
                    templateName: planetTemplateName
                )
                PlanetStore.shared.myPlanets.insert(planet, at: 0)
                PlanetStore.shared.selectedView = .myPlanet(planet)
                try planet.save()
                try planet.savePublic()
            } catch {
                PlanetStore.shared.alert(title: "Failed to create planet")
            }
        }
        return .success()
    }

    // MARK: GET /v0/planets/my/:uuid
    private func getPlanetInfo(forRequest r: HttpRequest) -> HttpResponse {
        guard validateRequest(r) else { return HttpResponse.unauthorized(nil) }
        if let uuid = planetUUIDFromRequest(r), let planet = myPlanets.first(where: { $0.id == uuid }) {
            let encoder = JSONEncoder()
            do {
                let data = try encoder.encode(planet)
                let jsonObject = try JSONSerialization.jsonObject(with: data)
                return .ok(.json(jsonObject))
            } catch {
                return .error(error.localizedDescription)
            }
        } else {
            return .notFound()
        }
    }
    
    // MARK: POST /v0/planets/my/:uuid
    private func modifyPlanetInfo(forRequest r: HttpRequest) -> HttpResponse {
        guard validateRequest(r) else { return HttpResponse.unauthorized(nil) }
        if let uuid = planetUUIDFromRequest(r), let planet = myPlanets.first(where: { $0.id == uuid }) {
            // MARK: TODO: support more planet properties.
            let params = r.parseUrlencodedForm()
            var name: String = ""
            var about: String = ""
            var templateName: String = ""
            for param in params {
                switch param.0 {
                case "name":
                    name = param.1
                case "about":
                    about = param.1
                case "template":
                    templateName = param.1
                default:
                    break
                }
            }
            let planetName = name
            let planetAbout = about
            let planetTemplateName = templateName
            Task { @MainActor in
                if planetName != "" {
                    planet.name = planetName
                }
                if planetAbout != "" {
                    planet.about = planetAbout
                }
                if planetTemplateName != "" {
                    planet.templateName = planetTemplateName
                }
                do {
                    try planet.save()
                    try planet.copyTemplateAssets()
                    try planet.articles.forEach { try $0.savePublic() }
                    try planet.savePublic()
                    NotificationCenter.default.post(name: .loadArticle, object: nil)
                    try await planet.publish()
                } catch {
                    debugPrint("failed to modify planet info: \(planet), error: \(error)")
                }
            }
            return .success()
        } else {
            return .notFound()
        }
    }
    
    // MARK: POST /v0/planets/my/:uuid/publish
    private func publishPlanet(forRequest r: HttpRequest) -> HttpResponse {
        guard validateRequest(r) else { return .unauthorized(nil) }
        if let uuid = planetUUIDFromRequest(r), let planet = myPlanets.first(where: { $0.id == uuid }) {
            Task {
                do {
                    try await planet.publish()
                } catch {
                    debugPrint("failed to publish planet: \(planet), error: \(error)")
                }
            }
            return .success()
        } else {
            return .notFound()
        }
    }
    
    // MARK: GET /v0/planets/my/:uuid/public
    private func exposePlanetPublicContent(inDirectory dir: String, forRequest r: HttpRequest) -> HttpResponse {
        guard validateRequest(r) else { return .unauthorized(nil) }
        let filePath = dir
        do {
            guard try filePath.exists() else {
                return .notFound()
            }
            if try filePath.directory() {
                var files = try filePath.files()
                files.sort(by: {$0.lowercased() < $1.lowercased()})
                return scopes {
                    html {
                        body {
                            table(files) { file in
                                tr {
                                    td {
                                        a {
                                            href = r.path + "/" + file
                                            inner = file
                                        }
                                    }
                                }
                            }
                        }
                    }
                    }(r)
            } else {
                let mimeType = filePath.mimeType()
                var responseHeader: [String: String] = ["Content-Type": mimeType]
                if let attr = try? FileManager.default.attributesOfItem(atPath: filePath), let fileSize = attr[FileAttributeKey.size] as? UInt64 {
                    responseHeader["Content-Length"] = try? String(fileSize)
                }
                let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
                return .raw(200, "OK", responseHeader, { writer in
                    try? writer.write(data)
                })
            }
        } catch {
            return HttpResponse.internalServerError(.text("Internal Server Error"))
        }
    }
    
    // MARK: GET /v0/planets/my/:uuid/articles
    private func getPlanetArticles(forRequest r: HttpRequest) -> HttpResponse {
        guard validateRequest(r) else { return .unauthorized(nil) }
        if let uuid = planetUUIDFromRequest(r), let planet = myPlanets.first(where: { $0.id == uuid }) {
            let encoder = JSONEncoder()
            do {
                let data = try encoder.encode(planet.articles)
                let jsonObject = try JSONSerialization.jsonObject(with: data)
                return .ok(.json(jsonObject))
            } catch {
                return .error(error.localizedDescription)
            }
        } else {
            return .notFound()
        }
    }
    
    // MARK: POST /v0/planets/my/:uuid/articles
    private func createPlanetArticle(forRequest r: HttpRequest) -> HttpResponse {
        guard validateRequest(r) else { return .unauthorized(nil) }
        if let uuid = planetUUIDFromRequest(r), let planet = myPlanets.first(where: { $0.id == uuid }) {
            // MARK: TODO: support attachments.
            let params = r.parseUrlencodedForm()
            var title: String = ""
            var date: String = ""
            var content: String = ""
            for param in params {
                switch param.0 {
                case "title":
                    title = param.1
                case "date":
                    date = param.1
                case "content":
                    content = param.1
                default:
                    break
                }
            }
            let articleTitle = title
            let articleDateString = date
            let articleContent = content
            Task { @MainActor in
                do {
                    let draft = try DraftModel.create(for: planet)
                    draft.title = articleTitle
                    if articleDateString == "" {
                        draft.date = Date()
                    } else {
                        draft.date = DateFormatter().date(from: articleDateString) ?? Date()
                    }
                    draft.content = articleContent
                    try draft.saveToArticle()
                } catch {
                    debugPrint("failed to create article for planet: \(planet), error: \(error)")
                }
            }
            return .success()
        } else {
            return .notFound()
        }
    }
    
    // MARK: GET /v0/planets/my/:uuid/articles/:uuid
    private func getPlanetArticle(forRequest r: HttpRequest) -> HttpResponse {
        guard validateRequest(r) else { return .unauthorized(nil) }
        let results = planetUUIDAndArticleUUIDFromRequest(r)
        if let planetUUID = results.0, let articleUUID = results.1 {
            if let planet = myPlanets.first(where: { $0.id == planetUUID }), let article = planet.articles.first(where: { $0.id == articleUUID }) {
                let encoder = JSONEncoder()
                do {
                    let data = try encoder.encode(article)
                    let jsonObject = try JSONSerialization.jsonObject(with: data)
                    return .ok(.json(jsonObject))
                } catch {
                    return .error(error.localizedDescription)
                }
            }
        }
        return .notFound()
    }
    
    // MARK: POST /v0/planets/my/:uuid/articles/:uuid
    private func modifyPlanetArticle(forRequest r: HttpRequest) -> HttpResponse {
        guard validateRequest(r) else { return .unauthorized(nil) }
        let results = planetUUIDAndArticleUUIDFromRequest(r)
        if let planetUUID = results.0, let articleUUID = results.1 {
            if let planet = myPlanets.first(where: { $0.id == planetUUID }), let article = planet.articles.first(where: { $0.id == articleUUID }) {
                // MARK: TODO: support attachments.
                let params = r.parseUrlencodedForm()
                var title: String = ""
                var date: String = ""
                var content: String = ""
                for param in params {
                    switch param.0 {
                    case "title":
                        title = param.1
                    case "date":
                        date = param.1
                    case "content":
                        content = param.1
                    default:
                        break
                    }
                }
                let articleTitle = title
                let articleDateString = date
                let articleContent = content
                Task { @MainActor in
                    do {
                        let draft = try DraftModel.create(from: article)
                        draft.title = articleTitle
                        if articleDateString == "" {
                            draft.date = Date()
                        } else {
                            draft.date = DateFormatter().date(from: articleDateString) ?? Date()
                        }
                        draft.content = articleContent
                        try draft.saveToArticle()
                    } catch {
                        debugPrint("failed to modify article for planet: \(planet), error: \(error)")
                    }
                }
                return .success()
            }
        }
        return .notFound()
    }
    
    // MARK: DELETE /v0/planets/my/:uuid/articles/:uuid
    private func deletePlanetArticle(forRequest r: HttpRequest) -> HttpResponse {
        guard validateRequest(r) else { return .unauthorized(nil) }
        let results = planetUUIDAndArticleUUIDFromRequest(r)
        if let planetUUID = results.0, let articleUUID = results.1 {
            if let planet = myPlanets.first(where: { $0.id == planetUUID }), let article = planet.articles.first(where: { $0.id == articleUUID }) {
                Task(priority: .background) {
                    await MainActor.run {
                        article.delete()
                        planet.updated = Date()
                        do {
                            try planet.save()
                            try planet.savePublic()
                            if PlanetStore.shared.selectedArticle == article {
                                PlanetStore.shared.selectedArticle = nil
                            }
                            if let selectedArticles = PlanetStore.shared.selectedArticleList,
                               selectedArticles.contains(article) {
                                PlanetStore.shared.refreshSelectedArticles()
                            }
                        } catch {
                            debugPrint("failed to delete planet article: \(articleUUID), error: \(error)")
                        }
                    }
                }
                return .success()
            }
        }
        return .notFound()
    }
}


// MARK: - API Functions -

extension PlanetAPI {
    private func planetUUIDFromRequest(_ r: HttpRequest) -> UUID? {
        guard let uuidString = r.params[":a"], let uuid = UUID(uuidString: uuidString) else { return nil }
        return uuid
    }
    
    private func planetUUIDAndArticleUUIDFromRequest(_ r: HttpRequest) -> (UUID?, UUID?) {
        guard let planetUUIDString = r.params[":a"], let planetUUID = UUID(uuidString: planetUUIDString), let articleUUIDString = r.params[":b"], let articleUUID = UUID(uuidString: articleUUIDString) else { return (nil, nil) }
        return (planetUUID, articleUUID)
    }
    
    private func validateRequest(_ r: HttpRequest) -> Bool {
        let apiUsesPasscode = UserDefaults.standard.bool(forKey: .settingsAPIUsesPasscode)
        let username = UserDefaults.standard.string(forKey: .settingsAPIUsername) ?? "Planet"
        let keychain = KeychainSwift()
        if apiUsesPasscode, let passcode = keychain.get(.settingsAPIPasscode), passcode != "" {
            if let auth = r.headers["authorization"], let encoded = auth.components(separatedBy: "Basic ").last, encoded != "", let usernameAndPasscode = encoded.base64Decoded(), usernameAndPasscode == "\(username):\(passcode)" {
                return true
            } else {
                return false
            }
        }
        return true
    }

    private func updateServerSettings() {
        if !UserDefaults.standard.bool(forKey: .settingsAPIEnabled) {
            shutdown()
            return
        }
        let planets = myPlanets
        let repoPath = URLUtils.repoPath.appendingPathComponent("Public", conformingTo: .folder)
        for planet in planets {
            let planetPublicURL = repoPath.appendingPathComponent(planet.id.uuidString)
            let planetRootPath = "/v0/planets/my/\(planet.id.uuidString)/public"
            server[planetRootPath] = { [weak self] r in
                if r.method == "GET" {
                    return self?.exposePlanetPublicContent(inDirectory: planetPublicURL.path, forRequest: r) ?? .error()
                } else {
                    return .error()
                }
            }
            if let subpaths = FileManager.default.subpaths(atPath: planetPublicURL.path) {
                for subpath in subpaths {
                    let urlPath = planetRootPath + "/" + subpath
                    let targetPath = planetPublicURL.appendingPathComponent(subpath).path
                    server[urlPath] = { [weak self] r in
                        if r.method == "GET" {
                            return self?.exposePlanetPublicContent(inDirectory: targetPath, forRequest: r) ?? .error()
                        } else {
                            return .error()
                        }
                    }
                }
            }
        }
    }
}


// MARK: - API Extensions -

extension HttpResponse {
    static func error(_ message: String = "") -> HttpResponse {
        let encoder = JSONEncoder()
        do {
            let info = ["status": "Error", "description": message]
            let data = try encoder.encode(info)
            let jsonObject = try JSONSerialization.jsonObject(with: data)
            return HttpResponse.badRequest(.json(jsonObject))
        } catch {
            return HttpResponse.badRequest(.text(message))
        }
    }
    static func success(_ message: String = "") -> HttpResponse {
        let encoder = JSONEncoder()
        do {
            let info = ["status": "Successful", "description": message]
            let data = try encoder.encode(info)
            let jsonObject = try JSONSerialization.jsonObject(with: data)
            return HttpResponse.ok(.json(jsonObject))
        } catch {
            return HttpResponse.ok(.text(message))
        }
    }
}


extension String {
    func base64Decoded() -> String? {
        guard let data = Data(base64Encoded: self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
