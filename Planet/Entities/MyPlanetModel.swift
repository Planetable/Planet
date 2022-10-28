import Foundation
import Stencil
import SwiftUI
import SwiftyJSON
import os

class MyPlanetModel: Equatable, Hashable, Identifiable, ObservableObject, Codable {
    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "MyPlanet")

    let id: UUID
    @Published var name: String
    @Published var about: String
    @Published var domain: String?
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
    @Published var telegramUsername: String?

    @Published var dWebServicesEnabled: Bool? = false
    @Published var dWebServicesDomain: String?
    @Published var dWebServicesAPIKey: String?

    @Published var filebaseEnabled: Bool? = false
    @Published var filebasePinName: String?
    @Published var filebaseAPIToken: String?
    @Published var filebaseRequestID: String?
    @Published var filebasePinCID: String?
    @Published var filebasePinStatus: String?
    @Published var filebasePinStatusRetrieved: Date?

    @Published var customCodeHeadEnabled: Bool? = false
    @Published var customCodeHead: String?
    @Published var customCodeBodyStartEnabled: Bool? = false
    @Published var customCodeBodyStart: String?
    @Published var customCodeBodyEndEnabled: Bool? = false
    @Published var customCodeBodyEnd: String?

    @Published var podcastCategories: [String: [String]]? = [:]
    @Published var podcastLanguage: String? = "en"
    @Published var podcastExplicit: Bool? = false

    @Published var metrics: Metrics?

    @Published var isPublishing = false
    // populated when initializing

    @Published var avatar: NSImage? = nil
    @Published var podcastCoverArt: NSImage? = nil

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
    lazy var faviconPath = basePath.appendingPathComponent("favicon.ico", isDirectory: false)
    lazy var podcastCoverArtPath = basePath.appendingPathComponent("podcastCoverArt.png", isDirectory: false)

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
    lazy var publicFaviconPath = publicBasePath.appendingPathComponent(
        "favicon.ico",
        isDirectory: false
    )
    lazy var publicPodcastCoverArtPath = publicBasePath.appendingPathComponent(
        "podcastCoverArt.png",
        isDirectory: false
    )

    lazy var publicIndexPath = publicBasePath.appendingPathComponent(
        "index.html",
        isDirectory: false
    )
    lazy var publicRSSPath = publicBasePath.appendingPathComponent(
        "rss.xml",
        isDirectory: false
    )
    lazy var publicPodcastPath = publicBasePath.appendingPathComponent(
        "podcast.xml",
        isDirectory: false
    )

    lazy var publicAssetsPath = publicBasePath.appendingPathComponent("assets", isDirectory: true)

    var template: Template? {
        TemplateStore.shared[templateName]
    }

    var templateStringRSS: String? {
        if let rssURL = Bundle.main.url(forResource:"RSS", withExtension: "xml") {
            do {
                let rssString = try String(contentsOf: rssURL)
                return rssString
            } catch {
                debugPrint("Error reading RSS template: \(error)")
            }
        }
        return nil
    }

    var nameInitials: String {
        let initials = name.components(separatedBy: .whitespaces).map { $0.prefix(1).capitalized }
            .joined()
        return String(initials.prefix(2))
    }

    var domainWithGateway: String? {
        if let domain = domain {
            if domain.hasSuffix(".eth") {
                return "\(domain).limo"
            }
            if domain.hasSuffix(".bit") {
                return "\(domain).cc"
            }
            return domain
        } else {
            return nil
        }
    }

    var browserURL: URL? {
        if let domainWithGateway = domainWithGateway {
            return URL(string: "https://" + domainWithGateway + "/")
        }
        return URL(string: "\(IPFSDaemon.preferredGateway())/ipns/\(ipns)/")
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(about)
        hasher.combine(domain)
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
        hasher.combine(telegramUsername)
        hasher.combine(dWebServicesEnabled)
        hasher.combine(dWebServicesDomain)
        hasher.combine(dWebServicesAPIKey)
        hasher.combine(filebaseEnabled)
        hasher.combine(filebasePinName)
        hasher.combine(filebaseAPIToken)
        hasher.combine(filebaseRequestID)
        hasher.combine(filebasePinCID)
        hasher.combine(customCodeHeadEnabled)
        hasher.combine(customCodeHead)
        hasher.combine(customCodeBodyStartEnabled)
        hasher.combine(customCodeBodyStart)
        hasher.combine(customCodeBodyEndEnabled)
        hasher.combine(customCodeBodyEnd)
        hasher.combine(podcastCategories)
        hasher.combine(podcastLanguage)
        hasher.combine(podcastExplicit)
        hasher.combine(avatar)
        hasher.combine(podcastCoverArt)
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
            && lhs.domain == rhs.domain
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
            && lhs.telegramUsername == rhs.telegramUsername
            && lhs.dWebServicesEnabled == rhs.dWebServicesEnabled
            && lhs.dWebServicesDomain == rhs.dWebServicesDomain
            && lhs.dWebServicesAPIKey == rhs.dWebServicesAPIKey
            && lhs.filebaseEnabled == rhs.filebaseEnabled
            && lhs.filebasePinName == rhs.filebasePinName
            && lhs.filebaseAPIToken == rhs.filebaseAPIToken
            && lhs.filebaseRequestID == rhs.filebaseRequestID
            && lhs.filebasePinCID == rhs.filebasePinCID
            && lhs.customCodeHeadEnabled == rhs.customCodeHeadEnabled
            && lhs.customCodeHead == rhs.customCodeHead
            && lhs.customCodeBodyStartEnabled == rhs.customCodeBodyStartEnabled
            && lhs.customCodeBodyStart == rhs.customCodeBodyStart
            && lhs.customCodeBodyEndEnabled == rhs.customCodeBodyEndEnabled
            && lhs.customCodeBodyEnd == rhs.customCodeBodyEnd
            && lhs.podcastCategories == rhs.podcastCategories
            && lhs.podcastLanguage == rhs.podcastLanguage
            && lhs.podcastExplicit == rhs.podcastExplicit
            && lhs.avatar == rhs.avatar
            && lhs.podcastCoverArt == rhs.podcastCoverArt
            && lhs.drafts == rhs.drafts
            && lhs.articles == rhs.articles
    }

    enum CodingKeys: String, CodingKey {
        case id, name, about, domain, ipns,
             created, updated,
             templateName, lastPublished,
             plausibleEnabled, plausibleDomain, plausibleAPIKey, plausibleAPIServer,
             twitterUsername, githubUsername, telegramUsername,
             dWebServicesEnabled, dWebServicesDomain, dWebServicesAPIKey,
             filebaseEnabled, filebasePinName, filebaseAPIToken, filebaseRequestID, filebasePinCID,
             customCodeHeadEnabled, customCodeHead, customCodeBodyStartEnabled, customCodeBodyStart, customCodeBodyEndEnabled, customCodeBodyEnd,
             podcastCategories, podcastLanguage, podcastExplicit
    }

    // `@Published` property wrapper invalidates default decode/encode implementation
    // plus we're doing class inheritance
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        about = try container.decode(String.self, forKey: .about)
        domain = try container.decodeIfPresent(String.self, forKey: .domain)
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
        telegramUsername = try container.decodeIfPresent(String.self, forKey: .telegramUsername)
        dWebServicesEnabled = try container.decodeIfPresent(Bool.self, forKey: .dWebServicesEnabled)
        dWebServicesDomain = try container.decodeIfPresent(String.self, forKey: .dWebServicesDomain)
        dWebServicesAPIKey = try container.decodeIfPresent(String.self, forKey: .dWebServicesAPIKey)
        filebaseEnabled = try container.decodeIfPresent(Bool.self, forKey: .filebaseEnabled)
        filebasePinName = try container.decodeIfPresent(String.self, forKey: .filebasePinName)
        filebaseAPIToken = try container.decodeIfPresent(String.self, forKey: .filebaseAPIToken)
        filebaseRequestID = try container.decodeIfPresent(String.self, forKey: .filebaseRequestID)
        filebasePinCID = try container.decodeIfPresent(String.self, forKey: .filebasePinCID)
        customCodeHeadEnabled = try container.decodeIfPresent(Bool.self, forKey: .customCodeHeadEnabled)
        customCodeHead = try container.decodeIfPresent(String.self, forKey: .customCodeHead)
        customCodeBodyStartEnabled = try container.decodeIfPresent(Bool.self, forKey: .customCodeBodyStartEnabled)
        customCodeBodyStart = try container.decodeIfPresent(String.self, forKey: .customCodeBodyStart)
        customCodeBodyEndEnabled = try container.decodeIfPresent(Bool.self, forKey: .customCodeBodyEndEnabled)
        customCodeBodyEnd = try container.decodeIfPresent(String.self, forKey: .customCodeBodyEnd)
        podcastCategories = try container.decodeIfPresent(Dictionary.self, forKey: .podcastCategories)
        podcastLanguage = try container.decodeIfPresent(String.self, forKey: .podcastLanguage)
        podcastExplicit = try container.decodeIfPresent(Bool.self, forKey: .podcastExplicit)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(about, forKey: .about)
        try container.encodeIfPresent(domain, forKey: .domain)
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
        try container.encodeIfPresent(telegramUsername, forKey: .telegramUsername)
        try container.encodeIfPresent(dWebServicesEnabled, forKey: .dWebServicesEnabled)
        try container.encodeIfPresent(dWebServicesDomain, forKey: .dWebServicesDomain)
        try container.encodeIfPresent(dWebServicesAPIKey, forKey: .dWebServicesAPIKey)
        try container.encodeIfPresent(filebaseEnabled, forKey: .filebaseEnabled)
        try container.encodeIfPresent(filebasePinName, forKey: .filebasePinName)
        try container.encodeIfPresent(filebaseAPIToken, forKey: .filebaseAPIToken)
        try container.encodeIfPresent(filebaseRequestID, forKey: .filebaseRequestID)
        try container.encodeIfPresent(filebasePinCID, forKey: .filebasePinCID)
        try container.encodeIfPresent(customCodeHeadEnabled, forKey: .customCodeHeadEnabled)
        try container.encodeIfPresent(customCodeHead, forKey: .customCodeHead)
        try container.encodeIfPresent(customCodeBodyStartEnabled, forKey: .customCodeBodyStartEnabled)
        try container.encodeIfPresent(customCodeBodyStart, forKey: .customCodeBodyStart)
        try container.encodeIfPresent(customCodeBodyEndEnabled, forKey: .customCodeBodyEndEnabled)
        try container.encodeIfPresent(customCodeBodyEnd, forKey: .customCodeBodyEnd)
        try container.encodeIfPresent(podcastCategories, forKey: .podcastCategories)
        try container.encodeIfPresent(podcastLanguage, forKey: .podcastLanguage)
        try container.encodeIfPresent(podcastExplicit, forKey: .podcastExplicit)
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
        planet.podcastCoverArt = NSImage(contentsOf: planet.podcastCoverArtPath)

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
        planet.podcastCoverArt = nil
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
        let backupPodcastCoverArtPath = path.appendingPathComponent("podcastCoverArt.png", isDirectory: false)

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

        // Restore domain
        if backupPlanet.domain != nil {
            planet.domain = backupPlanet.domain
        }

        // Restore Plausible
        if backupPlanet.plausibleEnabled != nil {
            planet.plausibleEnabled = backupPlanet.plausibleEnabled
        }
        if backupPlanet.plausibleDomain != nil {
            planet.plausibleDomain = backupPlanet.plausibleDomain
        }
        if backupPlanet.plausibleAPIKey != nil {
            planet.plausibleAPIKey = backupPlanet.plausibleAPIKey
        }
        if backupPlanet.plausibleAPIServer != nil {
            planet.plausibleAPIServer = backupPlanet.plausibleAPIServer
        }

        // Restore Social Links
        if backupPlanet.twitterUsername != nil {
            planet.twitterUsername = backupPlanet.twitterUsername
        }
        if backupPlanet.githubUsername != nil {
            planet.githubUsername = backupPlanet.githubUsername
        }
        if backupPlanet.telegramUsername != nil {
            planet.telegramUsername = backupPlanet.telegramUsername
        }

        // Restore DWebServices
        if backupPlanet.dWebServicesEnabled != nil {
            planet.dWebServicesEnabled = backupPlanet.dWebServicesEnabled
        }
        if backupPlanet.dWebServicesDomain != nil {
            planet.dWebServicesDomain = backupPlanet.dWebServicesDomain
        }
        if backupPlanet.dWebServicesAPIKey != nil {
            planet.dWebServicesAPIKey = backupPlanet.dWebServicesAPIKey
        }

        // Restore Filebase
        if backupPlanet.filebaseEnabled != nil {
            planet.filebaseEnabled = backupPlanet.filebaseEnabled
        }
        if backupPlanet.filebasePinName != nil {
            planet.filebasePinName = backupPlanet.filebasePinName
        }
        if backupPlanet.filebaseAPIToken != nil {
            planet.filebaseAPIToken = backupPlanet.filebaseAPIToken
        }
        if backupPlanet.filebaseRequestID != nil {
            planet.filebaseRequestID = backupPlanet.filebaseRequestID
        }
        if backupPlanet.filebasePinCID != nil {
            planet.filebasePinCID = backupPlanet.filebasePinCID
        }

        // Restore custom code
        if backupPlanet.customCodeHeadEnabled != nil {
            planet.customCodeHeadEnabled = backupPlanet.customCodeHeadEnabled
        }
        if backupPlanet.customCodeHead != nil {
            planet.customCodeHead = backupPlanet.customCodeHead
        }
        if backupPlanet.customCodeBodyStartEnabled != nil {
            planet.customCodeBodyStartEnabled = backupPlanet.customCodeBodyStartEnabled
        }
        if backupPlanet.customCodeBodyStart != nil {
            planet.customCodeBodyStart = backupPlanet.customCodeBodyStart
        }
        if backupPlanet.customCodeBodyEndEnabled != nil {
            planet.customCodeBodyEndEnabled = backupPlanet.customCodeBodyEndEnabled
        }
        if backupPlanet.customCodeBodyEnd != nil {
            planet.customCodeBodyEnd = backupPlanet.customCodeBodyEnd
        }

        // Restore Podcast settings
        if backupPlanet.podcastCategories != nil {
            planet.podcastCategories = backupPlanet.podcastCategories
        }
        if backupPlanet.podcastLanguage != nil {
            planet.podcastLanguage = backupPlanet.podcastLanguage
        }
        if backupPlanet.podcastExplicit != nil {
            planet.podcastExplicit = backupPlanet.podcastExplicit
        }

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
            if FileManager.default.fileExists(atPath: backupPodcastCoverArtPath.path) {
                try FileManager.default.copyItem(at: backupPodcastCoverArtPath, to: planet.publicPodcastCoverArtPath)
            }
        }
        catch {
            throw PlanetError.ImportPlanetError
        }
        Self.logger.info("Assets copied from backup planet \(backupPlanet.id)")

        planet.avatar = NSImage(contentsOf: planet.avatarPath)
        planet.podcastCoverArt = NSImage(contentsOf: planet.podcastCoverArtPath)

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
        if FileManager.default.fileExists(atPath: backupPodcastCoverArtPath.path) {
            try FileManager.default.copyItem(at: backupPodcastCoverArtPath, to: planet.podcastCoverArtPath)
        }
        planet.podcastCoverArt = NSImage(contentsOf: planet.podcastCoverArtPath)

        Self.logger.info("Saving imported planet \(planet.id)")
        try planet.save()
        try planet.articles.forEach { try $0.save() }
        return planet
    }

    func updateAvatar(path: URL) throws {
        // write 144x144 avatar.png
        guard let image = NSImage(contentsOf: path),
            let resizedImage = image.resizeSquare(maxLength: 144),
            let data = resizedImage.PNGData
        else {
            throw PlanetError.AvatarError
        }
        try data.write(to: avatarPath)
        try data.write(to: publicAvatarPath)
        // write 32x32 favicon.ico
        if let resizedIcon = image.resizeSquare(maxLength: 32),
            let iconData = resizedIcon.PNGData
        {
            try iconData.write(to: faviconPath)
            try iconData.write(to: publicFaviconPath)
        }
        avatar = resizedImage
    }

    func removeAvatar() throws {
        try FileManager.default.removeItem(at: avatarPath)
        try FileManager.default.removeItem(at: publicAvatarPath)
        avatar = nil
    }

    func updatePodcastCoverArt(path: URL) throws {
        // write 2048x2048 podcastCoverArt.png
        guard let image = NSImage(contentsOf: path),
            let resizedImage = image.resizeSquare(maxLength: 2048),
            let data = resizedImage.PNGData
        else {
            throw PlanetError.PodcastCoverArtError
        }
        try data.write(to: podcastCoverArtPath)
        try data.write(to: publicPodcastCoverArtPath)
        podcastCoverArt = resizedImage
    }

    func removePodcastCoverArt() throws {
        try FileManager.default.removeItem(at: podcastCoverArtPath)
        try FileManager.default.removeItem(at: publicPodcastCoverArtPath)
        podcastCoverArt = nil
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

    func renderRSS(podcastOnly: Bool = false) {
        if let templateStringRSS = templateStringRSS {
            do {
                let allArticles: [PublicArticleModel] = articles.map { item in
                    return item.publicArticle
                }
                let publicArticles = allArticles.filter { item in
                    if podcastOnly {
                        if item.audioFilename != nil {
                            return true
                        } else {
                            return false
                        }
                    } else {
                        return true
                    }
                }
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
                    githubUsername: githubUsername,
                    telegramUsername: telegramUsername,
                    podcastCategories: podcastCategories,
                    podcastLanguage: podcastLanguage,
                    podcastExplicit: podcastExplicit
                )
                let environment = Environment(extensions: [StencilExtension.common])
                let domain_prefix: String
                let root_prefix: String
                if let domainWithGateway = domainWithGateway {
                    domain_prefix = "https://" + domainWithGateway
                    root_prefix = "https://" + domainWithGateway
                } else {
                    domain_prefix = IPFSDaemon.preferredGateway()
                    root_prefix = IPFSDaemon.preferredGateway() + "/ipns/" + ipns
                }
                let context: [String: Any] = [
                    "planet": publicPlanet,
                    "has_domain": domain != nil,
                    "domain": domainWithGateway ?? "",
                    "domain_prefix": domain_prefix,
                    "root_prefix": root_prefix,
                    "ipfs_gateway": IPFSDaemon.preferredGateway(),
                    "podcast": podcastOnly,
                    "has_podcast_cover_art": FileManager.default.fileExists(atPath: publicPodcastCoverArtPath.path)
                ]
                let rssXML = try environment.renderTemplate(string: templateStringRSS, context: context)
                debugPrint("rssXML: \(rssXML)")
                if podcastOnly {
                    try rssXML.data(using: .utf8)?.write(to: publicPodcastPath)
                } else {
                    try rssXML.data(using: .utf8)?.write(to: publicRSSPath)
                }
            } catch {
                debugPrint("Error rendering RSS: \(error)")
            }
        }
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
            githubUsername: githubUsername,
            telegramUsername: telegramUsername,
            podcastCategories: podcastCategories,
            podcastLanguage: podcastLanguage,
            podcastExplicit: podcastExplicit
        )
        let hasAvatar = FileManager.default.fileExists(atPath: publicAvatarPath.path)
        let hasPodcastCoverArt = FileManager.default.fileExists(atPath: publicPodcastCoverArtPath.path)
        let context: [String: Any] = [
            "planet": publicPlanet,
            "my_planet": self,
            "has_avatar": hasAvatar,
            "has_podcast": publicPlanet.hasAudioContent(),
            "has_podcast_cover_art": hasPodcastCoverArt
        ]
        let indexHTML = try template.renderIndex(context: context)
        try indexHTML.data(using: .utf8)?.write(to: publicIndexPath)

        renderRSS(podcastOnly: false)

        if publicPlanet.hasAudioContent() {
            renderRSS(podcastOnly: true)
        }

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
        // Send the latest CID to dWebServices.xyz if enabled
        if let dWebServicesEnabled = dWebServicesEnabled, dWebServicesEnabled, let dWebServicesDomain = dWebServicesDomain, let dWebServicesAPIKey = dWebServicesAPIKey {
            debugPrint("dWebServices: about to update for \(dWebServicesDomain)")
            let dWebRecord = dWebServices(domain: dWebServicesDomain, apiKey: dWebServicesAPIKey)
            await dWebRecord.publish(cid: cid)
        }
        // Send the latest CID to Filebase if enabled
        if let filebaseEnabled = filebaseEnabled, filebaseEnabled, let filebasePinName = filebasePinName, let filebaseAPIToken = filebaseAPIToken {
            var toPin: Bool = false
            if let existingCID = filebasePinCID {
                if existingCID.count == 0 || existingCID != cid {
                    toPin = true
                }
            } else {
                toPin = true
            }
            if toPin {
                debugPrint("Filebase: about to pin for \(filebasePinName)")
                let filebase = Filebase(pinName: filebasePinName, apiToken: filebaseAPIToken)
                if let requestID = await filebase.pin(cid: cid) {
                    Task { @MainActor in
                        self.filebaseRequestID = requestID
                        self.filebasePinCID = cid
                    }
                    try save()
                }
            } else {
                debugPrint("Filebase: no need to pin for \(filebasePinName)")
            }
        }
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
        Task(priority: .background) {
            await self.prewarm()
        }
    }

    func prewarm() async {
        guard let rootURL = browserURL else { return }
        let planetJSONURL = rootURL.appendingPathComponent("planet.json")
        do {
            debugPrint("About to prewarm \(name): \(planetJSONURL)")
            let (planetJSONData, _) = try await URLSession.shared.data(from: planetJSONURL)
            debugPrint("Prewarmed \(name): \(planetJSONData.count) bytes")
        } catch {
            debugPrint("Failed to prewarm \(name): \(error)")
        }
    }

    func importArticle(articleID: UUID) async throws {
        let myPlanets = await PlanetStore.shared.myPlanets
        var previousPlanet: MyPlanetModel?
        var targetArticle: MyArticleModel?
        for myPlanet in myPlanets {
            if let article = myPlanet.articles.first(where: { $0.id == articleID && $0.planet.id != self.id }) {
                targetArticle = article
                previousPlanet = myPlanet
                break
            }
        }
        guard let previousPlanet = previousPlanet, let targetArticle = targetArticle else { return }
        debugPrint("moving article: \(targetArticle) from planet: \(previousPlanet) to planet: \(self) ...")
        // MARK: TODO: move article.
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
            domain: domain,
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
            telegramUsername: telegramUsername,
            dWebServicesEnabled: dWebServicesEnabled,
            dWebServicesDomain: dWebServicesDomain,
            dWebServicesAPIKey: dWebServicesAPIKey,
            filebaseEnabled: filebaseEnabled,
            filebasePinName: filebasePinName,
            filebaseAPIToken: filebaseAPIToken,
            filebaseRequestID: filebaseRequestID,
            filebasePinCID: filebasePinCID,
            customCodeHeadEnabled: customCodeHeadEnabled,
            customCodeHead: customCodeHead,
            customCodeBodyStartEnabled: customCodeBodyStartEnabled,
            customCodeBodyStart: customCodeBodyStart,
            customCodeBodyEndEnabled: customCodeBodyEndEnabled,
            customCodeBodyEnd: customCodeBodyEnd,
            podcastCategories: podcastCategories,
            podcastLanguage: podcastLanguage,
            podcastExplicit: podcastExplicit,
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
    let telegramUsername: String?

    let podcastCategories: [String: [String]]?
    let podcastLanguage: String?
    let podcastExplicit: Bool?

    func hasAudioContent() -> Bool {
        for article in articles {
            if article.audioFilename != nil {
                return true
            }
        }
        return false
    }

    func hasVideoContent() -> Bool {
        for article in articles {
            if article.videoFilename != nil {
                return true
            }
        }
        return false
    }
}

struct BackupMyPlanetModel: Codable {
    let id: UUID
    let name: String
    let about: String
    let domain: String?
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
    let telegramUsername: String?
    let dWebServicesEnabled: Bool?
    let dWebServicesDomain: String?
    let dWebServicesAPIKey: String?
    let filebaseEnabled: Bool?
    let filebasePinName: String?
    let filebaseAPIToken: String?
    let filebaseRequestID: String?
    let filebasePinCID: String?
    let customCodeHeadEnabled: Bool?
    let customCodeHead: String?
    let customCodeBodyStartEnabled: Bool?
    let customCodeBodyStart: String?
    let customCodeBodyEndEnabled: Bool?
    let customCodeBodyEnd: String?
    let podcastCategories: [String: [String]]?
    let podcastLanguage: String?
    let podcastExplicit: Bool?
    let articles: [BackupArticleModel]
}
