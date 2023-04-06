//
//  PlanetAPI.swift
//  Planet
//
//  Created by Kai on 1/12/23.
//

import Foundation
import Swifter
import Cocoa


actor PlanetAPIHelper {
    static let shared = PlanetAPIHelper()
    
    private var isRelaunchingServer: Bool = false
    private var server: HttpServer
    
    init() {
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
        // disable api authentication if no passcode found.
        do {
            let passcode = try KeychainHelper.shared.loadValue(forKey: .settingsAPIPasscode)
            if passcode == "" {
                defaults.set(false, forKey: .settingsAPIUsesPasscode)
            }
        } catch {
            defaults.set(false, forKey: .settingsAPIUsesPasscode)
        }
        Task {
            await self.updateSettings()
        }
    }

    func relaunch() throws {
        guard isRelaunchingServer == false else { return }
        debugPrint("Relaunching planet api server ...")
        isRelaunchingServer = true
        shutdown()
        updateSettings()
        try launch()
        isRelaunchingServer = false
    }
    
    func shutdown() {
        server.stop()
    }

    private func launch() throws {
        guard UserDefaults.standard.bool(forKey: .settingsAPIEnabled) else { return }
        server["/v0/planets/my"] = { r in
            switch r.method {
            case "GET":
                return PlanetAPI.shared.getPlanets(forRequest: r)
            case "POST":
                return PlanetAPI.shared.createPlanet(forRequest: r)
            default:
                return .error()
            }
        }
        server["/v0/planets/my/:a"] = { r in
            switch r.method {
            case "GET":
                return PlanetAPI.shared.getPlanetInfo(forRequest: r)
            case "POST":
                return PlanetAPI.shared.modifyPlanetInfo(forRequest: r)
            default:
                return .error()
            }
        }
        server["/v0/planets/my/:a/publish"] = { r in
            switch r.method {
            case "POST":
                return PlanetAPI.shared.publishPlanet(forRequest: r)
            default:
                return .error()
            }
        }
        server["/v0/planets/my/:a/articles"] = { r in
            switch r.method {
            case "GET":
                return PlanetAPI.shared.getPlanetArticles(forRequest: r)
            case "POST":
                return PlanetAPI.shared.createPlanetArticle(forRequest: r)
            default:
                return .error()
            }
        }
        server["/v0/planets/my/:a/articles/:b"] = { r in
            switch r.method {
            case "GET":
                return PlanetAPI.shared.getPlanetArticle(forRequest: r)
            case "POST":
                return PlanetAPI.shared.modifyPlanetArticle(forRequest: r)
            case "DELETE":
                return PlanetAPI.shared.deletePlanetArticle(forRequest: r)
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
    
    private func updateSettings() {
        if !UserDefaults.standard.bool(forKey: .settingsAPIEnabled) {
            shutdown()
            return
        }
        let planets = PlanetAPI.shared.myPlanets
        let repoPath = URLUtils.repoPath().appendingPathComponent("Public", conformingTo: .folder)
        for planet in planets {
            let planetPublicURL = repoPath.appendingPathComponent(planet.id.uuidString)
            let planetRootPath = "/v0/planets/my/\(planet.id.uuidString)/public"
            server[planetRootPath] = { r in
                if r.method == "GET" {
                    return PlanetAPI.shared.exposePlanetPublicContent(inDirectory: planetPublicURL.path, forRequest: r)
                } else {
                    return .error()
                }
            }
            if let subpaths = FileManager.default.subpaths(atPath: planetPublicURL.path) {
                for subpath in subpaths {
                    let urlPath = planetRootPath + "/" + subpath
                    let targetPath = planetPublicURL.appendingPathComponent(subpath).path
                    server[urlPath] = { r in
                        if r.method == "GET" {
                            return PlanetAPI.shared.exposePlanetPublicContent(inDirectory: targetPath, forRequest: r)
                        } else {
                            return .error()
                        }
                    }
                }
            }
        }
    }
}


class PlanetAPI: NSObject {
    static let shared = PlanetAPI()
    
    private(set) var myPlanets: [MyPlanetModel] = []
    private(set) var myArticles: [MyArticleModel] = []
    
    func updateMyPlanets(_ planets: [MyPlanetModel]) {
        myPlanets = planets
        var articles: [MyArticleModel] = []
        for planet in planets {
            if planet.articles != nil && planet.articles.count > 0 {
                articles.append(contentsOf: planet.articles)
            }
        }
        myArticles = articles
        Task {
            do {
                try await PlanetAPIHelper.shared.relaunch()
            } catch {
                debugPrint("failed to relaunch api server: \(error)")
            }
        }
    }
}


// MARK: - API Functions -

extension PlanetAPI {
    // MARK: GET /v0/planets/my
    func getPlanets(forRequest r: HttpRequest) -> HttpResponse {
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
    func createPlanet(forRequest r: HttpRequest) -> HttpResponse {
        guard validateRequest(r) else { return .unauthorized(nil) }
        let info: [String: Any] = processPlanetInfoRequest(r)
        let name: String = info["name"] as? String ?? ""
        let about: String = info["about"] as? String ?? ""
        var templateName: String = info["template"] as? String ?? ""
        let avatarImage: NSImage? = info["avatar"] as? NSImage ?? nil
        if name == "" || name == " " {
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
        let planetAvatarImage = avatarImage
        Task { @MainActor in
            do {
                let planet = try await MyPlanetModel.create(
                    name: planetName,
                    about: planetAbout,
                    templateName: planetTemplateName
                )
                if let planetAvatarImage {
                    try planet.uploadAvatar(image: planetAvatarImage)
                }
                try planet.save()
                try planet.savePublic()
                PlanetStore.shared.myPlanets.insert(planet, at: 0)
                PlanetStore.shared.selectedView = .myPlanet(planet)
            } catch {
                PlanetStore.shared.alert(title: "Failed to create planet")
            }
        }
        return .success()
    }

    // MARK: GET /v0/planets/my/:uuid
    func getPlanetInfo(forRequest r: HttpRequest) -> HttpResponse {
        guard validateRequest(r) else { return .unauthorized(nil) }
        guard
            let uuid = planetUUIDFromRequest(r),
            let planet = myPlanets.first(where: { $0.id == uuid })
        else {
            return .notFound()
        }
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(planet)
            let jsonObject = try JSONSerialization.jsonObject(with: data)
            return .ok(.json(jsonObject))
        } catch {
            return .error(error.localizedDescription)
        }
    }
    
    // MARK: POST /v0/planets/my/:uuid
    func modifyPlanetInfo(forRequest r: HttpRequest) -> HttpResponse {
        guard validateRequest(r) else { return .unauthorized(nil) }
        guard
            let uuid = planetUUIDFromRequest(r),
            let planet = myPlanets.first(where: { $0.id == uuid })
        else {
            return .notFound()
        }
        let info: [String: Any] = processPlanetInfoRequest(r)
        let planetName = info["name"] as? String ?? ""
        let planetAbout = info["about"] as? String ?? ""
        let planetTemplateName = info["template"] as? String ?? ""
        let planetAvatarImage = info["avatar"] as? NSImage ?? nil
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
                if let planetAvatarImage {
                    try planet.uploadAvatar(image: planetAvatarImage)
                }
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
    }
    
    // MARK: POST /v0/planets/my/:uuid/publish
    func publishPlanet(forRequest r: HttpRequest) -> HttpResponse {
        guard validateRequest(r) else { return .unauthorized(nil) }
        guard
            let uuid = planetUUIDFromRequest(r),
            let planet = myPlanets.first(where: { $0.id == uuid })
        else {
            return .notFound()
        }
        Task {
            do {
                try await planet.publish()
            } catch {
                debugPrint("failed to publish planet: \(planet), error: \(error)")
            }
        }
        return .success()
    }
    
    // MARK: GET /v0/planets/my/:uuid/public
    func exposePlanetPublicContent(inDirectory filePath: String, forRequest r: HttpRequest) -> HttpResponse {
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
                                            href = URL(fileURLWithPath: r.path).appendingPathComponent(file).path
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
                // MARK: TODO: handle large size data.
                let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
                responseHeader["Content-Length"] = String(data.count)
                return .raw(200, "OK", responseHeader, { writer in
                    try? writer.write(data)
                })
            }
        } catch {
            return .error(error.localizedDescription)
        }
    }
    
    // MARK: GET /v0/planets/my/:uuid/articles
    func getPlanetArticles(forRequest r: HttpRequest) -> HttpResponse {
        guard validateRequest(r) else { return .unauthorized(nil) }
        guard
            let uuid = planetUUIDFromRequest(r),
                let planet = myPlanets.first(where: { $0.id == uuid })
        else {
            return .notFound()
        }
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(planet.articles)
            let jsonObject = try JSONSerialization.jsonObject(with: data)
            return .ok(.json(jsonObject))
        } catch {
            return .error(error.localizedDescription)
        }
    }
    
    // MARK: POST /v0/planets/my/:uuid/articles
    func createPlanetArticle(forRequest r: HttpRequest) -> HttpResponse {
        guard validateRequest(r) else { return .unauthorized(nil) }
        guard
            let uuid = planetUUIDFromRequest(r),
            let planet = myPlanets.first(where: { $0.id == uuid })
        else {
            return .notFound()
        }
        let info: [String: Any] = processPlanetArticleRequest(r)
        let articleTitle = info["title"] as? String ?? ""
        let articleDateString = info["date"] as? String ?? Date().dateDescription()
        let articleContent = info["content"] as? String ?? ""
        if articleTitle == "" || articleTitle == " " {
            return .error("'title' is empty.")
        }
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
                for key in info.keys {
                    guard key.hasPrefix("attachment") else { continue }
                    guard let attachment: [String: Any] = info[key] as? [String : Any] else { continue }
                    guard
                        let attachmentData = attachment["data"] as? Data,
                        let attachmentFileName = attachment["fileName"] as? String,
                        let attachmentContentType = attachment["contentType"] as? String
                    else {
                        continue
                    }
                    try draft.addAttachmentFromData(data: attachmentData, fileName: attachmentFileName, forContentType: attachmentContentType)
                }
                try draft.saveToArticle()
            } catch {
                debugPrint("failed to create article for planet: \(planet), error: \(error)")
            }
        }
        return .success()
    }
    
    // MARK: GET /v0/planets/my/:uuid/articles/:uuid
    func getPlanetArticle(forRequest r: HttpRequest) -> HttpResponse {
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
    func modifyPlanetArticle(forRequest r: HttpRequest) -> HttpResponse {
        guard validateRequest(r) else { return .unauthorized(nil) }
        let results = planetUUIDAndArticleUUIDFromRequest(r)
        guard
            let planetUUID = results.0,
            let articleUUID = results.1,
            let planet = myPlanets.first(where: { $0.id == planetUUID }),
            let article = planet.articles.first(where: { $0.id == articleUUID })
        else {
            return .notFound()
        }
        let info: [String: Any] = processPlanetArticleRequest(r)
        let articleTitle = info["title"] as? String ?? ""
        let articleDateString = info["date"] as? String ?? Date().dateDescription()
        let articleContent = info["content"] as? String ?? ""
        Task { @MainActor in
            do {
                let draft = try DraftModel.create(from: article)
                draft.title = articleTitle
                if articleDateString == "" || articleDateString == " " {
                    draft.date = Date()
                } else {
                    draft.date = DateFormatter().date(from: articleDateString) ?? Date()
                }
                draft.content = articleContent
                for existingAttachment in draft.attachments {
                    draft.deleteAttachment(name: existingAttachment.name)
                }
                for key in info.keys {
                    guard key.hasPrefix("attachment") else { continue }
                    guard let attachment: [String: Any] = info[key] as? [String : Any] else { continue }
                    guard
                        let attachmentData = attachment["data"] as? Data,
                        let attachmentFileName = attachment["fileName"] as? String,
                        let attachmentContentType = attachment["contentType"] as? String
                    else {
                        continue
                    }
                    try draft.addAttachmentFromData(data: attachmentData, fileName: attachmentFileName, forContentType: attachmentContentType)
                }
                try draft.saveToArticle()
            } catch {
                debugPrint("failed to modify article for planet: \(planet), error: \(error)")
            }
        }
        return .success()
    }
    
    // MARK: DELETE /v0/planets/my/:uuid/articles/:uuid
    func deletePlanetArticle(forRequest r: HttpRequest) -> HttpResponse {
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
        guard
            let uuidString = r.params[":a"],
            let uuid = UUID(uuidString: uuidString)
        else {
            return nil
        }
        return uuid
    }
    
    private func planetUUIDAndArticleUUIDFromRequest(_ r: HttpRequest) -> (UUID?, UUID?) {
        guard
            let planetUUIDString = r.params[":a"],
            let planetUUID = UUID(uuidString: planetUUIDString),
            let articleUUIDString = r.params[":b"],
            let articleUUID = UUID(uuidString: articleUUIDString)
        else {
            return (nil, nil)
        }
        return (planetUUID, articleUUID)
    }
    
    private func validateRequest(_ r: HttpRequest) -> Bool {
        let apiUsesPasscode = UserDefaults.standard.bool(forKey: .settingsAPIUsesPasscode)
        let username = UserDefaults.standard.string(forKey: .settingsAPIUsername) ?? "Planet"
        if apiUsesPasscode {
            do {
                let passcode = try KeychainHelper.shared.loadValue(forKey: .settingsAPIPasscode)
                if passcode != "" {
                    if let auth = r.headers["authorization"], let encoded = auth.components(separatedBy: "Basic ").last, encoded != "", let usernameAndPasscode = encoded.base64Decoded(), usernameAndPasscode == "\(username):\(passcode)" {
                        return true
                    }
                }
                return false
            } catch {
                return false
            }
        }
        return true
    }
    
    private func processPlanetInfoRequest(_ r: HttpRequest) -> [String: Any] {
        var info: [String: Any] = [:]
        let multipartDatas = r.parseMultiPartFormData()
        let supportedContentTypes: [String] = ["image/jpeg", "image/png", "image/tiff"]
        for multipartData in multipartDatas {
            guard let propertyName = multipartData.name else { continue }
            switch propertyName {
            case "name", "about", "template":
                info[propertyName] = String(decoding: multipartData.body, as: UTF8.self)
            case "avatar":
                let data = Data(bytes: multipartData.body, count: multipartData.body.count)
                if let contentType = multipartData.headers["content-type"], supportedContentTypes.contains(contentType), let image = NSImage(data: data), image.isValid {
                    info["avatar"] = image
                }
            default:
                break
            }
        }
        return info
    }
    
    private func processPlanetArticleRequest(_ r: HttpRequest) -> [String: Any] {
        var info: [String: Any] = [:]
        let multipartDatas = r.parseMultiPartFormData()
        let supportedContentTypes: [String] = AttachmentType.supportedImageContentTypes + AttachmentType.supportedAudioContentTypes + AttachmentType.supportedVideoContentTypes
        for multipartData in multipartDatas {
            guard let propertyName = multipartData.name else { continue }
            switch propertyName {
            case "title", "date", "content":
                info[propertyName] = String(decoding: multipartData.body, as: UTF8.self)
            case "attachment":
                let data = Data(bytes: multipartData.body, count: multipartData.body.count)
                if let fileName = multipartData.fileName, data.count > 0, let contentType = multipartData.headers["content-type"], supportedContentTypes.contains(contentType) {
                    let attachmentData: [String: Any] = ["data": data, "fileName": fileName, "contentType": contentType]
                    if info[propertyName] == nil {
                        info[propertyName] = attachmentData
                    } else {
                        var index: Int = 1
                        var keyName = propertyName + "-" + String(index)
                        while info[keyName] != nil {
                            index += 1
                            keyName = propertyName + "-" + String(index)
                        }
                        info[keyName] = attachmentData
                    }
                }
            default:
                break
            }
        }
        return info
    }

    private func updateServerSettings() {
        if !UserDefaults.standard.bool(forKey: .settingsAPIEnabled) {
            Task {
                await PlanetAPIHelper.shared.shutdown()
            }
            return
        }
        /*
        let planets = myPlanets
        let repoPath = URLUtils.repoPath().appendingPathComponent("Public", conformingTo: .folder)
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
         */
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
