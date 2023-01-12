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
}


// MARK: - API Functions -

extension PlanetAPI {
    // MARK: GET /v0/planets/my
    private func getPlanets(forRequest r: HttpRequest) -> HttpResponse {
        return .okay
    }
    
    // MARK: POST /v0/planets/my
    private func createPlanet(forRequest r: HttpRequest) -> HttpResponse {
        return .okay
    }

    // MARK: GET /v0/planets/my/:uuid
    private func getPlanetInfo(forRequest r: HttpRequest) -> HttpResponse {
        if let uuid = planetUUIDFromRequest(r) {
            debugPrint("get planet info for uuid: \(uuid)")
        }
        return .okay
    }
    
    // MARK: POST /v0/planets/my/:uuid
    private func modifyPlanetInfo(forRequest r: HttpRequest) -> HttpResponse {
        if let uuid = planetUUIDFromRequest(r) {
            debugPrint("modify planet info for uuid: \(uuid), content: \(r.parseUrlencodedForm()), body: \(r.body)")
        }
        return .okay
    }
    
    // MARK: POST /v0/planets/my/:uuid/publish
    private func publishPlanet(forRequest r: HttpRequest) -> HttpResponse {
        if let uuid = planetUUIDFromRequest(r) {
            debugPrint("publish planet for uuid: \(uuid)")
        }
        return .okay
    }
    
    // MARK: GET /v0/planets/my/:uuid/public
    private func getPlanetPublicContent(forRequest r: HttpRequest) -> HttpResponse {
        if let uuid = planetUUIDFromRequest(r) {
            debugPrint("get planet public content for uuid: \(uuid)")
        }
        return .okay
    }
    
    // MARK: GET /v0/planets/my/:uuid/articles
    private func getPlanetArticles(forRequest r: HttpRequest) -> HttpResponse {
        if let uuid = planetUUIDFromRequest(r) {
            debugPrint("get planet articles for uuid: \(uuid)")
        }
        return .okay
    }
    
    // MARK: POST /v0/planets/my/:uuid/articles
    private func createPlanetArticle(forRequest r: HttpRequest) -> HttpResponse {
        if let uuid = planetUUIDFromRequest(r) {
            debugPrint("create planet article for uuid: \(uuid)")
        }
        return .okay
    }
    
    // MARK: GET /v0/planets/my/:uuid/articles/:uuid
    private func getPlanetArticle(forRequest r: HttpRequest) -> HttpResponse {
        let results = planetUUIDAndArticleUUIDFromRequest(r)
        if let planetUUID = results.0, let articleUUID = results.1 {
            debugPrint("get planet article for uuid: \(planetUUID), article uuid: \(articleUUID)")
        }
        return .okay
    }
    
    // MARK: POST /v0/planets/my/:uuid/articles/:uuid
    private func modifyPlanetArticle(forRequest r: HttpRequest) -> HttpResponse {
        let results = planetUUIDAndArticleUUIDFromRequest(r)
        if let planetUUID = results.0, let articleUUID = results.1 {
            debugPrint("modify planet article for uuid: \(planetUUID), article uuid: \(articleUUID)")
        }
        return .okay
    }
    
    // MARK: DELETE /v0/planets/my/:uuid/articles/:uuid
    private func deletePlanetArticle(forRequest r: HttpRequest) -> HttpResponse {
        let results = planetUUIDAndArticleUUIDFromRequest(r)
        if let planetUUID = results.0, let articleUUID = results.1 {
            debugPrint("delete planet article for uuid: \(planetUUID), article uuid: \(articleUUID)")
        }
        return .okay
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

    private func updateServerSettings() {
        if !UserDefaults.standard.bool(forKey: .settingsAPIEnabled) {
            shutdown()
            return
        }
    }
}


// MARK: - API Extensions -

extension HttpResponse {
    static let error = HttpResponse.ok(.text("Error"))
    static let okay = HttpResponse.ok(.text("Okay"))
}
