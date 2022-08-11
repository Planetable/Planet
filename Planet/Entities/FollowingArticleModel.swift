import Foundation
import SwiftSoup

class FollowingArticleModel: ArticleModel, Codable {
    let link: String
    @Published var read: Date? = nil
    var summary: String? = nil

    // populated when initializing
    unowned var planet: FollowingPlanetModel! = nil

    lazy var path = planet.articlesPath.appendingPathComponent("\(id.uuidString).json", isDirectory: false)
    var webviewURL: URL? {
        switch planet.planetType {
        case .planet, .dnslink, .ens:
            if let cid = planet.cid {
                if let linkURL = URL(string: link),
                   linkURL.isHTTP {
                    // article from a feed with an absolute HTTP URL: https://vitalik.ca/general/2022/05/25/stable.html
                    // transform URL to load with IPFS
                    return URL(string: "\(IPFSDaemon.shared.gateway)/ipfs/\(cid)\(linkURL.pathQueryFragment)")
                }
                if link.starts(with: "/") {
                    // article from a native planet: /12345678-90AB-CDEF-1234-567890ABCDEF/
                    // OR
                    // article from a feed with relative URL prefixed with slash: /general/2022/05/25/stable.html
                    return URL(string: "\(IPFSDaemon.shared.gateway)/ipfs/\(cid)\(link)")
                }
                if let base = URL(string: "\(IPFSDaemon.shared.gateway)/ipfs/\(cid)/") {
                    // relative URL: index.html, ./index.html, etc.
                    return URL(string: link, relativeTo: base)?.absoluteURL
                }
            }
            return nil
        case .dns:
            if let planetLink = URL(string: planet.link) {
                // absolute URL in HTTP scheme: https://vitalik.ca/general/2022/05/25/stable.html
                // OR
                // relative URL: /general/2022/05/25/stable.html, index.html, ./index.html, etc.
                return URL(string: link, relativeTo: planetLink)?.absoluteURL
            }
            return nil
        }
    }
    var browserURL: URL? {
        switch planet.planetType {
        case .planet:
            // planet article link: /12345678-90AB-CDEF-1234-567890ABCDEF/
            return URL(string: "\(IPFSDaemon.publicGateways[0])/ipns/\(planet.link)\(link)")
        case .ens:
            if let linkURL = URL(string: link),
               linkURL.isHTTP {
                // article from a feed with an absolute HTTP URL: https://vitalik.ca/general/2022/05/25/stable.html
                // transform URL to load with limo
                return URL(string: "https://\(planet.link).limo\(linkURL.pathQueryFragment)")
            }
            if let limo = URL(string: "https://\(planet.link).limo") {
                // relative URL: /general/2022/05/25/stable.html, index.html, ./index.html, etc.
                return URL(string: link, relativeTo: limo)?.absoluteURL
            }
            return nil
        case .dnslink:
            return URL(string: link)?.absoluteURL
        case .dns:
            if let planetLink = URL(string: planet.link) {
                // absolute URL in HTTP scheme: https://vitalik.ca/general/2022/05/25/stable.html
                // OR
                // relative URL: /general/2022/05/25/stable.html, index.html, ./index.html, etc.
                return URL(string: link, relativeTo: planetLink)?.absoluteURL
            }
            return nil
        }
    }

    static func extractSummary(content: String?) -> String? {
        if let content = content {
            let doc = try? SwiftSoup.parseBodyFragment(content)
            let text = try? doc?.text()
            if let text = text {
                if text.count > 280 {
                    return text.prefix(280) + "..."
                } else {
                    return text
                }
            } else {
                if content.count > 280 {
                    return content.prefix(280) + "..."
                } else {
                    return content
                }
            }
        }
        return nil
    }

    static func extractSummary(article: FollowingArticleModel, planet: FollowingPlanetModel) -> String? {
        if article.content.count > 0 {
            if planet.planetType == .planet || planet.planetType == .ens {
                if let contentHTML = CMarkRenderer.renderMarkdownHTML(markdown: article.content), let summary = extractSummary(content: contentHTML) {
                    article.summary = summary
                }
            } else if planet.planetType == .dnslink || planet.planetType == .dns {
                if let summary = extractSummary(content: article.content) {
                    article.summary = summary
                }
            }
        }
        return nil
    }

    enum CodingKeys: String, CodingKey {
        case id, link, title, content, summary, created, read, starred, videoFilename, audioFilename, attachments
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        link = try container.decode(String.self, forKey: .link)
        let title = try container.decode(String.self, forKey: .title)
        let content = try container.decode(String.self, forKey: .content)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        let created = try container.decode(Date.self, forKey: .created)
        read = try container.decodeIfPresent(Date.self, forKey: .read)
        let starred = try container.decodeIfPresent(Date.self, forKey: .starred)
        let videoFilename = try container.decodeIfPresent(String.self, forKey: .videoFilename)
        let audioFilename = try container.decodeIfPresent(String.self, forKey: .audioFilename)
        let attachments = try container.decodeIfPresent([String].self, forKey: .attachments)
        super.init(id: id, title: title, content: content, created: created, starred: starred, videoFilename: videoFilename, audioFilename: audioFilename, attachments: attachments)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(link, forKey: .link)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(summary, forKey: .summary)
        try container.encode(created, forKey: .created)
        try container.encodeIfPresent(read, forKey: .read)
        try container.encodeIfPresent(starred, forKey: .starred)
        try container.encodeIfPresent(videoFilename, forKey: .videoFilename)
        try container.encodeIfPresent(audioFilename, forKey: .audioFilename)
        try container.encodeIfPresent(attachments, forKey: .attachments)
    }

    init(
        id: UUID,
        link: String,
        title: String,
        content: String,
        created: Date,
        read: Date?,
        starred: Date?,
        videoFilename: String?,
        audioFilename: String?,
        attachments: [String]?
    ) {
        self.link = link
        self.read = read
        self.summary = FollowingArticleModel.extractSummary(content: content)
        super.init(id: id, title: title, content: content, created: created, starred: starred, videoFilename: videoFilename, audioFilename: audioFilename, attachments: attachments)
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
        if article.summary == nil || article.summary?.count ?? 0 > 283 {
            article.summary = extractSummary(article: article, planet: planet)
            try? article.save()
        }
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
            videoFilename: publicArticle.videoFilename,
            audioFilename: publicArticle.audioFilename,
            attachments: publicArticle.attachments
        )
        article.summary = extractSummary(article: article, planet: planet)
        article.planet = planet

        return article
    }

    func getAttachmentURL(name: String) -> URL? {
        // must be a native planet to have an attachment
        if let base = webviewURL,
           base.absoluteString.hasSuffix("/") {
            return base.appendingPathComponent(name)
        }
        return nil
    }

    func save() throws {
        try JSONEncoder.shared.encode(self).write(to: path)
    }

    func delete() {
        try? FileManager.default.removeItem(at: path)
    }
}
