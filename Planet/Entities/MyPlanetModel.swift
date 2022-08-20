import Foundation
import SwiftUI
import SwiftyJSON
import os

class MyPlanetModel: Equatable, Hashable, Identifiable, ObservableObject, Codable {
    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "MyPlanet")

    let id: UUID
    @Published var name: String
    @Published var about: String
    let created: Date
    let ipns: String
    @Published var updated: Date
    @Published var templateName: String
    @Published var lastPublished: Date?

    @Published var plausibleEnabled: Bool? = false
    @Published var plausibleDomain: String?
    @Published var plausibleAPIKey: String?
    @Published var plausibleAPIServer: String? = "plausible.io"

    @Published var twitterUsername: String?

    @Published var githubUsername: String?

    @Published var metrics: Metrics?

    @Published var isPublishing = false
    // populated when initializing
    @Published var avatar: NSImage? = nil
    @Published var drafts: [DraftModel]! = nil
    @Published var articles: [MyArticleModel]! = nil

    static let myPlanetsPath: URL = {
        // ~/Library/Containers/xyz.planetable.Planet/Data/Documents/Planet/My/
        let url = URLUtils.repoPath.appendingPathComponent("My", isDirectory: true)
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()
    lazy var basePath = Self.myPlanetsPath.appendingPathComponent(id.uuidString, isDirectory: true)
    lazy var infoPath = basePath.appendingPathComponent("planet.json", isDirectory: false)
    lazy var articlesPath = basePath.appendingPathComponent("Articles", isDirectory: true)
    lazy var avatarPath = basePath.appendingPathComponent("avatar.png", isDirectory: false)
    lazy var draftsPath = basePath.appendingPathComponent("Drafts", isDirectory: true)
    lazy var articleDraftsPath = articlesPath.appendingPathComponent("Drafts", isDirectory: true)

    static let publicPlanetsPath: URL = {
        // ~/Library/Containers/xyz.planetable.Planet/Data/Documents/Planet/Public/
        let url = URLUtils.repoPath.appendingPathComponent("Public", isDirectory: true)
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()
    lazy var publicBasePath = Self.publicPlanetsPath.appendingPathComponent(
        id.uuidString,
        isDirectory: true
    )
    lazy var publicInfoPath = publicBasePath.appendingPathComponent(
        "planet.json",
        isDirectory: false
    )
    lazy var publicAvatarPath = publicBasePath.appendingPathComponent(
        "avatar.png",
        isDirectory: false
    )
    lazy var publicIndexPath = publicBasePath.appendingPathComponent(
        "index.html",
        isDirectory: false
    )
    lazy var publicAssetsPath = publicBasePath.appendingPathComponent("assets", isDirectory: true)

    var template: Template? {
        TemplateStore.shared[templateName]
    }
    var nameInitials: String {
        let initials = name.components(separatedBy: .whitespaces).map { $0.prefix(1).capitalized }
            .joined()
        return String(initials.prefix(2))
    }
    var browserURL: URL? {
        URL(string: "\(IPFSDaemon.publicGateways[0])/ipns/\(ipns)/")
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(about)
        hasher.combine(created)
        hasher.combine(ipns)
        hasher.combine(updated)
        hasher.combine(templateName)
        hasher.combine(lastPublished)
        hasher.combine(isPublishing)
        hasher.combine(plausibleEnabled)
        hasher.combine(plausibleDomain)
        hasher.combine(plausibleAPIKey)
        hasher.combine(plausibleAPIServer)
        hasher.combine(twitterUsername)
        hasher.combine(githubUsername)
        hasher.combine(avatar)
        hasher.combine(drafts)
        hasher.combine(articles)
    }

    static func == (lhs: MyPlanetModel, rhs: MyPlanetModel) -> Bool {
        if lhs === rhs {
            return true
        }
        if type(of: lhs) != type(of: rhs) {
            return false
        }
        return lhs.id == rhs.id
            && lhs.name == rhs.name
            && lhs.about == rhs.about
            && lhs.created == rhs.created
            && lhs.ipns == rhs.ipns
            && lhs.updated == rhs.updated
            && lhs.templateName == rhs.templateName
            && lhs.lastPublished == rhs.lastPublished
            && lhs.plausibleEnabled == rhs.plausibleEnabled
            && lhs.plausibleDomain == rhs.plausibleDomain
            && lhs.plausibleAPIKey == rhs.plausibleAPIKey
            && lhs.plausibleAPIServer == rhs.plausibleAPIServer
            && lhs.isPublishing == rhs.isPublishing
            && lhs.twitterUsername == rhs.twitterUsername
            && lhs.githubUsername == rhs.githubUsername
            && lhs.avatar == rhs.avatar
            && lhs.drafts == rhs.drafts
            && lhs.articles == rhs.articles
    }

    enum CodingKeys: String, CodingKey {
        case id, name, about, ipns, created, updated, templateName, lastPublished, plausibleEnabled,
            plausibleDomain, plausibleAPIKey, plausibleAPIServer, twitterUsername, githubUsername
    }

    // `@Published` property wrapper invalidates default decode/encode implementation
    // plus we're doing class inheritance
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        about = try container.decode(String.self, forKey: .about)
        ipns = try container.decode(String.self, forKey: .ipns)
        created = try container.decode(Date.self, forKey: .created)
        updated = try container.decode(Date.self, forKey: .updated)
        templateName = try container.decode(String.self, forKey: .templateName)
        lastPublished = try container.decodeIfPresent(Date.self, forKey: .lastPublished)
        plausibleEnabled = try container.decodeIfPresent(Bool.self, forKey: .plausibleEnabled)
        plausibleDomain = try container.decodeIfPresent(String.self, forKey: .plausibleDomain)
        plausibleAPIKey = try container.decodeIfPresent(String.self, forKey: .plausibleAPIKey)
        plausibleAPIServer = try container.decodeIfPresent(String.self, forKey: .plausibleAPIServer)
        twitterUsername = try container.decodeIfPresent(String.self, forKey: .twitterUsername)
        githubUsername = try container.decodeIfPresent(String.self, forKey: .githubUsername)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(about, forKey: .about)
        try container.encode(ipns, forKey: .ipns)
        try container.encode(created, forKey: .created)
        try container.encode(updated, forKey: .updated)
        try container.encode(templateName, forKey: .templateName)
        try container.encodeIfPresent(lastPublished, forKey: .lastPublished)
        try container.encodeIfPresent(plausibleEnabled, forKey: .plausibleEnabled)
        try container.encodeIfPresent(plausibleDomain, forKey: .plausibleDomain)
        try container.encodeIfPresent(plausibleAPIKey, forKey: .plausibleAPIKey)
        try container.encodeIfPresent(plausibleAPIServer, forKey: .plausibleAPIServer)
        try container.encodeIfPresent(twitterUsername, forKey: .twitterUsername)
        try container.encodeIfPresent(githubUsername, forKey: .githubUsername)
    }

    init(
        id: UUID,
        name: String,
        about: String,
        ipns: String,
        created: Date,
        updated: Date,
        lastPublished: Date?,
        templateName: String
    ) {
        self.id = id
        self.name = name
        self.about = about
        self.created = created
        self.ipns = ipns
        self.updated = updated
        self.lastPublished = lastPublished
        self.templateName = templateName
    }

    static func load(from directoryPath: URL) throws -> MyPlanetModel {
        guard let planetID = UUID(uuidString: directoryPath.lastPathComponent) else {
            // directory name is not a UUID
            throw PlanetError.PersistenceError
        }
        let planetPath = directoryPath.appendingPathComponent("planet.json", isDirectory: false)
        let planetData = try Data(contentsOf: planetPath)
        let planet = try JSONDecoder.shared.decode(MyPlanetModel.self, from: planetData)
        guard planet.id == planetID else {
            // directory UUID does not match planet json UUID
            throw PlanetError.PersistenceError
        }

        planet.avatar = NSImage(contentsOf: planet.avatarPath)

        let draftDirectories = try FileManager.default.contentsOfDirectory(
            at: planet.draftsPath,
            includingPropertiesForKeys: nil
        ).filter { $0.hasDirectoryPath }
        planet.drafts = draftDirectories.compactMap {
            try? DraftModel.load(from: $0, planet: planet)
        }

        let articleDirectory = directoryPath.appendingPathComponent("Articles", isDirectory: true)
        let articleFiles = try FileManager.default.contentsOfDirectory(
            at: articleDirectory,
            includingPropertiesForKeys: nil
        )
        let articles = articleFiles.compactMap {
            try? MyArticleModel.load(from: $0, planet: planet)
        }
        planet.articles = articles.sorted {
            $0.created > $1.created
        }
        return planet
    }

    static func create(name: String, about: String, templateName: String) async throws
        -> MyPlanetModel
    {
        let id = UUID()
        let ipns = try await IPFSDaemon.shared.generateKey(name: id.uuidString)
        let now = Date()
        let planet = MyPlanetModel(
            id: id,
            name: name,
            about: about,
            ipns: ipns,
            created: now,
            updated: now,
            lastPublished: nil,
            templateName: templateName
        )
        planet.avatar = nil
        planet.drafts = []
        planet.articles = []
        try FileManager.default.createDirectory(
            at: planet.basePath,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: planet.articlesPath,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: planet.draftsPath,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: planet.articleDraftsPath,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: planet.publicBasePath,
            withIntermediateDirectories: true
        )
        try planet.copyTemplateAssets()
        return planet
    }

    @MainActor static func importBackup(from path: URL) throws -> MyPlanetModel {
        Self.logger.info("Importing backup from \(path)")
        let backupInfoPath = path.appendingPathComponent("planet.json", isDirectory: false)
        let backupAssetsPath = path.appendingPathComponent("assets", isDirectory: true)
        let backupIndexPath = path.appendingPathComponent("index.html", isDirectory: false)
        let backupPrivateKeyPath = path.appendingPathComponent("planet.key", isDirectory: false)
        let backupAvatarPath = path.appendingPathComponent("avatar.png", isDirectory: false)

        guard FileManager.default.fileExists(atPath: backupInfoPath.path),
            FileManager.default.fileExists(atPath: backupPrivateKeyPath.path)
        else {
            Self.logger.info("Planet backup is missing private key for publishing IPNS, abort")
            throw PlanetError.ImportPlanetError
        }

        let decoder = JSONDecoder()
        guard let data = try? Data.init(contentsOf: backupInfoPath),
            let backupPlanet = try? decoder.decode(BackupMyPlanetModel.self, from: data)
        else {
            throw PlanetError.ImportPlanetError
        }
        Self.logger.info("Loaded backup planet info with id \(backupPlanet.id)")

        if PlanetStore.shared.myPlanets.contains(where: { $0.id == backupPlanet.id }) {
            Self.logger.info("Planet with id \(backupPlanet.id) already exists, abort")
            throw PlanetError.PlanetExistsError
        }

        do {
            // key may already exist in IPFS keystore, ignore error
            try IPFSCommand.importKey(
                name: backupPlanet.id.uuidString,
                target: backupPrivateKeyPath
            ).run()
        }
        catch {
            throw PlanetError.IPFSError
        }

        let planet = MyPlanetModel(
            id: backupPlanet.id,
            name: backupPlanet.name,
            about: backupPlanet.about,
            ipns: backupPlanet.ipns,
            created: backupPlanet.created,
            updated: backupPlanet.updated,
            lastPublished: backupPlanet.lastPublished,
            templateName: backupPlanet.templateName
        )

        // delete existing planet files if exists
        // it is important we validate that the planet does not exist, or we override an existing planet with a stale backup
        if FileManager.default.fileExists(atPath: planet.publicBasePath.path) {
            try FileManager.default.removeItem(at: planet.publicBasePath)
        }
        Self.logger.info("Copying assets from backup planet \(backupPlanet.id)")
        do {
            try FileManager.default.createDirectory(
                at: planet.publicBasePath,
                withIntermediateDirectories: true
            )
            if FileManager.default.fileExists(atPath: backupAssetsPath.path) {
                try FileManager.default.copyItem(at: backupAssetsPath, to: planet.publicAssetsPath)
            }
            if FileManager.default.fileExists(atPath: backupIndexPath.path) {
                try FileManager.default.copyItem(at: backupIndexPath, to: planet.publicIndexPath)
            }
            if FileManager.default.fileExists(atPath: backupAvatarPath.path) {
                try FileManager.default.copyItem(at: backupAvatarPath, to: planet.publicAvatarPath)
            }
        }
        catch {
            throw PlanetError.ImportPlanetError
        }
        Self.logger.info("Assets copied from backup planet \(backupPlanet.id)")

        planet.avatar = NSImage(contentsOf: planet.avatarPath)
        planet.drafts = []
        Self.logger.info(
            "Found \(backupPlanet.articles.count) backup articles from backup planet \(backupPlanet.id)"
        )
        planet.articles = backupPlanet.articles.compactMap { backupArticle in
            let backupArticlePath = path.appendingPathComponent(
                backupArticle.link,
                isDirectory: true
            )
            if FileManager.default.fileExists(atPath: backupArticlePath.path) {
                let article = MyArticleModel(
                    id: backupArticle.id,
                    link: backupArticle.link,
                    title: backupArticle.title,
                    content: backupArticle.content,
                    summary: backupArticle.summary,
                    created: backupArticle.created,
                    starred: nil,
                    videoFilename: backupArticle.videoFilename,
                    audioFilename: backupArticle.audioFilename,
                    attachments: backupArticle.attachments
                )
                article.planet = planet
                do {
                    try FileManager.default.copyItem(
                        at: backupArticlePath,
                        to: article.publicBasePath
                    )
                    return article
                }
                catch {
                }
            }
            return nil
        }
        Self.logger.info(
            "Regenerated \(planet.articles.count) articles from backup articles for backup planet \(backupPlanet.id)"
        )

        try FileManager.default.createDirectory(
            at: planet.basePath,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: planet.articlesPath,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: planet.draftsPath,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: planet.articleDraftsPath,
            withIntermediateDirectories: true
        )

        if FileManager.default.fileExists(atPath: backupAvatarPath.path) {
            try FileManager.default.copyItem(at: backupAvatarPath, to: planet.avatarPath)
        }
        planet.avatar = NSImage(contentsOf: planet.avatarPath)

        Self.logger.info("Saving imported planet \(planet.id)")
        try planet.save()
        try planet.articles.forEach { try $0.save() }
        return planet
    }

    func updateAvatar(path: URL) throws {
        guard let image = NSImage(contentsOf: path),
            let resizedImage = image.resizeSquare(maxLength: 144),
            let data = resizedImage.PNGData
        else {
            throw PlanetError.AvatarError
        }
        try data.write(to: avatarPath)
        try data.write(to: publicAvatarPath)
        avatar = resizedImage
    }

    func removeAvatar() throws {
        try FileManager.default.removeItem(at: avatarPath)
        try FileManager.default.removeItem(at: publicAvatarPath)
        avatar = nil
    }

    func copyTemplateAssets() throws {
        guard let template = template else {
            throw PlanetError.MissingTemplateError
        }
        if FileManager.default.fileExists(atPath: publicAssetsPath.path) {
            try FileManager.default.removeItem(at: publicAssetsPath)
        }
        try FileManager.default.copyItem(at: template.assetsPath, to: publicAssetsPath)
    }

    func savePublic() throws {
        guard let template = template else {
            throw PlanetError.MissingTemplateError
        }
        let publicArticles = articles.map { $0.publicArticle }
        let publicPlanet = PublicPlanetModel(
            id: id,
            name: name,
            about: about,
            ipns: ipns,
            created: created,
            updated: updated,
            articles: publicArticles,
            plausibleEnabled: plausibleEnabled,
            plausibleDomain: plausibleDomain,
            plausibleAPIServer: plausibleAPIServer,
            twitterUsername: twitterUsername,
            githubUsername: githubUsername
        )
        let hasAvatar = FileManager.default.fileExists(atPath: publicAvatarPath.path)
        var context: [String: Any] = [
            "planet": publicPlanet,
            "has_avatar": hasAvatar,
        ]
        let indexHTML = try template.renderIndex(context: context)
        try indexHTML.data(using: .utf8)?.write(to: publicIndexPath)

        let info = try JSONEncoder.shared.encode(publicPlanet)
        try info.write(to: publicInfoPath)
    }

    func publish() async throws {
        await MainActor.run {
            self.isPublishing = true
        }
        defer {
            Task { @MainActor in
                self.isPublishing = false
            }
        }
        let cid = try await IPFSDaemon.shared.addDirectory(url: publicBasePath)
        let result = try await IPFSDaemon.shared.api(
            path: "name/publish",
            args: [
                "arg": cid,
                "allow-offline": "1",
                "key": id.uuidString,
                "quieter": "1",
                "lifetime": "7200h",
            ],
            timeout: 600
        )
        let published = try JSONDecoder.shared.decode(IPFSPublished.self, from: result)
        Self.logger.info("Published planet \(self.id) to \(published.name)")
        Task { @MainActor in
            self.lastPublished = Date()
        }
        try save()
    }

    func exportBackup(to directory: URL) throws {
        let exportPath = directory.appendingPathComponent(
            "\(name.sanitized()).planet",
            isDirectory: true
        )
        guard !FileManager.default.fileExists(atPath: exportPath.path) else {
            throw PlanetError.FileExistsError
        }

        let backupPlanet = BackupMyPlanetModel(
            id: id,
            name: name,
            about: about,
            ipns: ipns,
            created: created,
            updated: updated,
            lastPublished: lastPublished,
            templateName: templateName,
            plausibleEnabled: plausibleEnabled,
            plausibleDomain: plausibleDomain,
            plausibleAPIKey: plausibleAPIKey,
            plausibleAPIServer: plausibleAPIServer,
            twitterUsername: twitterUsername,
            githubUsername: githubUsername,
            articles: articles.map {
                BackupArticleModel(
                    id: $0.id,
                    link: $0.link,
                    title: $0.title,
                    content: $0.content,
                    summary: $0.summary,
                    created: $0.created,
                    videoFilename: $0.videoFilename,
                    audioFilename: $0.audioFilename,
                    attachments: $0.attachments
                )
            }
        )
        do {
            try FileManager.default.copyItem(at: publicBasePath, to: exportPath)

            // export private key from IPFS keystore
            let exportPrivateKeyPath = exportPath.appendingPathComponent(
                "planet.key",
                isDirectory: false
            )
            let (ret, _, _) = try IPFSCommand.exportKey(
                name: id.uuidString,
                target: exportPrivateKeyPath
            ).run()
            if ret != 0 {
                throw PlanetError.IPFSError
            }

            // override public planet info with backup planet info
            let backupPlanetInfoPath = exportPath.appendingPathComponent(
                "planet.json",
                isDirectory: false
            )
            let backupPlanet = try JSONEncoder.shared.encode(backupPlanet)
            try backupPlanet.write(to: backupPlanetInfoPath)
        }
        catch {
            throw PlanetError.ExportPlanetError
        }

        NSWorkspace.shared.activateFileViewerSelecting([exportPath])
    }

    func save() throws {
        try JSONEncoder.shared.encode(self).write(to: infoPath)
    }

    func delete() throws {
        try FileManager.default.removeItem(at: basePath)
        // try FileManager.default.removeItem(at: publicBasePath)
    }

    func updateTrafficAnalytics() async {
        if let domain = plausibleDomain, let apiKey = plausibleAPIKey, domain.count > 0,
            apiKey.count > 0
        {
            let apiServer = plausibleAPIServer ?? "plausible.io"
            let analytics = PlausibleAnalytics(domain: domain, apiKey: apiKey, apiServer: apiServer)
            await analytics.updateTrafficAnalytics(for: self)
        }
    }
}

