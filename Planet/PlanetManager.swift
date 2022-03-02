//
//  PlanetManager.swift
//  Planet
//
//  Created by Kai on 2/15/22.
//

import Foundation
import Cocoa
import Stencil
import PathKit
import Ink


class PlanetManager: NSObject {
    static let shared: PlanetManager = PlanetManager()
    
    private var publishTimer: Timer?
    private var feedTimer: Timer?
    private var statusTimer: Timer?

    private var unitTesting: Bool = {
        return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
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
    
    private var apiPort: String = "" {
        didSet {
            guard apiPort != "" else { return }
            debugPrint("api port updated.")
            commandQueue.addOperation {
                do {
                    // update api port.
                    let result = try runCommand(command: .ipfsUpdateAPIPort(target: self._ipfsPath(), config: self._configPath(), port: self.apiPort))
                    debugPrint("update api port command result: \(result)")
                } catch {
                    debugPrint("failed to update api port: \(error)")
                }
            }
        }
    }
    
    private var gatewayPort: String = "" {
        didSet {
            guard gatewayPort != "" else { return }
            debugPrint("gateway port updated.")
            commandQueue.addOperation {
                do {
                    // update gateway port.
                    let result = try runCommand(command: .ipfsUpdateGatewayPort(target: self._ipfsPath(), config: self._configPath(), port: self.gatewayPort))
                    debugPrint("update gateway port command result: \(result)")
                } catch {
                    debugPrint("failed to update gateway port: \(error)")
                }
            }
        }
    }
    
    private var swarmPort: String = "" {
        didSet {
            guard swarmPort != "" else { return }
            debugPrint("swarm port updated.")
            commandQueue.addOperation {
                do {
                    // update swarm port
                    let result = try runCommand(command: .ipfsUpdateSwarmPort(target: self._ipfsPath(), config: self._configPath(), port: self.swarmPort))
                    debugPrint("update swarm port command result: \(result)")
                } catch {
                    debugPrint("failed to update swarm port: \(error)")
                }
            }
        }
    }

    func setup() {
        debugPrint("Planet Manager Setup")
        loadTemplates()
        
        publishTimer = Timer.scheduledTimer(timeInterval: 600, target: self, selector: #selector(publishLocalPlanets), userInfo: nil, repeats: true)
        feedTimer = Timer.scheduledTimer(timeInterval: 300, target: self, selector: #selector(updateFollowingPlanets), userInfo: nil, repeats: true)
        statusTimer = Timer .scheduledTimer(timeInterval: 5, target: self, selector: #selector(updatePlanetStatus), userInfo: nil, repeats: true)
        
        Task.init(priority: .utility) {
            guard await verifyIPFSOnlineStatus() else { return }
            await updateInternalPorts()
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
        let templatePath = _templatesPath()
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
            DispatchQueue.main.async {
                PlanetStore.shared.templatePaths.append(targetPath)
            }
        }
    }
    
    func checkDaemonStatus() async -> Bool {
        guard apiPort != "" else { return false }
        let status = await verifyPortOnlineStatus(port: apiPort, suffix: "/webui")
        DispatchQueue.main.async {
            PlanetStore.shared.daemonIsOnline = status
        }
        return status
    }

    func checkPeersStatus() async -> Int {
        guard await PlanetStore.shared.daemonIsOnline else { return 0}
        let request = serverURL(path: "swarm/peers")
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoder = JSONDecoder()
            let peers = try decoder.decode(PlanetPeers.self, from: data)
            DispatchQueue.main.async {
                PlanetStore.shared.peersCount = peers.peers?.count ?? 0
            }
        } catch {}
        return 0
    }
    
    func checkPublishingStatus(planetID id: UUID) async -> Bool {
        return await PlanetStore.shared.publishingPlanets.contains(id)
    }
    
    func checkUpdatingStatus(planetID id: UUID) async -> Bool {
        return await PlanetStore.shared.updatingPlanets.contains(id)
    }
    
    func generateKeys() async -> (keyName: String?, keyID: String?) {
        let uuid = UUID()
        let checkKeyExistsRequest = serverURL(path: "key/list")
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
                    let generateKeyRequest = serverURL(path: "key/gen", args: ["arg": uuid.uuidString])
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
        let envPath = _ipfsENVPath()
        if !FileManager.default.fileExists(atPath: envPath.path) {
            try? FileManager.default.createDirectory(at: envPath, withIntermediateDirectories: true, attributes: nil)
        }
        return envPath
    }
    
    func ipfsVersion() async -> String {
        let checkKeyExistsRequest = serverURL(path: "version")
        do {
            let (data, _) = try await URLSession.shared.data(for: checkKeyExistsRequest)
            let decoder = JSONDecoder()
            let info: PlanetIPFSVersionInfo = try decoder.decode(PlanetIPFSVersionInfo.self, from: data)
            debugPrint("got ipfs version: \(info)")
            if let version = info.version, let system = info.system {
                return version + " " + system
            }
        } catch {
            debugPrint("failed to get ipfs version, error: \(error)")
        }
        return "0.12.0"
    }
    
    func deleteKey(withName name: String) async {
        let checkKeyExistsRequest = serverURL(path: "key/rm", args: ["arg": name])
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
    func setupDirectory(forPlanet planet: Planet) {
        if !planet.isMyPlanet() {
            Task.init(priority: .background) {
                await updateForPlanet(planet: planet)
            }
        } else {
            debugPrint("about setup directory for planet: \(planet) ...")
            let planetPath = _planetsPath().appendingPathComponent(planet.id!.uuidString)
            if !FileManager.default.fileExists(atPath: planetPath.path) {
                debugPrint("setup directory for planet: \(planet), path: \(planetPath)")
                do {
                    try FileManager.default.createDirectory(at: planetPath, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    debugPrint("failed to create planet path at \(planetPath), error: \(error)")
                    return
                }
            }
        }
    }
    
    func destroyDirectory(fromPlanet planetUUID: UUID) {
        debugPrint("about to destroy directory from planet: \(planetUUID) ...")
        let planetPath = _planetsPath().appendingPathComponent(planetUUID.uuidString)
        do {
            try FileManager.default.removeItem(at: planetPath)
        } catch {
            debugPrint("failed to destroy planet path at: \(planetPath), error: \(error)")
        }
    }
    
    func destroyArticleDirectory(planetUUID: UUID, articleUUID: UUID) {
        debugPrint("about to destroy directory from article: \(articleUUID) ...")
        let articlePath = _planetsPath().appendingPathComponent(planetUUID.uuidString).appendingPathComponent(articleUUID.uuidString)
        do {
            try FileManager.default.removeItem(at: articlePath)
        } catch {
            debugPrint("failed to destroy article path at: \(articlePath), error: \(error)")
        }
    }
    
    func articleURL(article: PlanetArticle) async -> URL? {
        guard let articleID = article.id, let planetID = article.planetID else { return nil }
        guard let planet = PlanetDataController.shared.getPlanet(id: article.planetID!), let ipns = planet.ipns else { return nil }
        if planet.isMyPlanet() {
            let articlePath = _planetsPath().appendingPathComponent(planetID.uuidString).appendingPathComponent(articleID.uuidString).appendingPathComponent("index.html")
            if !FileManager.default.fileExists(atPath: articlePath.path) {
                Task.init(priority: .background) {
                    PlanetDataController.shared.removeArticle(article: article)
                }
                return nil
            }
            return articlePath
        } else {
            let prefixString = "http://127.0.0.1" + ":" + gatewayPort + "/" + "ipns" + "/" + ipns
            let urlString: String = prefixString + "/" + articleID.uuidString + "/" + "index.html"
            if let url = URL(string: urlString) {
                let request = URLRequest(url: url, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: 15)
                do {
                    let (data, _) = try await URLSession.shared.data(for: request)
                    // cache index.html file if needed.
                    return url
                } catch {
                    debugPrint("failed to validate article url: \(url), error: \(error)")
                    return nil
                }
            }
            return nil
        }
    }
    
    func renderArticleToDirectory(fromArticle article: PlanetArticle, templateIndex: Int = 0, force: Bool = false) async {
        debugPrint("about to render article: \(article)")
        let planetPath = _planetsPath().appendingPathComponent(article.planetID!.uuidString)
        let articlePath = planetPath.appendingPathComponent(article.id!.uuidString)
        if !FileManager.default.fileExists(atPath: articlePath.path) {
            do {
                try FileManager.default.createDirectory(at: articlePath, withIntermediateDirectories: true, attributes: nil)
            } catch {
                debugPrint("failed to create article path: \(articlePath), error: \(error)")
                return
            }
        }
        let templatePath = await PlanetStore.shared.templatePaths[templateIndex]
        // render html
        let loader = FileSystemLoader(paths: [Path(templatePath.deletingLastPathComponent().path)])
        let environment = Environment(loader: loader)
        let parser = MarkdownParser()
        let result = parser.parse(article.content!)
        let content_html = result.html
        var context: [String: Any]
        context = ["article": article, "content_html": content_html]
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
        debugPrint("article \(article) rendered at: \(articlePath).")
    }
    
    func publishForPlanet(planet: Planet) async {
        guard let id = planet.id, let keyName = planet.keyName, keyName != "" else { return }
        let now = Date()
        let planetPath = _planetsPath().appendingPathComponent(id.uuidString)
        guard FileManager.default.fileExists(atPath: planetPath.path) else { return }
        let publishingStatus = await checkPublishingStatus(planetID: id)
        guard publishingStatus == false else {
            debugPrint("planet \(planet) is still publishing, abort.")
            return
        }
        DispatchQueue.main.async {
            PlanetStore.shared.publishingPlanets.insert(id)
        }
        defer {
            DispatchQueue.main.async {
                PlanetStore.shared.publishingPlanets.remove(id)
                let published: Date = Date()
                PlanetStore.shared.lastPublishedDates[id] = published
                DispatchQueue.global(qos: .background).async {
                    UserDefaults.standard.set(published, forKey: "PlanetLastPublished" + "-" + id.uuidString)
                }
            }
        }
        debugPrint("publishing for planet: \(planet), with key name: \(keyName) ...")
        
        // update feed.json
        let feedPath = planetPath.appendingPathComponent("feed.json")
        if FileManager.default.fileExists(atPath: feedPath.path) {
            do {
                try FileManager.default.removeItem(at: feedPath)
            } catch {
                debugPrint("failed to remove previous feed item at \(feedPath), error: \(error)")
            }
        }
        let articles = PlanetDataController.shared.getArticles(byPlanetID: id)
        let feedArticles: [PlanetFeedArticle] = articles.map() { t in
            let feedArticle: PlanetFeedArticle = PlanetFeedArticle(id: t.id!, created: t.created!, title: t.title ?? "")
            return feedArticle
        }
        let feed = PlanetFeed(id: id, ipns: planet.ipns!, created: planet.created!, updated: now, name: planet.name ?? "", about: planet.about ?? "", articles: feedArticles)
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
            let result = try runCommand(command: .ipfsAddDirectory(target: _ipfsPath(), config: _configPath(), directory: planetPath))
            if let result = result["result"] as? [String], let cid: String = result.first {
                planetCID = cid
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
            let (data, _) = try await URLSession.shared.data(for: serverURL(path: "name/publish", args: [
                "arg": planetCID!,
                "allow-offline": "1",
                "key": keyName,
                "quieter": "1"
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
    }
    
    func updateForPlanet(planet: Planet) async {
        guard let id = planet.id, let name = planet.name, let ipns = planet.ipns, ipns.count == "k51qzi5uqu5dioq5on1s4oc3wg2t13w03xxsq32b1qovi61b6oi8pcyep2gsyf".count else { return }
        
        // make sure you do not follow your own planet on the same Mac.
        guard !PlanetDataController.shared.getLocalIPNSs().contains(ipns) else {
            debugPrint("cannot follow your own planet on the same machine, abort.")
            PlanetDataController.shared.removePlanet(planet: planet)
            return
        }
        
        let updatingStatus = await checkUpdatingStatus(planetID: id)
        guard updatingStatus == false else {
            debugPrint("planet \(planet) is still been updating, abort.")
            return
        }
        DispatchQueue.main.async {
            PlanetStore.shared.updatingPlanets.insert(id)
        }
        defer {
            DispatchQueue.main.async {
                PlanetStore.shared.updatingPlanets.remove(id)
                let updated: Date = Date()
                PlanetStore.shared.lastUpdatedDates[id] = updated
                DispatchQueue.global(qos: .background).async {
                    UserDefaults.standard.set(updated, forKey: "PlanetLastUpdated" + "-" + id.uuidString)
                }
            }
        }
        
        // pin planet in background.
        debugPrint("pin in the background ...")
        let pinRequest = serverURL(path: "pin/add", args: ["arg": "/ipns/" + ipns], timeout: 120)
        URLSession.shared.dataTask(with: pinRequest) { data, response, error in
            debugPrint("pinned: \(response).")
        }.resume()

        debugPrint("updating for planet: \(planet) ...")
        let prefix = "http://127.0.0.1" + ":" + gatewayPort + "/" + "ipns" + "/" + ipns + "/"
        let ipnsString = prefix + "feed.json"
        let request = URLRequest(url: URL(string: ipnsString)!, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoder = JSONDecoder()
            let feed: PlanetFeed = try decoder.decode(PlanetFeed.self, from: data)
            guard feed.name != "" else { return }
            
            debugPrint("got following planet feed: \(feed)")
            
            // remove current planet as placeholder, create new planet with feed.id
            if name == "" {
                PlanetDataController.shared.removePlanet(planet: planet)
                PlanetDataController.shared.createPlanet(withID: feed.id, name: feed.name, about: feed.about, keyName: nil, keyID: nil, ipns: feed.ipns)
            }
            
            // update planet articles if needed.
            for a in feed.articles {
                if let _ = PlanetDataController.shared.getArticle(id: a.id) {
                } else {
                    await PlanetDataController.shared.createArticle(withID: a.id, forPlanet: feed.id, title: a.title, content: "")
                }
            }
            
            // MARK: TODO: delete saved articles which was deleted if needed.
            
            // update planet avatar if needed.
            let avatarString = prefix + "/" + "avatar.png"
            let avatarRequest = URLRequest(url: URL(string: avatarString)!, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
            let (avatarData, _) = try await URLSession.shared.data(for: avatarRequest)
            let planetPath = _planetsPath().appendingPathComponent(id.uuidString)
            if !FileManager.default.fileExists(atPath: planetPath.path) {
                try FileManager.default.createDirectory(at: planetPath, withIntermediateDirectories: true, attributes: nil)
            }
            let avatarPath = planetPath.appendingPathComponent("avatar.png")
            if FileManager.default.fileExists(atPath: avatarPath.path) {
                try FileManager.default.removeItem(at: avatarPath)
            }
            NSImage(data: avatarData)?.imageSave(avatarPath)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .updateAvatar, object: nil)
            }
        } catch {
            debugPrint("failed to get feed: \(error)")
        }
        
        debugPrint("done updating.")
    }
    
    @objc
    func publishLocalPlanets() {
        Task.init(priority: .background) {
            guard await checkDaemonStatus() else { return }
            let planets = PlanetDataController.shared.getLocalPlanets()
            debugPrint("publishing local planets: \(planets) ...")
            for p in planets {
                await publishForPlanet(planet: p)
            }
        }
    }
    
    @objc
    func updateFollowingPlanets() {
        Task.init(priority: .background) {
            guard await checkDaemonStatus() else { return }
            let planets = PlanetDataController.shared.getFollowingPlanets()
            debugPrint("updating following planets: \(planets) ...")
            for p in planets {
                await updateForPlanet(planet: p)
            }
        }
    }
    
    @objc
    func updatePlanetStatus() {
        Task.init(priority: .background) {
            await checkDaemonStatus()
        }
        Task.init(priority: .background) {
            await checkPeersStatus()
        }
    }

    // MARK: - Private -
    private func verifyIPFSOnlineStatus() async -> Bool {
        let targetPath = _ipfsPath()
        let configPath = _configPath()
        if FileManager.default.fileExists(atPath: targetPath.path) && FileManager.default.fileExists(atPath: configPath.path) {
            do {
                let lists = try FileManager.default.contentsOfDirectory(atPath: configPath.path)
                if lists.count >= 6 {
                    let result = try runCommand(command: .ipfsGetID(target: targetPath, config: configPath))
                    debugPrint("init command result: \(result)")
                    debugPrint("command status: ready.")
                    return true
                }
            } catch {}
        } else {
            let binaryDataName: String = isOnAppleSilicon() ? "IPFS-GO-ARM" : "IPFS-GO"
            if let data = NSDataAsset(name: NSDataAsset.Name(binaryDataName)) {
                do {
                    try data.data.write(to: targetPath, options: .atomic)
                    try FileManager.default.setAttributes([.posixPermissions: 755], ofItemAtPath: targetPath.path)
                    var result = try runCommand(command: .ipfsInit(target: targetPath, config: configPath))
                    debugPrint("init command result: \(result)")
                    result = try runCommand(command: .ipfsGetID(target: targetPath, config: configPath))
                    debugPrint("id command result: \(result)")
                    debugPrint("command status: ready.")
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
    
    private func verifyPortOnlineStatus(port: String, suffix: String = "/") async -> Bool {
        let url = URL(string: "http://127.0.0.1:" + port + suffix)!
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 5)
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let res = response as? HTTPURLResponse, res.statusCode == 200 {
                return true
            }
        } catch {}
        return false
    }
    
    private func serverURL(path: String, args: [String: String] = [:], timeout: TimeInterval = 5) -> URLRequest {
        var urlPath: String = "http://127.0.0.1" + ":" + apiPort + "/" + "api" + "/" + "v0"
        urlPath += "/" + path
        var url: URL = URL(string: urlPath)!
        if args != [:] {
            url = url.appendingQueryParameters(args)
        }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: timeout)
        request.httpMethod = "POST"
        return request
    }
    
    private func terminateDaemon(forceSkip: Bool = false) {
        let request = serverURL(path: "shutdown")
        URLSession.shared.dataTask(with: request) { data, response, error in
        }.resume()
    }
    
    private func launchDaemon() {
        Task.init(priority: .utility) {
            guard await checkDaemonStatus() == false else { return }
            commandDaemonQueue.addOperation {
                do {
                    let _ = try runCommand(command: .ipfsLaunchDaemon(target: self._ipfsPath(), config: self._configPath()))
                } catch {
                    debugPrint("failed to launch daemon: \(error). will try to start daemon again after 3 seconds.")
                    let _ = try? runCommand(command: .ipfsTerminateDaemon(target: self._ipfsPath(), config: self._configPath()))
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                Task.init(priority: .utility) {
                    let s = await self.checkDaemonStatus()
                    DispatchQueue.main.async {
                        PlanetStore.shared.daemonIsOnline = s
                    }
                    if !s {
                        DispatchQueue.global().async {
                            self.launchDaemon()
                        }
                    } else {
                        DispatchQueue.global(qos: .background).async {
                            self.publishLocalPlanets()
                            self.updateFollowingPlanets()
                        }
                        let version = await self.ipfsVersion()
                        DispatchQueue.main.async {
                            PlanetStore.shared.currentPlanetVersion = version
                        }
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
                PlanetStore.shared.daemonIsOnline = status
            }
        }
    }

    private func updateInternalPorts() async {
        debugPrint("updating internal ports ...")
        debugPrint("updating swarm port in range(4001, 4011) ...")
        for p in 4001...4011 {
            if await verifyPortAvailability(port: String(p)) {
                swarmPort = String(p)
                break
            }
        }
        debugPrint("updating api port in range(5981, 5991) ...")
        for p in 5981...5991 {
            if await verifyPortAvailability(port: String(p)) {
                apiPort = String(p)
                break
            }
        }
        debugPrint("updating gateway port in range(18181, 18191) ...")
        for p in 18181...18191 {
            if await verifyPortAvailability(port: String(p)) {
                gatewayPort = String(p)
                break
            }
        }
        debugPrint("internal ports updated: api \(apiPort), gateway \(gatewayPort), swarm \(swarmPort)")
    }
    
    private func getInternalPortsInformationFromConfig() async -> (String?, String?) {
        let request = serverURL(path: "config/show")
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
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    }

    private func _basePath() -> URL {
#if DEBUG
        let bundleID = Bundle.main.bundleIdentifier! + ".v03"
#else
        let bundleID = Bundle.main.bundleIdentifier! + ".v03"
#endif
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
        let path = _planetsPath().appendingPathComponent(id.uuidString)
        if !FileManager.default.fileExists(atPath: path.path) {
            try? FileManager.default.createDirectory(at: path, withIntermediateDirectories: true, attributes: nil)
        }
        return path.appendingPathComponent("avatar.png")
    }

    private func _ipfsPath() -> URL {
        let ipfsPath = _basePath().appendingPathComponent("ipfs", isDirectory: false)
        return ipfsPath
    }
    
    private func _ipfsENVPath() -> URL {
        let envPath = _basePath().appendingPathComponent(".ipfs", isDirectory: true)
        return envPath
    }
    
    private func _configPath() -> URL {
        let configPath = _basePath().appendingPathComponent("config", isDirectory: true)
        if !FileManager.default.fileExists(atPath: configPath.path) {
            try? FileManager.default.createDirectory(at: configPath, withIntermediateDirectories: true, attributes: nil)
        }
        return configPath
    }
    
    private func _planetsPath() -> URL {
        let contentPath = _basePath().appendingPathComponent("planets", isDirectory: true)
        if !FileManager.default.fileExists(atPath: contentPath.path) {
            try? FileManager.default.createDirectory(at: contentPath, withIntermediateDirectories: true, attributes: nil)
        }
        return contentPath
    }

    private func _templatesPath() -> URL {
        let contentPath = _basePath().appendingPathComponent("templates", isDirectory: true)
        if !FileManager.default.fileExists(atPath: contentPath.path) {
            try? FileManager.default.createDirectory(at: contentPath, withIntermediateDirectories: true, attributes: nil)
        }
        return contentPath
    }
}
