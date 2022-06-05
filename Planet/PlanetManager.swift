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
        if !FileManager.default.fileExists(atPath: article.baseURL.path) {
            try FileManager.default.createDirectory(at: article.baseURL, withIntermediateDirectories: true)
        }

        let template = TemplateBrowserStore.shared[planet.templateName ?? "Plain"]!
        if FileManager.default.fileExists(atPath: planet.assetsURL.path) {
            try FileManager.default.removeItem(at: planet.assetsURL)
        }
        try FileManager.default.copyItem(at: template.assetsPath, to: planet.assetsURL)

        let output = try template.render(article: article)
        try output.data(using: .utf8)?.write(to: article.indexURL)

        // save article.json
        let encoder = JSONEncoder()
        let data = try encoder.encode(article)
        try data.write(to: article.infoURL)

        // save index.html
        let articles = PlanetDataController.shared.getArticles(byPlanetID: article.planetID!)
        let outputIndex = try template.renderIndex(articles: articles, planet: planet)
        try outputIndex.data(using: .utf8)?.write(to: planet.indexURL)
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
                name: planet.name!,
                about: planet.about!,
                ipns: planet.ipns!,
                created: planet.created!,
                updated: planet.lastUpdated ?? planet.created ?? Date(),
                articles: feedArticles,
                templateName: planet.templateName
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
            debugPrint("planet: \(planet) is published: \(published.name)")
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

    @MainActor func alert(title: String, message: String? = nil) {
        PlanetStore.shared.isAlert = true
        alertTitle = title
        alertMessage = message ?? ""
    }
}
