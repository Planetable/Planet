import Foundation

class FollowingArticleModel: ArticleModel, Codable {
    let link: String
    @Published var read: Date? = nil

    // populated when initializing
    unowned var planet: FollowingPlanetModel! = nil

    lazy var path = planet.articlesPath.appendingPathComponent("\(id.uuidString).json", isDirectory: false)
    var webviewURL: URL? {
        get async {
            if let linkURL = URL(string: link),
               linkURL.scheme?.lowercased() == "https" {
                return linkURL
            }
            if let cid = planet.cid {
                return URL(string: "\(await IPFSDaemon.shared.gateway)/ipfs/\(cid)\(link)")
            }
            if let planetLink = URL(string: planet.link) {
                return URL(string: link, relativeTo: planetLink)?.absoluteURL
            }
            return nil
        }
    }
    var browserURL: URL? {
        if let linkURL = URL(string: link),
           linkURL.scheme?.lowercased() == "https" {
            return linkURL
        }
        if let cid = planet.cid {
            return URL(string: "\(IPFSDaemon.publicGateways[0])/ipfs/\(cid)\(link)")
        }
        if let planetLink = URL(string: planet.link) {
            return URL(string: link, relativeTo: planetLink)?.absoluteURL
        }
        return nil
    }

    enum CodingKeys: String, CodingKey {
        case id, link, title, content, created, read, starred, videoFilename
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        link = try container.decode(String.self, forKey: .link)
        let title = try container.decode(String.self, forKey: .title)
        let content = try container.decode(String.self, forKey: .content)
        let created = try container.decode(Date.self, forKey: .created)
        read = try container.decodeIfPresent(Date.self, forKey: .read)
        let starred = try container.decodeIfPresent(Date.self, forKey: .starred)
        let videoFilename = try container.decodeIfPresent(String.self, forKey: .videoFilename)
        super.init(id: id, title: title, content: content, created: created, starred: starred, videoFilename: videoFilename)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(link, forKey: .link)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encode(created, forKey: .created)
        try container.encodeIfPresent(read, forKey: .read)
        try container.encodeIfPresent(starred, forKey: .starred)
        try container.encodeIfPresent(videoFilename, forKey: .videoFilename)
    }

    init(
        id: UUID,
        link: String,
        title: String,
        content: String,
        created: Date,
        read: Date?,
        starred: Date?,
        videoFilename: String?
    ) {
        self.link = link
        self.read = read
        super.init(id: id, title: title, content: content, created: created, starred: starred, videoFilename: videoFilename)
    }

    static func load(from filePath: URL, planet: FollowingPlanetModel) throws -> FollowingArticleModel {
        let filename = (filePath.lastPathComponent as NSString).deletingPathExtension
        guard let id = UUID(uuidString: filename) else {
            throw PlanetError.PersistenceError
        }
        let articleData = try Data(contentsOf: filePath)
        let article = try JSONDecoder.shared.decode(FollowingArticleModel.self, from: articleData)
        guard article.id == id else {
            throw PlanetError.PersistenceError
        }
        article.planet = planet
        return article
    }

    static func from(publicArticle: PublicArticleModel, planet: FollowingPlanetModel) -> FollowingArticleModel {
        let article = FollowingArticleModel(
            id: UUID(),
            link: publicArticle.link,
            title: publicArticle.title,
            content: publicArticle.content,
            created: publicArticle.created,
            read: nil,
            starred: nil,
            videoFilename: nil
        )
        article.planet = planet

        return article
    }

    func save() throws {
        try JSONEncoder.shared.encode(self).write(to: path)
    }

    func delete() {
        try? FileManager.default.removeItem(at: path)
    }
}
