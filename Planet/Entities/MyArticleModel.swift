import Foundation

class MyArticleModel: ArticleModel, Codable {
    @Published var link: String

    // populated when initializing
    unowned var planet: MyPlanetModel! = nil
    var draft: DraftModel? = nil

    lazy var path = planet.articlesPath.appendingPathComponent("\(id.uuidString).json", isDirectory: false)
    lazy var publicBasePath = planet.publicBasePath.appendingPathComponent(id.uuidString, isDirectory: true)
    lazy var publicIndexPath = publicBasePath.appendingPathComponent("index.html", isDirectory: false)

    var publicArticle: PublicArticleModel {
        PublicArticleModel(id: id, link: link, title: title, content: content, created: created, videoFilename: videoFilename)
    }
    var browserURL: URL? {
        URL(string: "\(IPFSDaemon.publicGateways[0])/ipns/\(planet.ipns)\(link)")
    }

    enum CodingKeys: String, CodingKey {
        case id, link, title, content, created, starred, videoFilename
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        link = try container.decode(String.self, forKey: .link)
        let title = try container.decode(String.self, forKey: .title)
        let content = try container.decode(String.self, forKey: .content)
        let created = try container.decode(Date.self, forKey: .created)
        let starred = try container.decodeIfPresent(Date.self, forKey: .starred)
        let videoFilename = try container.decodeIfPresent(String.self, forKey: .videoFilename)
        super.init(id: id,
                   title: title,
                   content: content,
                   created: created,
                   starred: starred,
                   videoFilename: videoFilename)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(link, forKey: .link)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encode(created, forKey: .created)
        try container.encodeIfPresent(starred, forKey: .starred)
        try container.encodeIfPresent(videoFilename, forKey: .videoFilename)
    }

    init(id: UUID, link: String, title: String, content: String, created: Date, starred: Date?, videoFilename: String?) {
        self.link = link
        super.init(id: id, title: title, content: content, created: created, starred: starred, videoFilename: videoFilename)
    }

    static func load(from filePath: URL, planet: MyPlanetModel) throws -> MyArticleModel {
        let filename = (filePath.lastPathComponent as NSString).deletingPathExtension
        guard let id = UUID(uuidString: filename) else {
            throw PlanetError.PersistenceError
        }
        let articleData = try Data(contentsOf: filePath)
        let article = try JSONDecoder.shared.decode(MyArticleModel.self, from: articleData)
        guard article.id == id else {
            throw PlanetError.PersistenceError
        }
        article.planet = planet
        let draftPath = planet.articleDraftsPath.appendingPathComponent(id.uuidString, isDirectory: true)
        if FileManager.default.fileExists(atPath: draftPath.path) {
            article.draft = try DraftModel.load(from: draftPath, article: article)
        }
        return article
    }

    static func compose(link: String?, title: String, content: String, planet: MyPlanetModel) throws -> MyArticleModel {
        let id = UUID()
        let article = MyArticleModel(
            id: id,
            link: link ?? "/\(id.uuidString)/",
            title: title,
            content: content,
            created: Date(),
            starred: nil,
            videoFilename: nil
        )
        article.planet = planet
        try FileManager.default.createDirectory(at: article.publicBasePath, withIntermediateDirectories: true)
        return article
    }

    func save() throws {
        let data = try JSONEncoder.shared.encode(self)
        try data.write(to: path)
    }

    func delete() {
        try? FileManager.default.removeItem(at: path)
        // try? FileManager.default.removeItem(at: publicBasePath)
    }
}

struct BackupArticleModel: Codable {
    let id: UUID
    let link: String
    let title: String
    let content: String
    let created: Date
    let videoFilename: String?
}
