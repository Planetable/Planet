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
    @Published var authorName: String?
    let created: Date
    let ipns: String
    @Published var updated: Date
    @Published var templateName: String
    @Published var lastPublished: Date?
    @Published var lastPublishedCID: String?

    @Published var archived: Bool? = false
    @Published var archivedAt: Date?

    @Published var plausibleEnabled: Bool? = false
    @Published var plausibleDomain: String?
    @Published var plausibleAPIKey: String?
    @Published var plausibleAPIServer: String? = "plausible.io"

    @Published var twitterUsername: String?
    @Published var githubUsername: String?
    @Published var telegramUsername: String?
    @Published var mastodonUsername: String?

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

    @Published var juiceboxEnabled: Bool? = false
    @Published var juiceboxProjectID: Int?
    @Published var juiceboxProjectIDGoerli: Int?

    @Published var metrics: Metrics?

    @Published var isPublishing = false
    // populated when initializing

    @Published var avatar: NSImage? = nil
    @Published var podcastCoverArt: NSImage? = nil

    @Published var drafts: [DraftModel]! = nil
    @Published var articles: [MyArticleModel]! = nil

    static func myPlanetsPath() -> URL {
        let url = URLUtils.repoPath().appendingPathComponent("My", isDirectory: true)
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    var basePath: URL {
        return Self.myPlanetsPath().appendingPathComponent(self.id.uuidString, isDirectory: true)
    }
    var infoPath: URL {
        return Self.myPlanetsPath().appendingPathComponent(self.id.uuidString, isDirectory: true)
            .appendingPathComponent("planet.json", isDirectory: false)
    }
    var articlesPath: URL {
        return Self.myPlanetsPath().appendingPathComponent(self.id.uuidString, isDirectory: true)
            .appendingPathComponent("Articles", isDirectory: true)
    }
    var avatarPath: URL {
        return Self.myPlanetsPath().appendingPathComponent(self.id.uuidString, isDirectory: true)
            .appendingPathComponent("avatar.png", isDirectory: false)
    }
    var faviconPath: URL {
        return Self.myPlanetsPath().appendingPathComponent(self.id.uuidString, isDirectory: true)
            .appendingPathComponent("favicon.ico", isDirectory: false)
    }
    var podcastCoverArtPath: URL {
        return Self.myPlanetsPath().appendingPathComponent(self.id.uuidString, isDirectory: true)
            .appendingPathComponent("podcastCoverArt.png", isDirectory: false)
    }
    var draftsPath: URL {
        return Self.myPlanetsPath().appendingPathComponent(self.id.uuidString, isDirectory: true)
            .appendingPathComponent("Drafts", isDirectory: true)
    }
    var articleDraftsPath: URL {
        return Self.myPlanetsPath().appendingPathComponent(self.id.uuidString, isDirectory: true)
            .appendingPathComponent("Articles", isDirectory: true).appendingPathComponent(
                "Drafts",
                isDirectory: true
            )
    }

    static func publicPlanetsPath() -> URL {
        let url = URLUtils.repoPath().appendingPathComponent("Public", isDirectory: true)
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    var publicBasePath: URL {
        return Self.publicPlanetsPath().appendingPathComponent(
            self.id.uuidString,
            isDirectory: true
        )
    }
    var publicInfoPath: URL {
        return Self.publicPlanetsPath().appendingPathComponent(
            self.id.uuidString,
            isDirectory: true
        ).appendingPathComponent("planet.json", isDirectory: false)
    }
    var publicAvatarPath: URL {
        return Self.publicPlanetsPath().appendingPathComponent(
            self.id.uuidString,
            isDirectory: true
        ).appendingPathComponent("avatar.png", isDirectory: false)
    }
    var publicFaviconPath: URL {
        return Self.publicPlanetsPath().appendingPathComponent(
            self.id.uuidString,
            isDirectory: true
        ).appendingPathComponent("favicon.ico", isDirectory: false)
    }
    var publicPodcastCoverArtPath: URL {
        return Self.publicPlanetsPath().appendingPathComponent(
            self.id.uuidString,
            isDirectory: true
        ).appendingPathComponent("podcastCoverArt.png", isDirectory: false)
    }
    var publicIndexPath: URL {
        return Self.publicPlanetsPath().appendingPathComponent(
            self.id.uuidString,
            isDirectory: true
        ).appendingPathComponent("index.html", isDirectory: false)
    }
    func publicIndexPagePath(page: Int) -> URL {
        return Self.publicPlanetsPath().appendingPathComponent(
            self.id.uuidString,
            isDirectory: true
        ).appendingPathComponent("page\(page).html", isDirectory: false)
    }
    var publicRSSPath: URL {
        return Self.publicPlanetsPath().appendingPathComponent(
            self.id.uuidString,
            isDirectory: true
        ).appendingPathComponent("rss.xml", isDirectory: false)
    }
    var publicPodcastPath: URL {
        return Self.publicPlanetsPath().appendingPathComponent(
            self.id.uuidString,
            isDirectory: true
        ).appendingPathComponent("podcast.xml", isDirectory: false)
    }
    var publicAssetsPath: URL {
        return Self.publicPlanetsPath().appendingPathComponent(
            self.id.uuidString,
            isDirectory: true
        ).appendingPathComponent("assets", isDirectory: true)
    }

    var template: Template? {
        TemplateStore.shared[templateName]
    }

    var templateStringRSS: String? {
        if let rssURL = Bundle.main.url(forResource: "RSS", withExtension: "xml") {
            do {
                let rssString = try String(contentsOf: rssURL)
                return rssString
            }
            catch {
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
        if let domain: String = domain {
            let domain = domain.trim()
            if domain.hasSuffix(".eth") {
                return "\(domain).limo"
            }
            if domain.hasSuffix(".bit") {
                return "\(domain).cc"
            }
            if domain.count > 0 {
                return domain
            }
            else {
                return nil
            }
        }
        else {
            return nil
        }
    }

    var ogImageURLString: String {
        if let domain = domainWithGateway {
            return "https://\(domain)/avatar.png"
        }
        else {
            return "https://ipfs.io/ipns/\(ipns)/avatar.png"
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
        hasher.combine(authorName)
        hasher.combine(created)
        hasher.combine(ipns)
        hasher.combine(updated)
        hasher.combine(templateName)
        hasher.combine(lastPublished)
        hasher.combine(lastPublishedCID)
        hasher.combine(isPublishing)
        hasher.combine(archived)
        hasher.combine(archivedAt)
        hasher.combine(plausibleEnabled)
        hasher.combine(plausibleDomain)
        hasher.combine(plausibleAPIKey)
        hasher.combine(plausibleAPIServer)
        hasher.combine(twitterUsername)
        hasher.combine(githubUsername)
        hasher.combine(telegramUsername)
        hasher.combine(mastodonUsername)
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
        hasher.combine(juiceboxEnabled)
        hasher.combine(juiceboxProjectID)
        hasher.combine(juiceboxProjectIDGoerli)
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
            && lhs.authorName == rhs.authorName
            && lhs.created == rhs.created
            && lhs.ipns == rhs.ipns
            && lhs.updated == rhs.updated
            && lhs.templateName == rhs.templateName
            && lhs.lastPublished == rhs.lastPublished
            && lhs.lastPublishedCID == rhs.lastPublishedCID
            && lhs.archived == rhs.archived
            && lhs.archivedAt == rhs.archivedAt
            && lhs.plausibleEnabled == rhs.plausibleEnabled
            && lhs.plausibleDomain == rhs.plausibleDomain
            && lhs.plausibleAPIKey == rhs.plausibleAPIKey
            && lhs.plausibleAPIServer == rhs.plausibleAPIServer
            && lhs.isPublishing == rhs.isPublishing
            && lhs.twitterUsername == rhs.twitterUsername
            && lhs.githubUsername == rhs.githubUsername
            && lhs.telegramUsername == rhs.telegramUsername
            && lhs.mastodonUsername == rhs.mastodonUsername
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
            && lhs.juiceboxEnabled == rhs.juiceboxEnabled
            && lhs.juiceboxProjectID == rhs.juiceboxProjectID
            && lhs.juiceboxProjectIDGoerli == rhs.juiceboxProjectIDGoerli
            && lhs.avatar == rhs.avatar
            && lhs.podcastCoverArt == rhs.podcastCoverArt
            && lhs.drafts == rhs.drafts
            && lhs.articles == rhs.articles
    }

    enum CodingKeys: String, CodingKey {
        case id, name, about, domain, authorName, ipns,
            created, updated,
            templateName, lastPublished, lastPublishedCID,
            archived, archivedAt,
            plausibleEnabled, plausibleDomain, plausibleAPIKey, plausibleAPIServer,
            twitterUsername, githubUsername, telegramUsername, mastodonUsername,
            dWebServicesEnabled, dWebServicesDomain, dWebServicesAPIKey,
            filebaseEnabled, filebasePinName, filebaseAPIToken, filebaseRequestID, filebasePinCID,
            customCodeHeadEnabled, customCodeHead, customCodeBodyStartEnabled, customCodeBodyStart,
            customCodeBodyEndEnabled, customCodeBodyEnd,
            podcastCategories, podcastLanguage, podcastExplicit,
            juiceboxEnabled, juiceboxProjectID, juiceboxProjectIDGoerli
    }

    // `@Published` property wrapper invalidates default decode/encode implementation
    // plus we're doing class inheritance
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        about = try container.decode(String.self, forKey: .about)
        domain = try container.decodeIfPresent(String.self, forKey: .domain)
        authorName = try container.decodeIfPresent(String.self, forKey: .authorName)
        ipns = try container.decode(String.self, forKey: .ipns)
        created = try container.decode(Date.self, forKey: .created)
        updated = try container.decode(Date.self, forKey: .updated)
        templateName = try container.decode(String.self, forKey: .templateName)
        lastPublished = try container.decodeIfPresent(Date.self, forKey: .lastPublished)
        lastPublishedCID = try container.decodeIfPresent(String.self, forKey: .lastPublishedCID)
        archived = try container.decodeIfPresent(Bool.self, forKey: .archived)
        archivedAt = try container.decodeIfPresent(Date.self, forKey: .archivedAt)
        plausibleEnabled = try container.decodeIfPresent(Bool.self, forKey: .plausibleEnabled)
        plausibleDomain = try container.decodeIfPresent(String.self, forKey: .plausibleDomain)
        plausibleAPIKey = try container.decodeIfPresent(String.self, forKey: .plausibleAPIKey)
        plausibleAPIServer = try container.decodeIfPresent(String.self, forKey: .plausibleAPIServer)
        twitterUsername = try container.decodeIfPresent(String.self, forKey: .twitterUsername)
        githubUsername = try container.decodeIfPresent(String.self, forKey: .githubUsername)
        telegramUsername = try container.decodeIfPresent(String.self, forKey: .telegramUsername)
        mastodonUsername = try container.decodeIfPresent(String.self, forKey: .mastodonUsername)
        dWebServicesEnabled = try container.decodeIfPresent(Bool.self, forKey: .dWebServicesEnabled)
        dWebServicesDomain = try container.decodeIfPresent(String.self, forKey: .dWebServicesDomain)
        dWebServicesAPIKey = try container.decodeIfPresent(String.self, forKey: .dWebServicesAPIKey)
        filebaseEnabled = try container.decodeIfPresent(Bool.self, forKey: .filebaseEnabled)
        filebasePinName = try container.decodeIfPresent(String.self, forKey: .filebasePinName)
        filebaseAPIToken = try container.decodeIfPresent(String.self, forKey: .filebaseAPIToken)
        filebaseRequestID = try container.decodeIfPresent(String.self, forKey: .filebaseRequestID)
        filebasePinCID = try container.decodeIfPresent(String.self, forKey: .filebasePinCID)
        customCodeHeadEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .customCodeHeadEnabled
        )
        customCodeHead = try container.decodeIfPresent(String.self, forKey: .customCodeHead)
        customCodeBodyStartEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .customCodeBodyStartEnabled
        )
        customCodeBodyStart = try container.decodeIfPresent(
            String.self,
            forKey: .customCodeBodyStart
        )
        customCodeBodyEndEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .customCodeBodyEndEnabled
        )
        customCodeBodyEnd = try container.decodeIfPresent(String.self, forKey: .customCodeBodyEnd)
        podcastCategories = try container.decodeIfPresent(
            Dictionary.self,
            forKey: .podcastCategories
        )
        podcastLanguage = try container.decodeIfPresent(String.self, forKey: .podcastLanguage)
        podcastExplicit = try container.decodeIfPresent(Bool.self, forKey: .podcastExplicit)
        juiceboxEnabled = try container.decodeIfPresent(Bool.self, forKey: .juiceboxEnabled)
        juiceboxProjectID = try container.decodeIfPresent(Int.self, forKey: .juiceboxProjectID)
        juiceboxProjectIDGoerli = try container.decodeIfPresent(
            Int.self,
            forKey: .juiceboxProjectIDGoerli
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(about, forKey: .about)
        try container.encodeIfPresent(domain, forKey: .domain)
        try container.encodeIfPresent(authorName, forKey: .authorName)
        try container.encode(ipns, forKey: .ipns)
        try container.encode(created, forKey: .created)
        try container.encode(updated, forKey: .updated)
        try container.encode(templateName, forKey: .templateName)
        try container.encodeIfPresent(lastPublished, forKey: .lastPublished)
        try container.encodeIfPresent(lastPublishedCID, forKey: .lastPublishedCID)
        try container.encodeIfPresent(archived, forKey: .archived)
        try container.encodeIfPresent(archivedAt, forKey: .archivedAt)
        try container.encodeIfPresent(plausibleEnabled, forKey: .plausibleEnabled)
        try container.encodeIfPresent(plausibleDomain, forKey: .plausibleDomain)
        try container.encodeIfPresent(plausibleAPIKey, forKey: .plausibleAPIKey)
        try container.encodeIfPresent(plausibleAPIServer, forKey: .plausibleAPIServer)
        try container.encodeIfPresent(twitterUsername, forKey: .twitterUsername)
        try container.encodeIfPresent(githubUsername, forKey: .githubUsername)
        try container.encodeIfPresent(telegramUsername, forKey: .telegramUsername)
        try container.encodeIfPresent(mastodonUsername, forKey: .mastodonUsername)
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
        try container.encodeIfPresent(
            customCodeBodyStartEnabled,
            forKey: .customCodeBodyStartEnabled
        )
        try container.encodeIfPresent(customCodeBodyStart, forKey: .customCodeBodyStart)
        try container.encodeIfPresent(customCodeBodyEndEnabled, forKey: .customCodeBodyEndEnabled)
        try container.encodeIfPresent(customCodeBodyEnd, forKey: .customCodeBodyEnd)
        try container.encodeIfPresent(podcastCategories, forKey: .podcastCategories)
        try container.encodeIfPresent(podcastLanguage, forKey: .podcastLanguage)
        try container.encodeIfPresent(podcastExplicit, forKey: .podcastExplicit)
        try container.encodeIfPresent(juiceboxEnabled, forKey: .juiceboxEnabled)
        try container.encodeIfPresent(juiceboxProjectID, forKey: .juiceboxProjectID)
        try container.encodeIfPresent(juiceboxProjectIDGoerli, forKey: .juiceboxProjectIDGoerli)
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
        debugPrint(
            "Loading Planet \(planet.name) drafts from \(draftDirectories.count) directories"
        )
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
        try? KeychainHelper.shared.exportKeyToKeychain(forPlanetKeyName: id.uuidString)
        return planet
    }

    @MainActor static func importBackup(from path: URL) throws -> MyPlanetModel {
        Self.logger.info("Importing backup from \(path)")
        let backupInfoPath = path.appendingPathComponent("planet.json", isDirectory: false)
        let backupAssetsPath = path.appendingPathComponent("assets", isDirectory: true)
        let backupIndexPath = path.appendingPathComponent("index.html", isDirectory: false)
        let backupPrivateKeyPath = path.appendingPathComponent("planet.key", isDirectory: false)
        let backupAvatarPath = path.appendingPathComponent("avatar.png", isDirectory: false)
        let backupPodcastCoverArtPath = path.appendingPathComponent(
            "podcastCoverArt.png",
            isDirectory: false
        )

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
            // also export key to keychain
            try? KeychainHelper.shared.exportKeyToKeychain(
                forPlanetKeyName: backupPlanet.id.uuidString
            )
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

        // Restore authorName
        if backupPlanet.authorName != nil {
            planet.authorName = backupPlanet.authorName
        }

        // Restore last published CID
        if backupPlanet.lastPublishedCID != nil {
            planet.lastPublishedCID = backupPlanet.lastPublishedCID
        }

        // Restore archived
        if backupPlanet.archived != nil {
            planet.archived = backupPlanet.archived
        }
        else {
            planet.archived = false
        }
        if backupPlanet.archivedAt != nil {
            planet.archivedAt = backupPlanet.archivedAt
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
        if backupPlanet.mastodonUsername != nil {
            planet.mastodonUsername = backupPlanet.mastodonUsername
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

        // Restore Juicebox settings
        if backupPlanet.juiceboxEnabled != nil {
            planet.juiceboxEnabled = backupPlanet.juiceboxEnabled
        }
        if backupPlanet.juiceboxProjectID != nil {
            planet.juiceboxProjectID = backupPlanet.juiceboxProjectID
        }
        if backupPlanet.juiceboxProjectIDGoerli != nil {
            planet.juiceboxProjectIDGoerli = backupPlanet.juiceboxProjectIDGoerli
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
                try FileManager.default.copyItem(
                    at: backupPodcastCoverArtPath,
                    to: planet.publicPodcastCoverArtPath
                )
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
                    slug: backupArticle.slug,
                    title: backupArticle.title,
                    content: backupArticle.content,
                    summary: backupArticle.summary,
                    created: backupArticle.created,
                    starred: nil,
                    starType: backupArticle.starType,
                    videoFilename: backupArticle.videoFilename,
                    audioFilename: backupArticle.audioFilename,
                    attachments: backupArticle.attachments,
                    isIncludedInNavigation: backupArticle.isIncludedInNavigation,
                    navigationWeight: backupArticle.navigationWeight
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
            try FileManager.default.copyItem(
                at: backupPodcastCoverArtPath,
                to: planet.podcastCoverArtPath
            )
        }
        planet.podcastCoverArt = NSImage(contentsOf: planet.podcastCoverArtPath)

        Self.logger.info("Saving imported planet \(planet.id)")
        try planet.save()
        try planet.articles.forEach { try $0.save() }
        return planet
    }

    func updateAvatar(path: URL) throws {
        guard let image = NSImage(contentsOf: path)
        else {
            throw PlanetError.AvatarError
        }
        let size = image.size
        // if path is already a PNG and size is within 120x120 and 288x288 then just use it
        if path.pathExtension == "png",
            size.width >= 120 && size.width <= 288 && size.height >= 120 && size.height <= 288
        {
            if FileManager.default.fileExists(atPath: avatarPath.path) {
                try FileManager.default.removeItem(at: avatarPath)
            }
            try FileManager.default.copyItem(at: path, to: avatarPath)
            if FileManager.default.fileExists(atPath: publicAvatarPath.path) {
                try FileManager.default.removeItem(at: publicAvatarPath)
            }
            try FileManager.default.copyItem(at: path, to: publicAvatarPath)
            avatar = image
            try updateFavicon(witImage: image)
            return
        }
        // write 144x144 avatar.png
        if let resizedImage = image.resizeSquare(maxLength: 144), let data = resizedImage.PNGData {
            try data.write(to: avatarPath)
            try data.write(to: publicAvatarPath)
            avatar = resizedImage
        }
        // write 32x32 favicon.ico
        try updateFavicon(witImage: image)
    }

    func updateFavicon(witImage image: NSImage) throws {
        if let resizedIcon = image.resizeSquare(maxLength: 32),
            let iconData = resizedIcon.PNGData
        {
            try iconData.write(to: faviconPath)
            try iconData.write(to: publicFaviconPath)
        }
    }

    func uploadAvatar(image: NSImage) throws {
        guard
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

    @ViewBuilder
    func avatarView(size: CGFloat) -> some View {
        if let image = self.avatar {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size, alignment: .center)
                .cornerRadius(size / 2)
                .overlay(
                    RoundedRectangle(cornerRadius: size / 2)
                        .stroke(Color("BorderColor"), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                .padding(2)
        }
        else {
            Text(self.nameInitials)
                .font(Font.custom("Arial Rounded MT Bold", size: size / 2))
                .foregroundColor(Color.white)
                .contentShape(Rectangle())
                .frame(width: size, height: size, alignment: .center)
                .background(
                    LinearGradient(
                        gradient: ViewUtils.getPresetGradient(from: self.id),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(size / 2)
                .overlay(
                    RoundedRectangle(cornerRadius: size / 2)
                        .stroke(Color("BorderColor"), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                .padding(2)
        }
    }

    @ViewBuilder
    func smallAvatarAndNameView() -> some View {
        if let image = self.avatar {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24, alignment: .center)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color("BorderColor"), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
        }
        else {
            Text(self.nameInitials)
                .font(Font.custom("Arial Rounded MT Bold", size: 12))
                .foregroundColor(Color.white)
                .contentShape(Rectangle())
                .frame(width: 24, height: 24, alignment: .center)
                .background(
                    LinearGradient(
                        gradient: ViewUtils.getPresetGradient(from: self.id),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color("BorderColor"), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
        }

        Text("\(self.name)")
            .font(.body)
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
                        }
                        else {
                            return false
                        }
                    }
                    else {
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
                    juiceboxEnabled: juiceboxEnabled,
                    juiceboxProjectID: juiceboxProjectID,
                    juiceboxProjectIDGoerli: juiceboxProjectIDGoerli,
                    twitterUsername: twitterUsername,
                    githubUsername: githubUsername,
                    telegramUsername: telegramUsername,
                    mastodonUsername: mastodonUsername,
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
                }
                else {
                    domain_prefix = IPFSDaemon.preferredGateway()
                    root_prefix = IPFSDaemon.preferredGateway() + "/ipns/" + ipns
                }
                var hasDomain: Bool = false
                if let planetDomain = domain, planetDomain.count > 0, !planetDomain.contains(":") {
                    hasDomain = true
                }
                let context: [String: Any] = [
                    "planet": publicPlanet,
                    "has_domain": hasDomain,
                    "domain": domainWithGateway ?? "",
                    "domain_prefix": domain_prefix,
                    "root_prefix": root_prefix,
                    "ipfs_gateway": IPFSDaemon.preferredGateway(),
                    "podcast": podcastOnly,
                    "has_podcast_cover_art": FileManager.default.fileExists(
                        atPath: publicPodcastCoverArtPath.path
                    ),
                ]
                let rssXML = try environment.renderTemplate(
                    string: templateStringRSS,
                    context: context
                )
                debugPrint("rssXML: \(rssXML)")
                if podcastOnly {
                    try rssXML.data(using: .utf8)?.write(to: publicPodcastPath)
                }
                else {
                    try rssXML.data(using: .utf8)?.write(to: publicRSSPath)
                }
            }
            catch {
                debugPrint("Error rendering RSS: \(error)")
            }
        }
    }

    func savePublic() throws {
        guard let template = template else {
            throw PlanetError.MissingTemplateError
        }
        let siteNavigation = self.siteNavigation()
        debugPrint("Planet Site Navigation: \(siteNavigation)")
        let publicArticles = articles.filter { $0.articleType == .blog }.map { $0.publicArticle }
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
            juiceboxEnabled: juiceboxEnabled,
            juiceboxProjectID: juiceboxProjectID,
            juiceboxProjectIDGoerli: juiceboxProjectIDGoerli,
            twitterUsername: twitterUsername,
            githubUsername: githubUsername,
            telegramUsername: telegramUsername,
            mastodonUsername: mastodonUsername,
            podcastCategories: podcastCategories,
            podcastLanguage: podcastLanguage,
            podcastExplicit: podcastExplicit
        )
        let hasPodcastCoverArt = FileManager.default.fileExists(
            atPath: publicPodcastCoverArtPath.path
        )
        let itemsPerPage = template.idealItemsPerPage ?? 10
        if publicPlanet.articles.count > itemsPerPage {
            let pages = Int(ceil(Double(publicPlanet.articles.count) / Double(itemsPerPage)))
            debugPrint("Rendering \(pages) pages")
            for i in 1...pages {
                let pageArticles = Array(
                    publicPlanet.articles[
                        (i - 1) * itemsPerPage..<min(i * itemsPerPage, publicPlanet.articles.count)
                    ]
                )
                let pageContext: [String: Any] = [
                    "planet": publicPlanet,
                    "my_planet": self,
                    "site_navigation": siteNavigation,
                    "has_avatar": hasAvatar,
                    "og_image_url": ogImageURLString,
                    "has_podcast": publicPlanet.hasAudioContent(),
                    "has_podcast_cover_art": hasPodcastCoverArt,
                    "page": i,
                    "pages": pages,
                    "articles": pageArticles,
                ]
                let pageHTML = try template.renderIndex(context: pageContext)
                let pagePath = publicIndexPagePath(page: i)
                try pageHTML.data(using: .utf8)?.write(to: pagePath)

                if i == 1 {
                    debugPrint("Build index.html: hasAvatar=\(self.hasAvatar())")
                    let indexHTML = try template.renderIndex(context: pageContext)
                    try indexHTML.data(using: .utf8)?.write(to: publicIndexPath)
                }
            }
        }
        else {
            let pageContext: [String: Any] = [
                "planet": publicPlanet,
                "my_planet": self,
                "site_navigation": siteNavigation,
                "has_avatar": self.hasAvatar(),
                "og_image_url": ogImageURLString,
                "has_podcast": publicPlanet.hasAudioContent(),
                "has_podcast_cover_art": hasPodcastCoverArt,
                "articles": publicPlanet.articles,
            ]
            let pageHTML = try template.renderIndex(context: pageContext)
            let pagePath = publicIndexPagePath(page: 1)
            try pageHTML.data(using: .utf8)?.write(to: pagePath)

            let indexHTML = try template.renderIndex(context: pageContext)
            try indexHTML.data(using: .utf8)?.write(to: publicIndexPath)
        }

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
        // Make sure planet key is available in keystore or in keychain, abort publishing if not.
        if try await !IPFSDaemon.shared.checkKeyExists(name: id.uuidString) {
            try KeychainHelper.shared.importKeyFromKeychain(forPlanetKeyName: id.uuidString)
        }
        let cid = try await IPFSDaemon.shared.addDirectory(url: publicBasePath)
        // Send the latest CID to dWebServices.xyz if enabled
        if let dWebServicesEnabled = dWebServicesEnabled, dWebServicesEnabled,
            let dWebServicesDomain = dWebServicesDomain, let dWebServicesAPIKey = dWebServicesAPIKey
        {
            debugPrint("dWebServices: about to update for \(dWebServicesDomain)")
            let dWebRecord = dWebServices(domain: dWebServicesDomain, apiKey: dWebServicesAPIKey)
            await dWebRecord.publish(cid: cid)
        }
        // Send the latest CID to Filebase if enabled
        if let filebaseEnabled = filebaseEnabled, filebaseEnabled,
            let filebasePinName = filebasePinName, let filebaseAPIToken = filebaseAPIToken
        {
            var toPin: Bool = false
            if let existingCID = filebasePinCID {
                if existingCID.count == 0 || existingCID != cid {
                    toPin = true
                }
            }
            else {
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
            }
            else {
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
            self.lastPublishedCID = cid
        }
        try save()
        Task(priority: .background) {
            await self.prewarm()
        }
        if UserDefaults.standard.bool(forKey: .settingsAPIEnabled) {
            Task {
                try? await PlanetAPIHelper.shared.relaunch()
            }
        }
    }

    func prewarm() async {
        guard let rootURL = browserURL else { return }
        let planetJSONURL = rootURL.appendingPathComponent("planet.json")
        do {
            debugPrint("About to prewarm \(name): \(planetJSONURL)")
            let (planetJSONData, _) = try await URLSession.shared.data(from: planetJSONURL)
            debugPrint("Prewarmed \(name): \(planetJSONData.count) bytes")
        }
        catch {
            debugPrint("Failed to prewarm \(name): \(error)")
        }
    }

    func exportBackup(to directory: URL, isForAirDropSharing: Bool = false) throws {
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
            authorName: authorName,
            ipns: ipns,
            created: created,
            updated: updated,
            lastPublished: lastPublished,
            lastPublishedCID: lastPublishedCID,
            archived: archived,
            archivedAt: archivedAt,
            templateName: templateName,
            plausibleEnabled: plausibleEnabled,
            plausibleDomain: plausibleDomain,
            plausibleAPIKey: plausibleAPIKey,
            plausibleAPIServer: plausibleAPIServer,
            twitterUsername: twitterUsername,
            githubUsername: githubUsername,
            telegramUsername: telegramUsername,
            mastodonUsername: mastodonUsername,
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
            juiceboxEnabled: juiceboxEnabled,
            juiceboxProjectID: juiceboxProjectID,
            juiceboxProjectIDGoerli: juiceboxProjectIDGoerli,
            articles: articles.map {
                BackupArticleModel(
                    id: $0.id,
                    link: $0.link,
                    slug: $0.slug,
                    externalLink: $0.externalLink,
                    title: $0.title,
                    content: $0.content,
                    summary: $0.summary,
                    starred: $0.starred,
                    starType: $0.starType,
                    created: $0.created,
                    videoFilename: $0.videoFilename,
                    audioFilename: $0.audioFilename,
                    attachments: $0.attachments,
                    isIncludedInNavigation: $0.isIncludedInNavigation,
                    navigationWeight: $0.navigationWeight
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

        if !isForAirDropSharing {
            NSWorkspace.shared.activateFileViewerSelecting([exportPath])
        }
    }

    func save() throws {
        try JSONEncoder.shared.encode(self).write(to: infoPath)
    }

    func archive() {
        Task { @MainActor in
            self.archived = true
            self.archivedAt = Date()
            try? self.save()
        }
    }

    func delete() throws {
        try FileManager.default.removeItem(at: basePath)
        // try FileManager.default.removeItem(at: publicBasePath)
        Task(priority: .utility) {
            do {
                try await IPFSDaemon.shared.removeKey(name: id.uuidString)
                try KeychainHelper.shared.delete(forKey: id.uuidString)
            }
            catch {
                debugPrint("failed to remove key from planet: \(id.uuidString), error: \(error)")
            }
        }
    }

    func rebuild() throws {
        try self.copyTemplateAssets()
        try self.articles.forEach { try $0.savePublic() }
        try self.savePublic()
        NotificationCenter.default.post(name: .loadArticle, object: nil)
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

struct NavigationItem: Codable {
    let id: String
    let title: String
    let slug: String
    let externalLink: String?
    let weight: Int
}

extension MyPlanetModel {
    func hasAvatar() -> Bool {
        FileManager.default.fileExists(atPath: publicAvatarPath.path)
    }

    func navigationSubtitle() -> String {
        if articles.count > 0 {
            if articles.count > 1 {
                return "\(articles.count) articles"
            }
            else {
                return "1 article"
            }
        }
        else {
            return "No articles"
        }
    }

    func siteNavigation() -> [NavigationItem] {
        var navigation: [NavigationItem] = articles.compactMap { article in
            let articleSlug: String
            if let slug = article.slug {
                articleSlug = slug
            }
            else {
                articleSlug = article.id.uuidString
            }
            let articleExternalLink: String?
            if let externalLink = article.externalLink {
                articleExternalLink = externalLink
            }
            else {
                articleExternalLink = nil
            }
            let articleNavigationWeight = article.navigationWeight ?? 1
            if let included = article.isIncludedInNavigation, included {
                return NavigationItem(
                    id: article.id.uuidString,
                    title: article.title,
                    slug: articleSlug,
                    externalLink: articleExternalLink,
                    weight: articleNavigationWeight
                )
            }
            return nil
        }
        navigation.sort(by: { $0.weight < $1.weight })
        return navigation
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

    let juiceboxEnabled: Bool?
    let juiceboxProjectID: Int?
    let juiceboxProjectIDGoerli: Int?

    let twitterUsername: String?
    let githubUsername: String?
    let telegramUsername: String?
    let mastodonUsername: String?

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
    let authorName: String?
    let ipns: String
    let created: Date
    let updated: Date
    let lastPublished: Date?
    let lastPublishedCID: String?
    let archived: Bool?
    let archivedAt: Date?
    let templateName: String
    let plausibleEnabled: Bool?
    let plausibleDomain: String?
    let plausibleAPIKey: String?
    let plausibleAPIServer: String?
    let twitterUsername: String?
    let githubUsername: String?
    let telegramUsername: String?
    let mastodonUsername: String?
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
    let juiceboxEnabled: Bool?
    let juiceboxProjectID: Int?
    let juiceboxProjectIDGoerli: Int?
    let articles: [BackupArticleModel]
}
