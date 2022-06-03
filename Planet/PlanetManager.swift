//
//  PlanetManager.swift
//  Planet
//
//  Created by Kai on 2/15/22.
//

import Foundation
import SwiftUI
import Stencil
import PathKit
import Ink

class PlanetManager: NSObject {
    static let shared: PlanetManager = PlanetManager()

    var importPath: URL!
    var exportPath: URL!
    var alertTitle: String = ""
    var alertMessage: String = ""

    override init() {
        super.init()
        debugPrint("Planet Manager Setup")

        RunLoop.main.add(Timer(timeInterval: 600, repeats: true) { [self] timer in
            publishLocalPlanets()
        }, forMode: .common)
        RunLoop.main.add(Timer(timeInterval: 300, repeats: true) { [self] timer in
            updateFollowingPlanets()
        }, forMode: .common)
    }

    // MARK: - General -
    func resizedAvatarImage(image: NSImage) -> NSImage {
        let targetImageSize = CGSize(width: 144, height: 144)
        if min(image.size.width, image.size.height) > targetImageSize.width / 2.0 {
            return image.resize(targetImageSize) ?? image
        } else {
            return image
        }
    }

    // MARK: - Planet & Planet Article -
    func destroyDirectory(fromPlanet planetUUID: UUID) {
        debugPrint("about to destroy directory from planet: \(planetUUID) ...")
        let planetPath = URLUtils.planetsPath.appendingPathComponent(planetUUID.uuidString)
        do {
            try FileManager.default.removeItem(at: planetPath)
        } catch {
            debugPrint("failed to destroy planet path at: \(planetPath), error: \(error)")
        }
    }

    func destroyArticleDirectory(planetUUID: UUID, articleUUID: UUID) async {
        debugPrint("about to destroy directory from article: \(articleUUID) ...")
        let articlePath = URLUtils.planetsPath.appendingPathComponent(planetUUID.uuidString).appendingPathComponent(articleUUID.uuidString)
        do {
            try FileManager.default.removeItem(at: articlePath)
        } catch {
            debugPrint("failed to destroy article path at: \(articlePath), error: \(error)")
        }
    }

    func articleURL(article: PlanetArticle) async -> URL? {
        guard let planet = PlanetDataController.shared.getPlanet(id: article.planetID!) else { return nil }
        let urlString: String
        if planet.isMyPlanet() {
            let articlePath = URLUtils.planetsPath.appendingPathComponent(planet.id!.uuidString).appendingPathComponent(article.id!.uuidString).appendingPathComponent("index.html")
            return articlePath
        }
        switch (planet.type) {
            case .planet:
                if let cid = planet.latestCID {
                    urlString = "\(await IPFSDaemon.shared.gateway)\(cid)\(article.link!)index.html"
                } else {
                    urlString = "\(await IPFSDaemon.shared.gateway)/ipns/\(planet.ipns!)\(article.link!)index.html"
                }
            case .ens:
                if let cid = planet.latestCID {
                    urlString = "\(await IPFSDaemon.shared.gateway)\(cid)\(article.link!)"
                } else {
                    urlString = "\(await IPFSDaemon.shared.gateway)/ipfs/\(planet.ipfs!)\(article.link!)"
                }
            case .dns:
                urlString = article.link!
            default:
                urlString = "\(await IPFSDaemon.shared.gateway)/ipns/\(planet.ipns!)/\(article.link!)/index.html"
        }
        debugPrint("article URL: \(urlString)")
        return URL(string: urlString)
    }

    func renderArticle(_ article: PlanetArticle) throws {
        debugPrint("rendering article: \(article)")
        let planet = PlanetDataController.shared.getPlanet(id: article.planetID!)!
        if !FileManager.default.fileExists(atPath: article.basePath.path) {
            try FileManager.default.createDirectory(at: article.basePath, withIntermediateDirectories: true)
        }

        let template = TemplateBrowserStore.shared[planet.templateName ?? "Plain"]!
        if FileManager.default.fileExists(atPath: planet.assetsPath.path) {
            try FileManager.default.removeItem(atPath: planet.assetsPath.path)
        }
        try FileManager.default.copyItem(at: template.assetsPath, to: planet.assetsPath)

        let output = try template.render(article: article)
        try output.data(using: .utf8)?.write(to: article.indexPath)

        // save article.json
        let encoder = JSONEncoder()
        let data = try encoder.encode(article)
        try data.write(to: article.metadataPath)

        // save index.html
        let articles = PlanetDataController.shared.getArticles(byPlanetID: article.planetID!)
        let outputIndex = try template.renderIndex(articles: articles, planet: planet)
        try outputIndex.data(using: .utf8)?.write(to: planet.indexPath)
    }