struct PlausibleAnalytics {
    let domain: String
    let apiKey: String
    let apiServer: String

    func updateTrafficAnalytics(for planet: MyPlanetModel) async {
        let url = URL(
            string:
                "https://\(apiServer)/api/v1/stats/aggregate?site_id=\(domain)&period=day&metrics=visitors,pageviews"
        )!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        guard let (data, response) = try? await URLSession.shared.data(for: request) else {
            return
        }
        do {
            let jsonString = String(data: data, encoding: .utf8)
            debugPrint("Data: \(jsonString)")
            let json = try JSON(data: data)
            debugPrint("SwiftyJSON: \(json)")
            if let visitors = json["results"]["visitors"]["value"].int,
                let pageviews = json["results"]["pageviews"]["value"].int
            {
                if planet.metrics == nil {
                    Task { @MainActor in
                        planet.metrics = Metrics(
                            visitorsToday: visitors,
                            pageviewsToday: pageviews
                        )
                    }
                }
                else {
                    Task { @MainActor in
                        planet.metrics?.visitorsToday = visitors
                        planet.metrics?.pageviewsToday = pageviews
                    }
                }
            }
        }
        catch {
            debugPrint(
                "Plausible: error occurred when fetching analytics for \(planet.name) \(error)"
            )
        }
    }
}

struct Metrics: Codable {
    var visitorsToday: Int
    var pageviewsToday: Int
}

struct PublicPlanetModel: Codable {
    let id: UUID
    let name: String
    let about: String
    let ipns: String
    let created: Date
    let updated: Date
    let articles: [PublicArticleModel]
    let plausibleEnabled: Bool?
    let plausibleDomain: String?
    let plausibleAPIServer: String?
    let twitterUsername: String?
    let githubUsername: String?
}

struct BackupMyPlanetModel: Codable {
    let id: UUID
    let name: String
    let about: String
    let ipns: String
    let created: Date
    let updated: Date
    let lastPublished: Date?
    let templateName: String
    let plausibleEnabled: Bool?
    let plausibleDomain: String?
    let plausibleAPIKey: String?
    let plausibleAPIServer: String?
    let twitterUsername: String?
    let githubUsername: String?
    let articles: [BackupArticleModel]
}
