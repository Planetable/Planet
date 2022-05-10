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

    private var publishTimer: Timer?
    private var feedTimer: Timer?
    private var statusTimer: Timer?

    private var unitTesting: Bool = {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }()

    private var commandQueue: OperationQueue = {
        let q = OperationQueue()
        q.maxConcurrentOperationCount = 1
        q.qualityOfService = .utility
        return q
    }()

    private var commandDaemonQueue: OperationQueue = {
        let q = OperationQueue()
        q.maxConcurrentOperationCount = 2
        q.qualityOfService = .background
        return q
    }()

    var apiPort: String = "" {
        didSet {
            guard apiPort != "" else { return }
            commandQueue.addOperation {
                do {
                    let _ = try runCommand(command: .ipfsUpdateAPIPort(target: self.ipfsPath, config: self.ipfsConfigPath, port: self.apiPort))
                } catch {
                    debugPrint("failed to update api port: \(error)")
                }
            }
        }
    }

    var gatewayPort: String = "" {
        didSet {
            guard gatewayPort != "" else { return }
            commandQueue.addOperation {
                do {
                    let _ = try runCommand(command: .ipfsUpdateGatewayPort(target: self.ipfsPath, config: self.ipfsConfigPath, port: self.gatewayPort))
                } catch {
                    debugPrint("failed to update gateway port: \(error)")
                }
            }
        }
    }

    var swarmPort: String = "" {
        didSet {
            guard swarmPort != "" else { return }
            commandQueue.addOperation {
                do {
                    let _ = try runCommand(command: .ipfsUpdateSwarmPort(target: self.ipfsPath, config: self.ipfsConfigPath, port: self.swarmPort))
                } catch {
                    debugPrint("failed to update swarm port: \(error)")
                }
            }
        }
    }

    var ipfsGateway: String {
        get {
            "http://127.0.0.1:\(gatewayPort)"
        }
    }

    var currentPlanetVersion: String = ""
    var importPath: URL!
    var exportPath: URL!
    var alertTitle: String = ""
    var alertMessage: String = ""
    var templatePaths: [URL] = []

    func setup() {
        debugPrint("Planet Manager Setup")

        loadTemplates()

        publishTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [self] timer in publishLocalPlanets() }
        feedTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [self] timer in updateFollowingPlanets() }
        statusTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [self] timer in updatePlanetStatus() }

        Task.init(priority: .utility) {
            guard verifyIPFSOnlineStatus() else { return }
            updateInternalPorts()
            launchDaemon()
        }
    }

    func cleanup() {
        debugPrint("Planet Manager Cleanup")
        terminateDaemon(forceSkip: true)
        publishTimer?.invalidate()
        feedTimer?.invalidate()
        statusTimer?.invalidate()
    }

    func relaunchDaemon() {
        relaunchDaemonIfNeeded()
    }

    // MARK: - General -
    func loadTemplates() {
        let templatePath = templatesPath
        if let sourcePath = Bundle.main.url(forResource: "Basic", withExtension: "html") {
            let targetPath = templatePath.appendingPathComponent("basic.html")
            do {
                if FileManager.default.fileExists(atPath: targetPath.path) {
                    try? FileManager.default.removeItem(at: targetPath)
                }
                try FileManager.default.copyItem(at: sourcePath, to: targetPath)
            } catch {
                debugPrint("failed to copy template file: \(error)")
            }
            templatePaths.append(targetPath)
        }
    }

    func checkDaemonStatus() async -> Bool {
        let status: Bool

        if apiPort != "" {
            let url = URL(string: "http://127.0.0.1:\(apiPort)/webui")!
            let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 1)
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let res = response as? HTTPURLResponse, res.statusCode == 200 {
                    status = true
                } else {
                    status = false
                }
            } catch {
                status = false
            }
        } else {
            status = false
        }
        await MainActor.run {
            PlanetStatusViewModel.shared.daemonIsOnline = status
        }
        return status
    }

    func checkPeersStatus() async -> Int {
        let request = apiRequest(path: "swarm/peers")
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoder = JSONDecoder()
            let peers = try decoder.decode(PlanetPeers.self, from: data)
            DispatchQueue.main.async {
                PlanetStatusViewModel.shared.peersCount = peers.peers?.count ?? 0
            }
        } catch {}
        return 0
    }

    func generateKeys() async -> (keyName: String?, keyID: String?) {
        let uuid = UUID()
        let checkKeyExistsRequest = apiRequest(path: "key/list")
        do {
            let (data, _) = try await URLSession.shared.data(for: checkKeyExistsRequest)
            do {
                let decoder = JSONDecoder()
                let availableKeys = try decoder.decode(PlanetKeys.self, from: data)
                var keyID: String = ""
                var keyName: String = ""
                var keyExists: Bool = false
                if let keys = availableKeys.keys {
                    for k in keys {
                        if k.name == uuid.uuidString {
                            keyID = k.id ?? ""
                            keyName = k.name ?? ""
                            keyExists = true
                            break
                        }
                    }
                }
                if keyExists {
                    return (keyName, keyID)
                } else {
                    let generateKeyRequest = apiRequest(path: "key/gen", args: ["arg": uuid.uuidString])
                    do {
                        let (data, _) = try await URLSession.shared.data(for: generateKeyRequest)
                        let genKey = try decoder.decode(PlanetKey.self, from: data)
                        if let theKeyName = genKey.name, let theKeyID = genKey.id {
                            return (theKeyName, theKeyID)
                        } else {
                            debugPrint("failed to generate key, empty result.")
                        }
                    } catch {
                        debugPrint("failed to generate key: \(error)")
                    }
                }
            } catch {
                debugPrint("failed to check key: \(error)")
            }
        } catch {
            debugPrint("failed to create planet.")
        }
        return (nil, nil)
    }

    func ipfsENVPath() -> URL {
        let envPath = ipfsEnvPath
        if !FileManager.default.fileExists(atPath: envPath.path) {
            try? FileManager.default.createDirectory(at: envPath, withIntermediateDirectories: true, attributes: nil)
        }
        return envPath
    }

    func ipfsVersion() async -> String {
        let checkKeyExistsRequest = apiRequest(path: "version")
        do {
            let (data, _) = try await URLSession.shared.data(for: checkKeyExistsRequest)
            let decoder = JSONDecoder()
            let info: PlanetIPFSVersionInfo = try decoder.decode(PlanetIPFSVersionInfo.self, from: data)
            if let version = info.version, let system = info.system {
                return version + " " + system
            }
        } catch {
            debugPrint("failed to get ipfs version, error: \(error)")
        }
        return "0.12.0"
    }

    func deleteKey(withName name: String) async {
        let checkKeyExistsRequest = apiRequest(path: "key/rm", args: ["arg": name])
        do {
            let (_, _) = try await URLSession.shared.data(for: checkKeyExistsRequest)
        } catch {
            debugPrint("failed to remove key with name: \(name), error: \(error)")
        }
    }

    func resizedAvatarImage(image: NSImage) -> NSImage {
        let targetImage: NSImage
        let targetImageSize = CGSize(width: 144, height: 144)
        if min(image.size.width, image.size.height) > targetImageSize.width / 2.0 {
            targetImage = image.imageResize(targetImageSize) ?? image
        } else {
            targetImage = image
        }
        return targetImage
    }

    func updateAvatar(forPlanet planet: Planet, image: NSImage, isEditing: Bool = false) {
        guard let id = planet.id else { return }
        let imageURL = _avatarPath(forPlanetID: id, isEditing: isEditing)
        let targetImage = resizedAvatarImage(image: image)
        targetImage.imageSave(imageURL)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .updateAvatar, object: nil)
        }
    }

    func removeAvatar(forPlanet planet: Planet) {
        guard let id = planet.id else { return }
        let imageURL = _avatarPath(forPlanetID: id, isEditing: false)
        let imageEditURL = _avatarPath(forPlanetID: id, isEditing: true)
        try? FileManager.default.removeItem(at: imageURL)
        try? FileManager.default.removeItem(at: imageEditURL)
    }

    func avatar(forPlanet planet: Planet) -> NSImage? {
        if let id = planet.id {
            let imageURL = _avatarPath(forPlanetID: id, isEditing: false)
            if FileManager.default.fileExists(atPath: imageURL.path) {
                return NSImage(contentsOf: imageURL)
            }
        }
        return nil
    }

    // MARK: - Planet & Planet Article -
    func destroyDirectory(fromPlanet planetUUID: UUID) {
        debugPrint("about to destroy directory from planet: \(planetUUID) ...")
        let planetPath = planetsPath.appendingPathComponent(planetUUID.uuidString)
        do {
            try FileManager.default.removeItem(at: planetPath)
        } catch {
            debugPrint("failed to destroy planet path at: \(planetPath), error: \(error)")
        }
    }

    func destroyArticleDirectory(planetUUID: UUID, articleUUID: UUID) async {
        debugPrint("about to destroy directory from article: \(articleUUID) ...")
        let articlePath = planetsPath.appendingPathComponent(planetUUID.uuidString).appendingPathComponent(articleUUID.uuidString)
        do {
            try FileManager.default.removeItem(at: articlePath)
        } catch {
            debugPrint("failed to destroy article path at: \(articlePath), error: \(error)")
        }
    }

    func articleURL(article: PlanetArticle) -> URL? {
        guard let articleID = article.id, let planetID = article.planetID else { return nil }
        guard let planet = PlanetDataController.shared.getPlanet(id: article.planetID!) else { return nil }
        if planet.isMyPlanet() {
            let articlePath = planetsPath.appendingPathComponent(planetID.uuidString).appendingPathComponent(articleID.uuidString).appendingPathComponent("index.html")
            return articlePath
        } else {
            debugPrint("Trying to get article URL")
            let urlString: String = {
                switch (planet.type) {
                    case .planet:
                        return "\(ipfsGateway)/ipns/\(planet.ipns!)\(article.link!)index.html"
                    case .ens:
                        return "\(ipfsGateway)/ipfs/\(planet.ipfs!)\(article.link!)"
                    case .dns:
                        return article.link!
                    default:
                        return "\(ipfsGateway)/ipns/\(planet.ipns!)/\(article.link!)/index.html"
                }
            }()
            debugPrint("Article URL string: \(urlString)")
            return URL(string: urlString)
        }
    }

    func articleReadStatus(article: PlanetArticle) -> Bool {
        article.read != nil
    }

    func renderArticle(_ article: PlanetArticle) {
        debugPrint("about to render article: \(article)")
        let planetPath = planetsPath.appendingPathComponent(article.planetID!.uuidString)
        let articlePath = planetPath.appendingPathComponent(article.id!.uuidString)
        if !FileManager.default.fileExists(atPath: articlePath.path) {
            do {
                try FileManager.default.createDirectory(at: articlePath, withIntermediateDirectories: true, attributes: nil)
            } catch {
                debugPrint("failed to create article path: \(articlePath), error: \(error)")
                return
            }
        }
        // MARK: TODO: Choose Template [legacy]
        let templatePath = templatePaths[0]
        // render html
        let loader = FileSystemLoader(paths: [Path(templatePath.deletingLastPathComponent().path)])
        let environment = Environment(loader: loader)
        let parser = MarkdownParser()
        let result = parser.parse(article.content!)
        let content_html = result.html
        var context: [String: Any]
        context = ["article": article, "created_date": article.created!.ISO8601Format(), "content_html": content_html]
        let templateName = templatePath.lastPathComponent
        let articleIndexPagePath = articlePath.appendingPathComponent("index.html")
        do {
            let output: String = try environment.renderTemplate(name: templateName, context: context)
            try output.data(using: .utf8)?.write(to: articleIndexPagePath)
        } catch {
            debugPrint("failed to render article: \(error), at path: \(articleIndexPagePath)")
            return
        }
        // save article.json
        let articleJSONPath = articlePath.appendingPathComponent("article.json")
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(article)
            try data.write(to: articleJSONPath)
        } catch {
            debugPrint("failed to save article summary json: \(error), at: \(articleJSONPath)")
            return
        }

        // refresh
        NotificationCenter.default.post(name: .refreshArticle, object: article.id!)
        debugPrint("article \(article.id), rendered and refreshed at: \(articlePath)")
    }

    func pin(_ endpoint: String) {
        debugPrint("pinning \(endpoint) ...")
        let pinRequest = apiRequest(path: "pin/add", args: ["arg": endpoint], timeout: 120)
        URLSession.shared.dataTask(with: pinRequest) { data, response, error in
            debugPrint("pinned: \(String(describing: response)).")
        }.resume()
    }

    @MainActor func publish(_ planet: Planet) async {
        guard !planet.isPublishing else {
            return
        }
        planet.isPublishing = true
        defer {
            planet.isPublishing = false
        }

        guard let id = planet.id, let keyName = planet.keyName, keyName != "" else { return }
        let planetPath = planetsPath.appendingPathComponent(id.uuidString)
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
        var planetCID: String?
        do {
            let result = try runCommand(command: .ipfsAddDirectory(target: ipfsPath, config: ipfsConfigPath, directory: planetPath))
            if let result = result["result"] as? [String], let cid: String = result.first {
                planetCID = cid
                debugPrint("Planet CID: \(String(describing: planet.name)) - \(cid)")
            }
        } catch {
            debugPrint("failed to add planet directory at: \(planetPath), error: \(error)")
        }
        if planetCID == nil {
            debugPrint("failed to add planet directory: empty cid.")
            return
        }

        // publish
        do {
            let decoder = JSONDecoder()
            let (data, _) = try await URLSession.shared.data(for: apiRequest(path: "name/publish", args: [
                "arg": planetCID!,
                "allow-offline": "1",
                "key": keyName,
                "quieter": "1",
                "lifetime": "168h",
            ], timeout: 600))
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
        PlanetDataController.shared.save()
        debugPrint("done updating.")
    }

    func publishLocalPlanets() {
        Task.init(priority: .background) {
            guard PlanetStatusViewModel.shared.daemonIsOnline else { return }
            let planets = PlanetDataController.shared.getLocalPlanets()
            debugPrint("publishing local planets: \(planets) ...")
            for planet in planets {
                await publish(planet)
            }
        }
    }

    func updateFollowingPlanets() {
        Task.init(priority: .background) {
            guard PlanetStatusViewModel.shared.daemonIsOnline else { return }
            let planets = PlanetDataController.shared.getFollowingPlanets()
            debugPrint("updating following planets: \(planets) ...")
            for planet in planets {
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

    func updatePlanetStatus() {
        Task.init(priority: .background) {
            await checkDaemonStatus()
        }
        Task.init(priority: .background) {
            await checkPeersStatus()
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
            planet = PlanetDataController.shared.createPlanet(withID: UUID(), name: "", about: "", keyName: nil, keyID: nil, ipns: processed)
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
            await PlanetDataController.shared.remove(planet)
            await alert(title: "Unable to follow planet", message: "The URL provided is not a planet.")
        } catch {
            await PlanetDataController.shared.remove(planet)
            await alert(title: "Failed to follow planet")
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

        let importPlanetKeyPath = importPath.appendingPathComponent("planet.key")
        guard FileManager.default.fileExists(atPath: importPlanetKeyPath.path) else {
            alert(title: "Failed to Import Planet", message: "The planet data file is damaged.")
            return
        }

        let decoder = JSONDecoder()
        do {
            let planetInfoData = try Data.init(contentsOf: importPlanetInfoPath)
            let planetInfo = try decoder.decode(PlanetFeed.self, from: planetInfoData)

            if PlanetDataController.shared.getPlanet(id: planetInfo.id) != nil {
                alert(title: "Failed to Import Planet", message: "The planet '\(String(describing: planetInfo.name))' exists.")
                return
            }

            let planetDirectories = try FileManager.default.contentsOfDirectory(at: importPath, includingPropertiesForKeys: nil, options: .skipsHiddenFiles).filter({ u in
                u.hasDirectoryPath
            })

            // import planet key if needed
            let targetPath = ipfsPath
            let configPath = ipfsConfigPath
            let importPlanetKeyName = planetInfo.id.uuidString
            let importPlanetKeyPath = importPath.appendingPathComponent("planet.key")
            try runCommand(command: .ipfsImportKey(target: targetPath, config: configPath, keyName: importPlanetKeyName, targetPath: importPlanetKeyPath))

            // create planet
            guard let planetName = planetInfo.name else {
                alert(title: "Failed to Import Planet", message: "The planet is invalid: missing planet name.")
                return
            }

            let _ = PlanetDataController.shared.createPlanet(withID: planetInfo.id, name: planetName, about: planetInfo.about ?? "", keyName: planetInfo.id.uuidString, keyID: planetInfo.ipns, ipns: planetInfo.ipns)

            // create planet directory if needed
            let targetPlanetPath = planetsPath.appendingPathComponent(planetInfo.id.uuidString)
            if !FileManager.default.fileExists(atPath: targetPlanetPath.path) {
                try FileManager.default.createDirectory(at: targetPlanetPath, withIntermediateDirectories: true, attributes: nil)
            }

            // copy planet.json
            try FileManager.default.copyItem(at: importPlanetInfoPath, to: targetPlanetPath.appendingPathComponent("planet.json"))

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

        let currentPlanetPath = planetsPath.appendingPathComponent(planetID.uuidString)
        do {
            try FileManager.default.copyItem(at: currentPlanetPath, to: exportPlanetPath)
        } catch {
            alert(title: "Failed to Export Planet", message: error.localizedDescription)
            return
        }

        let targetPath = ipfsPath
        let configPath = ipfsConfigPath
        let exportPlanetKeyPath = exportPlanetPath.appendingPathComponent("planet.key")
        do {
            try runCommand(command: .ipfsExportKey(target: targetPath, config: configPath, keyName: planetKeyName, targetPath: exportPlanetKeyPath))
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

    // MARK: - Private -
    private func verifyIPFSOnlineStatus() -> Bool {
        let targetPath = ipfsPath
        let configPath = ipfsConfigPath
        if FileManager.default.fileExists(atPath: targetPath.path) && FileManager.default.fileExists(atPath: configPath.path) {
            do {
                let lists = try FileManager.default.contentsOfDirectory(atPath: configPath.path)
                if lists.count >= 6 {
                    let _ = try runCommand(command: .ipfsGetID(target: targetPath, config: configPath))
                    return true
                }
            } catch {}
        } else {
            let binaryDataName: String = isOnAppleSilicon() ? "IPFS-GO-ARM" : "IPFS-GO"
            if let data = NSDataAsset(name: NSDataAsset.Name(binaryDataName)) {
                do {
                    try data.data.write(to: targetPath, options: .atomic)
                    try FileManager.default.setAttributes([.posixPermissions: 755], ofItemAtPath: targetPath.path)
                    let _ = try runCommand(command: .ipfsInit(target: targetPath, config: configPath))
                    let _ = try runCommand(command: .ipfsGetID(target: targetPath, config: configPath))
                    return true
                } catch {}
            }
        }
        return false
    }

    private func verifyPortAvailability(port: String) async -> Bool {
        let request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)")!, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 1)
        debugPrint("verify port: \(port)")
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let res = response as? HTTPURLResponse {
                if !(200..<500).contains(res.statusCode) {
                    return true
                }
            }
            return false
        } catch {
            return true
        }
    }

    private func isPortOpen(port: UInt16) -> Bool {
        let socketFileDescriptor = socket(AF_INET, SOCK_STREAM, 0)
        if socketFileDescriptor == -1 {
            return false
        }
        var addr = sockaddr_in()
        let sizeOfSockkAddr = MemoryLayout<sockaddr_in>.size
        addr.sin_len = __uint8_t(sizeOfSockkAddr)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = Int(OSHostByteOrder()) == OSLittleEndian ? _OSSwapInt16(port) : port
        addr.sin_addr = in_addr(s_addr: inet_addr("0.0.0.0"))
        addr.sin_zero = (0, 0, 0, 0, 0, 0, 0, 0)
        var bind_addr = sockaddr()
        memcpy(&bind_addr, &addr, Int(sizeOfSockkAddr))
        if Darwin.bind(socketFileDescriptor, &bind_addr, socklen_t(sizeOfSockkAddr)) == -1 {
            return false
        }
        if listen(socketFileDescriptor, SOMAXCONN ) == -1 {
            return false
        }
        return true
    }

    private func apiRequest(path: String, args: [String: String] = [:], timeout: TimeInterval = 5) -> URLRequest {
        var url: URL = URL(string: "http://127.0.0.1:\(apiPort)/api/v0/\(path)")!
        if args != [:] {
            url = url.appendingQueryParameters(args)
        }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: timeout)
        request.httpMethod = "POST"
        return request
    }

    private func terminateDaemon(forceSkip: Bool = false) {
        let request = apiRequest(path: "shutdown")
        URLSession.shared.dataTask(with: request) { data, response, error in
        }.resume()
    }

    private func launchDaemon() {
        Task.init(priority: .utility) {
            guard await checkDaemonStatus() == false else { return }
            commandDaemonQueue.addOperation { [self] in
                do {
                    let _ = try runCommand(command: .ipfsLaunchDaemon(target: ipfsPath, config: ipfsConfigPath))
                } catch {
                    debugPrint("failed to launch daemon: \(error). will try to start daemon again after 3 seconds.")
                    let _ = try? runCommand(command: .ipfsTerminateDaemon(target: ipfsPath, config: ipfsConfigPath))
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                Task.init(priority: .utility) {
                    let s = await self.checkDaemonStatus()
                    if !s {
                        DispatchQueue.global().async {
                            self.launchDaemon()
                        }
                    } else {
                        DispatchQueue.global(qos: .background).async {
                            self.publishLocalPlanets()
                            self.updateFollowingPlanets()
                        }
                        self.currentPlanetVersion = await self.ipfsVersion()
                    }
                }
            }
        }
    }

    private func relaunchDaemonIfNeeded() {
        debugPrint("relaunching daemon ...")
        Task.init(priority: .utility) {
            let status = await checkDaemonStatus()
            if status {
                let (api, gateway) = await getInternalPortsInformationFromConfig()
                if let a = api, let g = gateway {
                    if let theAPIPort = a.components(separatedBy: "/").last, let theGatewayPort = g.components(separatedBy: "/").last {
                        if theAPIPort == self.apiPort, theGatewayPort == self.gatewayPort {
                            debugPrint("no need to relaunch daemon.")
                            return
                        }
                    }
                }
                terminateDaemon()
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.launchDaemon()
                }
            } else {
                launchDaemon()
            }

            DispatchQueue.main.async {
                PlanetStatusViewModel.shared.daemonIsOnline = status
            }
        }
    }

    private func updateInternalPorts() {
        for p in 4001...4011 {
            if isPortOpen(port: UInt16(p)) {
                swarmPort = String(p)
                break
            }
        }
        for p in 5981...5991 {
            if isPortOpen(port: UInt16(p)) {
                apiPort = String(p)
                break
            }
        }
        for p in 18181...18191 {
            if isPortOpen(port: UInt16(p)) {
                gatewayPort = String(p)
                break
            }
        }
        guard swarmPort != "", apiPort != "", gatewayPort != "" else {
            fatalError("IPFS internal ports not ready, api port: \(apiPort), gateway port: \(gatewayPort), swarm port: \(swarmPort), abort.")
        }
        debugPrint("IPFS internal ports updated: api port: \(apiPort), gateway port: \(gatewayPort), swarm port: \(swarmPort)")
    }

    private func getInternalPortsInformationFromConfig() async -> (String?, String?) {
        let request = apiRequest(path: "config/show")
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoder = JSONDecoder()
            let config: PlanetConfig = try decoder.decode(PlanetConfig.self, from: data)
            if let api = config.addresses?.api, let gateway = config.addresses?.gateway {
                return (api, gateway)
            }
        } catch {}
        return (nil, nil)
    }

    private func isOnAppleSilicon() -> Bool {
        var systeminfo = utsname()
        uname(&systeminfo)
        let machine = withUnsafeBytes(of: &systeminfo.machine) {bufPtr->String in
            let data = Data(bufPtr)
            if let lastIndex = data.lastIndex(where: {$0 != 0}) {
                return String(data: data[0...lastIndex], encoding: .isoLatin1)!
            } else {
                return String(data: data, encoding: .isoLatin1)!
            }
        }
        if machine == "arm64" {
            return true
        }
        return false
    }

    private func _applicationSupportPath() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    }

    var basePath: URL {
        let bundleID = Bundle.main.bundleIdentifier! + ".v03"
        let path: URL
        if let p = _applicationSupportPath() {
            path = p.appendingPathComponent(bundleID, isDirectory: true)
        } else {
            path = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Planet")
        }
        if !FileManager.default.fileExists(atPath: path.path) {
            try? FileManager.default.createDirectory(at: path, withIntermediateDirectories: true, attributes: nil)
        }
        return path
    }

    func _avatarPath(forPlanetID id: UUID, isEditing: Bool = false) -> URL {
        let path = planetsPath.appendingPathComponent(id.uuidString)
        if !FileManager.default.fileExists(atPath: path.path) {
            try? FileManager.default.createDirectory(at: path, withIntermediateDirectories: true, attributes: nil)
        }
        return path.appendingPathComponent("avatar.png")
    }

    var ipfsPath: URL {
        basePath.appendingPathComponent("ipfs", isDirectory: false)
    }

    var ipfsEnvPath: URL {
        basePath.appendingPathComponent(".ipfs", isDirectory: true)
    }

    var ipfsConfigPath: URL {
        let configPath = basePath.appendingPathComponent("config", isDirectory: true)
        if !FileManager.default.fileExists(atPath: configPath.path) {
            try? FileManager.default.createDirectory(at: configPath, withIntermediateDirectories: true, attributes: nil)
        }
        return configPath
    }

    var planetsPath: URL {
        let contentPath = basePath.appendingPathComponent("planets", isDirectory: true)
        if !FileManager.default.fileExists(atPath: contentPath.path) {
            try? FileManager.default.createDirectory(at: contentPath, withIntermediateDirectories: true, attributes: nil)
        }
        return contentPath
    }

    var templatesPath: URL {
        let contentPath = basePath.appendingPathComponent("templates", isDirectory: true)
        if !FileManager.default.fileExists(atPath: contentPath.path) {
            try? FileManager.default.createDirectory(at: contentPath, withIntermediateDirectories: true, attributes: nil)
        }
        return contentPath
    }
}