    func pin(_ endpoint: String) async {
        debugPrint("pinning \(endpoint) ...")
        do {
            try await IPFSDaemon.shared.api(path: "pin/add", args: ["arg": endpoint], timeout: 120)
            debugPrint("pinned \(endpoint)")
        } catch {
            debugPrint("failed to pin \(endpoint)")
        }
    }

    func publish(_ planet: Planet) async throws {
        guard let id = planet.id, let keyName = planet.keyName, keyName != "" else { return }
        let planetPath = URLUtils.planetsPath.appendingPathComponent(id.uuidString)
        guard FileManager.default.fileExists(atPath: planetPath.path) else { return }
        debugPrint("publishing for planet: \(planet), with key name: \(keyName) ...")

        // update planet.json
        let feedPath = planetPath.appendingPathComponent("planet.json")
        if FileManager.default.fileExists(atPath: feedPath.path) {
            do {
                try FileManager.default.removeItem(at: feedPath)
            } catch {
                debugPrint("failed to remove previous feed item at \(feedPath), error: \(error)")
            }
        }
        let articles = PlanetDataController.shared.getArticles(byPlanetID: id)
        let feedArticles: [PlanetFeedArticle] = articles.map { t in
            PlanetFeedArticle(
                    id: t.id!,
                    created: t.created!,
                    title: t.title ?? "",
                    content: t.content ?? "",
                    link: "/\(t.id!)/"
            )
        }
        let feed = PlanetFeed(
                id: id,
                ipns: planet.ipns!,
                created: planet.created!,
                updated: planet.lastUpdated ?? planet.created ?? Date(),
                name: planet.name,
                about: planet.about,
                articles: feedArticles
        )
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(feed)
            try data.write(to: feedPath)
        } catch {
            debugPrint("failed to encode feed: \(feed), at path: \(feedPath), error: \(error)")
            return
        }

        // add planet directory
        let cid: String
        do {
            cid = try await IPFSDaemon.shared.addDirectory(url: planetPath)
            planet.latestCID = "/ipfs/" + cid
            Task { @MainActor in
                PlanetDataController.shared.save()
                NotificationCenter.default.post(name: .publishPlanet, object: nil)
            }
        } catch {
            debugPrint("failed to add planet directory at: \(planetPath), error: \(error)")
            throw PlanetError.IPFSError
        }

        // publish
        do {
            let decoder = JSONDecoder()
            let data = try await IPFSDaemon.shared.api(path: "name/publish", args: [
                "arg": cid,
                "allow-offline": "1",
                "key": keyName,
                "quieter": "1",
                "lifetime": "168h",
            ], timeout: 600)
            let published = try decoder.decode(PlanetPublished.self, from: data)
            if let planetIPNS = published.name {
                debugPrint("planet: \(planet) is published: \(planetIPNS)")
            } else {
                debugPrint("planet: \(planet) not published: \(published).")
            }
        } catch {
            debugPrint("failed to publish planet: \(planet), at path: \(planetPath), error: \(error)")
        }

