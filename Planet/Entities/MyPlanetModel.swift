import Foundation
import SwiftUI
import os

class MyPlanetModel: PlanetModel, Codable {
    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "MyPlanet")

    let ipns: String
    @Published var updated: Date
    @Published var templateName: String
    @Published var lastPublished: Date?

    @Published var isPublishing = false

    // populated when initializing
    @Published var avatar: NSImage? = nil
    @Published var drafts: [NewArticleDraftModel]! = nil
    @Published var articles: [MyArticleModel]! = nil

    static let myPlanetsPath: URL = {
        // ~/Library/Containers/xyz.planetable.Planet/Data/Documents/Planet/My/
        let url = URLUtils.repoPath.appendingPathComponent("My", isDirectory: true)
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()
    lazy var basePath = Self.myPlanetsPath.appendingPathComponent(id.uuidString, isDirectory: true)
    lazy var infoPath = basePath.appendingPathComponent("Planet.json", isDirectory: false)
    lazy var articlesPath = basePath.appendingPathComponent("Articles", isDirectory: true)
    lazy var avatarPath = basePath.appendingPathComponent("Avatar.png", isDirectory: false)
    lazy var draftsPath = basePath.appendingPathComponent("Drafts", isDirectory: true)
    lazy var articleDraftsPath = articlesPath.appendingPathComponent("Drafts", isDirectory: true)

    static let publicPlanetsPath: URL = {
        // ~/Library/Containers/xyz.planetable.Planet/Data/Documents/Planet/Public/
        let url = URLUtils.repoPath.appendingPathComponent("Public", isDirectory: true)
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()
    lazy var publicBasePath = Self.publicPlanetsPath.appendingPathComponent(id.uuidString, isDirectory: true)
    lazy var publicInfoPath = publicBasePath.appendingPathComponent("planet.json", isDirectory: false)
    lazy var publicAvatarPath = publicBasePath.appendingPathComponent("avatar.png", isDirectory: false)
    lazy var publicIndexPath = publicBasePath.appendingPathComponent("index.html", isDirectory: false)
    lazy var publicAssetsPath = publicBasePath.appendingPathComponent("assets", isDirectory: true)

    var template: Template? {
        TemplateStore.shared[templateName]
    }
    var nameInitials: String {
        let initials = name.components(separatedBy: .whitespaces).map { $0.prefix(1).capitalized }.joined()
        return String(initials.prefix(2))
    }
    var browserURL: URL? {
        URL(string: "\(IPFSDaemon.publicGateways[0])/ipns/\(ipns)/")
    }

    enum CodingKeys: String, CodingKey {
        case id, name, about, ipns, created, updated, templateName, lastPublished
    }

    // `@Published` property wrapper invalidates default decode/encode implementation
    // plus we're doing class inheritance
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let name = try container.decode(String.self, forKey: .name)
        let about = try container.decode(String.self, forKey: .about)
        ipns = try container.decode(String.self, forKey: .ipns)
        let created = try container.decode(Date.self, forKey: .created)
        updated = try container.decode(Date.self, forKey: .updated)
        templateName = try container.decode(String.self, forKey: .templateName)
        lastPublished = try container.decodeIfPresent(Date.self, forKey: .lastPublished)
        super.init(id: id, name: name, about: about, created: created)
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
    }

    init(id: UUID, name: String, about: String, ipns: String, created: Date, updated: Date, templateName: String) {
        self.ipns = ipns
        self.updated = updated
        self.templateName = templateName
        super.init(id: id, name: name, about: about, created: created)
    }

    static func load(from directoryPath: URL) throws -> MyPlanetModel {
        guard let planetID = UUID(uuidString: directoryPath.lastPathComponent) else {
            // directory name is not a UUID
            throw PlanetError.PersistenceError
        }
        let planetPath = directoryPath.appendingPathComponent("Planet.json", isDirectory: false)
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
        planet.drafts = draftDirectories.compactMap { try? NewArticleDraftModel.load(from: $0, planet: planet) }

        let articleDirectory = directoryPath.appendingPathComponent("Articles", isDirectory: true)
        let articleFiles = try FileManager.default.contentsOfDirectory(
            at: articleDirectory,
            includingPropertiesForKeys: nil
        )
        planet.articles = articleFiles.compactMap { try? MyArticleModel.load(from: $0, planet: planet) }

        return planet
    }

    static func create(name: String, about: String, templateName: String) async throws -> MyPlanetModel {
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
            templateName: templateName
        )
        planet.avatar = nil
        planet.drafts = []
        planet.articles = []
        try FileManager.default.createDirectory(at: planet.basePath, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: planet.articlesPath, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: planet.publicBasePath, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: planet.draftsPath, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: planet.articleDraftsPath, withIntermediateDirectories: true)
        try planet.copyTemplateAssets()
        return planet
    }

    static func importBackup(from path: URL) async throws -> MyPlanetModel {
        let backupInfoPath = path.appendingPathComponent("planet.json", isDirectory: false)
        let backupAssetsPath = path.appendingPathComponent("assets", isDirectory: true)
        let backupIndexPath = path.appendingPathComponent("index.html", isDirectory: false)
        let backupPrivateKeyPath = path.appendingPathComponent("planet.key", isDirectory: false)
        let backupAvatarPath = path.appendingPathComponent("avatar.png", isDirectory: false)

        guard FileManager.default.fileExists(atPath: backupInfoPath.path),
              FileManager.default.fileExists(atPath: backupPrivateKeyPath.path)
        else {
            throw PlanetError.ImportPlanetError
        }

        let decoder = JSONDecoder()
        guard let data = try? Data.init(contentsOf: backupInfoPath),
              let backupPlanet = try? decoder.decode(BackupMyPlanetModel.self, from: data)
        else {
            throw PlanetError.ImportPlanetError
        }

        if await PlanetStore.shared.myPlanets.contains(where: { $0.id == backupPlanet.id }) {
            throw PlanetError.PlanetExistsError
        }

        do {
            // key may already exist in IPFS keystore, ignore error
            try IPFSCommand.importKey(name: backupPlanet.id.uuidString, target: backupPrivateKeyPath).run()
        } catch {
            throw PlanetError.IPFSError
        }

        let planet = MyPlanetModel(
            id: backupPlanet.id,
            name: backupPlanet.name,
            about: backupPlanet.about,
            ipns: backupPlanet.ipns,
            created: backupPlanet.created,
            updated: backupPlanet.updated,
            templateName: backupPlanet.templateName
        )

        // delete existing local planet file if exists
        if FileManager.default.fileExists(atPath: planet.publicBasePath.path) {
            try? FileManager.default.removeItem(at: planet.publicBasePath)
        }
        do {
            try FileManager.default.createDirectory(at: planet.publicBasePath, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: backupAssetsPath.path) {
                try FileManager.default.copyItem(at: backupAssetsPath, to: planet.publicAssetsPath)
            }
            if FileManager.default.fileExists(atPath: backupIndexPath.path) {
                try FileManager.default.copyItem(at: backupIndexPath, to: planet.publicIndexPath)
            }
            if FileManager.default.fileExists(atPath: backupAvatarPath.path) {
                try FileManager.default.copyItem(at: backupAvatarPath, to: planet.publicAvatarPath)
            }
        } catch {
            throw PlanetError.ImportPlanetError
        }

        planet.avatar = NSImage(contentsOf: planet.avatarPath)
        planet.drafts = []
        planet.articles = backupPlanet.articles.compactMap { backupArticle in
            let backupArticlePath = path.appendingPathComponent(backupArticle.link, isDirectory: true)
            if FileManager.default.fileExists(atPath: backupArticlePath.path) {
                let article = MyArticleModel(
                    id: backupArticle.id,
                    link: backupArticle.link,
                    title: backupArticle.title,
                    content: backupArticle.content,
                    created: backupArticle.created
                )
                article.planet = planet
                do {
                    try FileManager.default.copyItem(at: backupArticlePath, to: article.publicBasePath)
                    return article
                } catch {
                }
            }
            return nil
        }
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
        let publicArticles: [PublicArticleModel] = try articles.map { article in
            let publicArticle = article.publicArticle
            let articleHTML = try template.render(article: article)
            try articleHTML.data(using: .utf8)?.write(to: article.publicIndexPath)
            return publicArticle
        }
        let publicPlanet = PublicPlanetModel(
            name: name, about: about, ipns: ipns, created: created, updated: updated, articles: publicArticles
        )
        let indexHTML = try template.renderIndex(planet: publicPlanet)
        try indexHTML.data(using: .utf8)?.write(to: publicIndexPath)

        let info = try JSONEncoder.shared.encode(publicPlanet)
        try info.write(to: publicInfoPath)
    }

    func publish() async throws {
        isPublishing = true
        defer {
            isPublishing = false
        }
        let cid = try await IPFSDaemon.shared.addDirectory(url: publicBasePath)
        let result = try await IPFSDaemon.shared.api(path: "name/publish", args: [
            "arg": cid,
            "allow-offline": "1",
            "key": id.uuidString,
            "quieter": "1",
            "lifetime": "168h",
        ], timeout: 600)
        _ = try JSONDecoder.shared.decode(IPFSPublished.self, from: result)
        lastPublished = Date()
        try save()
    }

    func exportBackup(to directory: URL) throws {
        let exportPath = directory.appendingPathComponent("\(name.sanitized()).planet", isDirectory: true)
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
            templateName: templateName,
            articles: articles.map {
                BackupArticleModel(
                    id: $0.id,
                    link: $0.link,
                    title: $0.title,
                    content: $0.content,
                    created: $0.created
                )
            }
        )
        do {
            try FileManager.default.copyItem(at: publicBasePath, to: exportPath)

            // export private key from IPFS keystore
            let exportPrivateKeyPath = exportPath.appendingPathComponent("planet.key", isDirectory: false)
            let (ret, _, _) = try IPFSCommand.exportKey(name: id.uuidString, target: exportPrivateKeyPath).run()
            if ret != 0 {
                throw PlanetError.IPFSError
            }

            // override public planet info with backup planet info
            let backupPlanetInfoPath = exportPath.appendingPathComponent("planet.json", isDirectory: false)
            let backupPlanet = try JSONEncoder.shared.encode(backupPlanet)
            try backupPlanet.write(to: backupPlanetInfoPath)
        } catch {
            throw PlanetError.ExportPlanetError
        }

        NSWorkspace.shared.activateFileViewerSelecting([exportPath])
    }

    func save() throws {
        let data = try JSONEncoder.shared.encode(self)
        try data.write(to: infoPath)
        articles.forEach { try? $0.save() }
    }

    func delete() {
        try? FileManager.default.removeItem(at: basePath)
    }
}

struct BackupMyPlanetModel: Codable {
    let id: UUID
    let name: String
    let about: String
    let ipns: String
    let created: Date
    let updated: Date
    let templateName: String
    let articles: [BackupArticleModel]
}
