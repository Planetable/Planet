//
//  PlanetAPI.swift
//  Planet
//
//  Created by Kai on 1/12/23.
//

import Foundation
import Swifter


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
        super.init()
        self.updateServerSettings()
    }
    
    // MARK: -
    
    func launch() throws {
        guard UserDefaults.standard.bool(forKey: .settingsAPIEnabled) else { return }
        server["/v0/planets/my"] = { [weak self] r in
            switch r.method {
            case "GET":
                return self?.getPlanets(forRequest: r) ?? .error
            case "POST":
                return self?.createPlanet(forRequest: r) ?? .error
            default:
                return .error
            }
        }
        server["/v0/planets/my/:a"] = { [weak self] r in
            switch r.method {
            case "GET":
                return self?.getPlanetInfo(forRequest: r) ?? .error
            case "POST":
                return self?.modifyPlanetInfo(forRequest: r) ?? .error
            default:
                return .error
            }
        }
        server["/v0/planets/my/:a/publish"] = { [weak self] r in
            switch r.method {
            case "POST":
                return self?.publishPlanet(forRequest: r) ?? .error
            default:
                return .error
            }
        }
        server["/v0/planets/my/:a/public"] = { [weak self] r in
            switch r.method {
            case "GET":
                return self?.getPlanetPublicContent(forRequest: r) ?? .error
            default:
                return .error
            }
        }
        server["/v0/planets/my/:a/articles"] = { [weak self] r in
            switch r.method {
            case "GET":
                return self?.getPlanetArticles(forRequest: r) ?? .error
            case "POST":
                return self?.createPlanetArticle(forRequest: r) ?? .error
            default:
                return .error
            }
        }
        server["/v0/planets/my/:a/articles/:b"] = { [weak self] r in
            switch r.method {
            case "GET":
                return self?.getPlanetArticle(forRequest: r) ?? .error
            case "POST":
                return self?.modifyPlanetArticle(forRequest: r) ?? .error
            case "DELETE":
                return self?.deletePlanetArticle(forRequest: r) ?? .error
            default:
                return .error
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
    }
}


// MARK: - API Functions -

extension PlanetAPI {
    // MARK: GET /v0/planets/my
    private func getPlanets(forRequest r: HttpRequest) -> HttpResponse {
        guard validateRequest(r) else { return .invalid }
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(myPlanets)
            let jsonObject = try JSONSerialization.jsonObject(with: data)
            return .ok(.json(jsonObject))
        } catch {
            return .error
        }
    }
    
    // MARK: POST /v0/planets/my
    private func createPlanet(forRequest r: HttpRequest) -> HttpResponse {
        guard validateRequest(r) else { return .invalid }
        let params = r.parseUrlencodedForm()
        var name: String = ""
        var about: String = ""
        var templateName: String = ""
        for param in params {
            if param.0 == "name" {
                name = param.1
            }
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
            return .invalid
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
        return .okay
    }

    // MARK: GET /v0/planets/my/:uuid
    private func getPlanetInfo(forRequest r: HttpRequest) -> HttpResponse {
        guard validateRequest(r) else { return .invalid }
        if let uuid = planetUUIDFromRequest(r), let planet = myPlanets.first(where: { $0.id == uuid }) {
            let encoder = JSONEncoder()
            do {
                let data = try encoder.encode(planet)
                let jsonObject = try JSONSerialization.jsonObject(with: data)
                return .ok(.json(jsonObject))
            } catch {
                return .error
            }
        } else {
            return .invalid
        }
    }
    
    // MARK: POST /v0/planets/my/:uuid
    private func modifyPlanetInfo(forRequest r: HttpRequest) -> HttpResponse {
        guard validateRequest(r) else { return .invalid }
        if let uuid = planetUUIDFromRequest(r) {
            debugPrint("modify planet info for uuid: \(uuid), content: \(r.parseUrlencodedForm()), body: \(r.body)")
        }
        return .okay
    }
    
    // MARK: POST /v0/planets/my/:uuid/publish
    private func publishPlanet(forRequest r: HttpRequest) -> HttpResponse {
        guard validateRequest(r) else { return .invalid }
        if let uuid = planetUUIDFromRequest(r), let planet = myPlanets.first(where: { $0.id == uuid }) {
            Task {
                do {
                    try await planet.publish()
                } catch {
                    debugPrint("failed to publish planet: \(planet), error: \(error)")
                }
            }
            return .okay
        } else {
            return .invalid
        }
    }
    
    // MARK: GET /v0/planets/my/:uuid/public
    private func getPlanetPublicContent(forRequest r: HttpRequest) -> HttpResponse {
        guard validateRequest(r) else { return .invalid }
        if let uuid = planetUUIDFromRequest(r), let planet = myPlanets.first(where: { $0.id == uuid }) {
            let planetJSONURL = planet.publicBasePath.appendingPathComponent("planet.json")
            do {
                let data = try Data(contentsOf: planetJSONURL)
                let jsonObject = try JSONSerialization.jsonObject(with: data)
                return .ok(.json(jsonObject))
            } catch {
                return .error
            }
        } else {
            return .invalid
        }
    }
    
    // MARK: GET /v0/planets/my/:uuid/articles
    private func getPlanetArticles(forRequest r: HttpRequest) -> HttpResponse {
        guard validateRequest(r) else { return .invalid }
        if let uuid = planetUUIDFromRequest(r), let planet = myPlanets.first(where: { $0.id == uuid }) {
            let encoder = JSONEncoder()
            do {
                let data = try encoder.encode(planet.articles)
                let jsonObject = try JSONSerialization.jsonObject(with: data)
                return .ok(.json(jsonObject))
            } catch {
                return .error
            }
        } else {
            return .invalid
        }
    }
    
    // MARK: POST /v0/planets/my/:uuid/articles
    private func createPlanetArticle(forRequest r: HttpRequest) -> HttpResponse {
        guard validateRequest(r) else { return .invalid }
        if let uuid = planetUUIDFromRequest(r) {
            debugPrint("create planet article for uuid: \(uuid)")
        }
        return .okay
    }
    
    // MARK: GET /v0/planets/my/:uuid/articles/:uuid
    private func getPlanetArticle(forRequest r: HttpRequest) -> HttpResponse {
        guard validateRequest(r) else { return .invalid }
        let results = planetUUIDAndArticleUUIDFromRequest(r)
        if let planetUUID = results.0, let articleUUID = results.1 {
            if let planet = myPlanets.first(where: { $0.id == planetUUID }), let article = planet.articles.first(where: { $0.id == articleUUID }) {
                let encoder = JSONEncoder()
                do {
                    let data = try encoder.encode(article)
                    let jsonObject = try JSONSerialization.jsonObject(with: data)
                    return .ok(.json(jsonObject))
                } catch {
                    return .error
                }
            } else {
                return .invalid
            }
        } else {
            return .invalid
        }
    }
    
    // MARK: POST /v0/planets/my/:uuid/articles/:uuid
    private func modifyPlanetArticle(forRequest r: HttpRequest) -> HttpResponse {
        guard validateRequest(r) else { return .invalid }
        let results = planetUUIDAndArticleUUIDFromRequest(r)
        if let planetUUID = results.0, let articleUUID = results.1 {
            debugPrint("modify planet article for uuid: \(planetUUID), article uuid: \(articleUUID)")
        }
        return .okay
    }
    
    // MARK: DELETE /v0/planets/my/:uuid/articles/:uuid
    private func deletePlanetArticle(forRequest r: HttpRequest) -> HttpResponse {
        guard validateRequest(r) else { return .invalid }
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
                return .okay
            } else {
                return .invalid
            }
        } else {
            return .invalid
        }
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
        // MARK: TODO: validate with passcode if needed, from keychain.
        return true
    }

    private func updateServerSettings() {
        if !UserDefaults.standard.bool(forKey: .settingsAPIEnabled) {
            shutdown()
            return
        }
    }
}


// MARK: - API Extensions -

extension HttpResponse {
    // MARK: TODO: more details: json data output, status code.
    static let error = HttpResponse.ok(.text("Error"))
    static let okay = HttpResponse.ok(.text("Okay"))
    static let invalid = HttpResponse.ok(.text("Invalid"))
}