        planet.lastPublished = Date()
    }

    func update(_ planet: Planet) async throws {
        if planet.type == .ens {
            debugPrint("Going to update Type 1 ENS planet: \(planet.ens!)")
            try await PlanetDataController.shared.updateENSPlanet(planet: planet)
        } else if planet.type == .dns {
            debugPrint("Going to update Type 3 DNS planet: \(planet.dns!)")
            try await PlanetDataController.shared.updateDNSPlanet(planet: planet)
        } else {
            try await PlanetDataController.shared.updateNativePlanet(planet: planet)
        }
        planet.lastUpdated = Date()
        PlanetDataController.shared.save()
        debugPrint("done updating.")
    }

    func publishLocalPlanets() {
        Task.init(priority: .background) {
            let planets = PlanetDataController.shared.getLocalPlanets()
            debugPrint("publishing local planets: \(planets) ...")
            for planet in planets {
                if !(await planet.isPublishing) {
                    await MainActor.run {
                        planet.isPublishing = true
                    }
                    do {
                        try await PlanetManager.shared.publish(planet)
                    } catch {}
                    await MainActor.run {
                        planet.isPublishing = false
                    }
                }

            }
        }
    }

    func updateFollowingPlanets() {
        Task.init(priority: .background) {
            let planets = PlanetDataController.shared.getFollowingPlanets()
            debugPrint("updating following planets: \(planets) ...")
            for planet in planets {
                if !(await planet.isUpdating) {
                    await MainActor.run {
                        planet.isUpdating = true
                    }
                    try? await update(planet)
                    await MainActor.run {
                        planet.isUpdating = false
                    }
                }
            }
        }
    }

    func followPlanet(url: String) async throws {
        let processed: String
        if url.hasPrefix("planet://") {
            processed = url.replacingOccurrences(of: "planet://", with: "")
        } else {
            processed = url
        }

        if PlanetDataController.shared.planetExists(planetURL: processed) {
            await alert(title: "Failed to follow planet", message: "You are already following this planet.")
            return
        }

        let planet: Planet?
        if processed.hasSuffix(".eth") {
            planet = PlanetDataController.shared.createPlanet(ens: processed)
        } else if processed.hasPrefix("https://") {
            planet = PlanetDataController.shared.createPlanet(endpoint: processed)
        } else {
            let localIPNS = PlanetDataController.shared.getLocalPlanets().compactMap { planet in
                planet.ipns
            }
            guard !localIPNS.contains(processed) else {
                throw PlanetError.FollowLocalPlanetError
            }
            planet = PlanetDataController.shared.createPlanet(withID: UUID(), name: "", about: "", ipns: processed)
        }

        guard let planet = planet else {
            throw PlanetError.InvalidPlanetURLError
        }

        await MainActor.run {
            PlanetStore.shared.pendingFollowingPlanet = planet
        }

        do {
            try await update(planet)
        } catch PlanetError.PlanetFeedError, PlanetError.InvalidPlanetURLError {
            if planet.softDeleted == nil {
                await alert(title: "Unable to follow planet", message: "The URL provided is not a planet.")
                await PlanetDataController.shared.remove(planet)
            }
        } catch {
            if planet.softDeleted == nil {
                await alert(title: "Failed to follow planet")
                await PlanetDataController.shared.remove(planet)
            }
        }
        PlanetDataController.shared.save()
    }

    // MARK: -
    @MainActor
    func importCurrentPlanet() {
        guard let importPath = PlanetManager.shared.importPath else {
            alert(title: "Failed to Import Planet", message: "Please choose a planet data file to import.")
            return
        }

        let importPlanetInfoPath = importPath.appendingPathComponent("planet.json")
        guard FileManager.default.fileExists(atPath: importPlanetInfoPath.path) else {
            alert(title: "Failed to Import Planet", message: "The planet data file is damaged.")
            return
        }

        let importPlanetAssetsPath = importPath.appendingPathComponent("assets")
        guard FileManager.default.fileExists(atPath: importPlanetAssetsPath.path) else {
            alert(title: "Failed to Import Planet", message: "The planet data file is damaged.")
            return
        }

        let importPlanetIndexPath = importPath.appendingPathComponent("index.html")
        guard FileManager.default.fileExists(atPath: importPlanetIndexPath.path) else {
            alert(title: "Failed to Import Planet", message: "The planet data file is damaged.")
            return
        }

        let importPlanetKeyPath = importPath.appendingPathComponent("planet.key")
        guard FileManager.default.fileExists(atPath: importPlanetKeyPath.path) else {
            alert(title: "Failed to Import Planet", message: "The planet data file is damaged.")
            return
        }

        let decoder = JSONDecoder()
        do {
            let planetInfoData = try Data.init(contentsOf: importPlanetInfoPath)
            let planetInfo = try decoder.decode(PlanetFeed.self, from: planetInfoData)

            guard let planetName = planetInfo.name else {
                alert(title: "Failed to Import Planet", message: "The planet is invalid: missing planet name.")
                return
            }

            guard PlanetDataController.shared.getPlanet(id: planetInfo.id) == nil else {
                alert(title: "Failed to Import Planet", message: "The planet '\(String(describing: planetInfo.name))' exists.")
                return
            }

            let planetDirectories = try FileManager.default.contentsOfDirectory(at: importPath, includingPropertiesForKeys: nil, options: .skipsHiddenFiles).filter({ u in
                u.hasDirectoryPath && u.lastPathComponent.count == UUID().uuidString.count
            })

            // import planet key if needed
            let keyName = planetInfo.id.uuidString
            let keyPath = importPath.appendingPathComponent("planet.key")
            try IPFSCommand.importKey(name: keyName, target: keyPath).run()

            // create planet
            let _ = PlanetDataController.shared.createPlanet(
                withID: planetInfo.id,
                name: planetName,
                about: planetInfo.about ?? "",
                keyName: planetInfo.id.uuidString,
                keyID: planetInfo.ipns,
                ipns: planetInfo.ipns,
                templateName: "Plain"
            )

            // create planet directory if needed
            let targetPlanetPath = URLUtils.planetsPath.appendingPathComponent(planetInfo.id.uuidString)
            if !FileManager.default.fileExists(atPath: targetPlanetPath.path) {
                try FileManager.default.createDirectory(at: targetPlanetPath, withIntermediateDirectories: true, attributes: nil)
            }

            // copy planet.json
            try FileManager.default.copyItem(at: importPlanetInfoPath, to: targetPlanetPath.appendingPathComponent("planet.json"))

            // copy assets folder
            try FileManager.default.copyItem(at: importPlanetAssetsPath, to: targetPlanetPath.appendingPathComponent("assets"))

            // copy index.html
            try FileManager.default.copyItem(at: importPlanetIndexPath, to: targetPlanetPath.appendingPathComponent("index.html"))

            // copy avatar.png if exists
            let importPlanetAvatarPath = importPath.appendingPathComponent("avatar.png")
            if FileManager.default.fileExists(atPath: importPlanetAvatarPath.path) {
                try FileManager.default.copyItem(at: importPlanetAvatarPath, to: targetPlanetPath.appendingPathComponent("avatar.png"))
            }

            // import planet directory from feed, ignore publish status.
            let decoder: JSONDecoder = JSONDecoder()
            var targetArticles: Set<PlanetFeedArticle> = Set()
            for planetDirectory in planetDirectories {
                let articleJSONPath = planetDirectory.appendingPathComponent("article.json")
                let articleJSONData = try Data(contentsOf: articleJSONPath)
                let article = try decoder.decode(PlanetFeedArticle.self, from: articleJSONData)
                try FileManager.default.copyItem(at: planetDirectory, to: targetPlanetPath.appendingPathComponent(planetDirectory.lastPathComponent))
                targetArticles.insert(article)
            }
            if targetArticles.count > 0 {
                let articles: [PlanetFeedArticle] = Array(targetArticles)
                Task.init(priority: .background) {
                    await PlanetDataController.shared.batchImportArticles(articles: articles, planetID: planetInfo.id)
                }
            }

            alert(title: "Planet Imported", message: planetName)
        } catch {
            alert(title: "Failed to Import Planet", message: error.localizedDescription)
        }
        PlanetDataController.shared.save()
    }

    @MainActor
    func exportCurrentPlanet() {
        guard let planet = PlanetStore.shared.currentPlanet,
              planet.isMyPlanet(), let planetID = planet.id,
              let planetName = planet.name,
              let planetKeyName = planet.keyName else {
            alert(
                    title: "Failed to Export Planet",
                    message: "Unable to prepare for current selected planet, please make sure the planet you selected is ready to export then try again."
            )
            return
        }

        guard let exportPath = PlanetManager.shared.exportPath else {
            alert(title: "Failed to Export Planet", message: "Please choose the export path then try again.")
            return
        }

        let exportPlanetPath = exportPath.appendingPathComponent("\(planetName.sanitized()).planet")
        guard FileManager.default.fileExists(atPath: exportPlanetPath.path) == false else {
            alert(title: "Failed to Export Planet", message: "Export path exists, please choose another export path then try again.")
            return
        }

        let planetInfoPath = URLUtils.planetsPath.appendingPathComponent(planetID.uuidString).appendingPathComponent("planet.json")
        let planetIndexPath = URLUtils.planetsPath.appendingPathComponent(planetID.uuidString).appendingPathComponent("index.html")
        guard FileManager.default.fileExists(atPath: planetInfoPath.path), FileManager.default.fileExists(atPath: planetIndexPath.path) else {
            alert(title: "Failed to Export Planet", message: "This planet has no articles to export.")
            return
        }

        let currentPlanetPath = URLUtils.planetsPath.appendingPathComponent(planetID.uuidString)
        do {
            try FileManager.default.copyItem(at: currentPlanetPath, to: exportPlanetPath)
        } catch {
            alert(title: "Failed to Export Planet", message: error.localizedDescription)
            return
        }

        let exportPlanetKeyPath = exportPlanetPath.appendingPathComponent("planet.key")
        do {
            try IPFSCommand.exportKey(name: planetKeyName, target: exportPlanetKeyPath).run()
        } catch {
            debugPrint("failed to export planet key: \(error)")
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([exportPlanetPath])
    }

    @MainActor func alert(title: String, message: String? = nil) {
        PlanetStore.shared.isAlert = true
        alertTitle = title
        alertMessage = message ?? ""
    }

    private func getInternalPortsInformationFromConfig() async -> (String?, String?) {
        do {
            let data = try await IPFSDaemon.shared.api(path: "config/show")
            let decoder = JSONDecoder()
            let config: PlanetConfig = try decoder.decode(PlanetConfig.self, from: data)
            if let api = config.addresses?.api, let gateway = config.addresses?.gateway {
                return (api, gateway)
            }
        } catch {}
        return (nil, nil)
    }
}
