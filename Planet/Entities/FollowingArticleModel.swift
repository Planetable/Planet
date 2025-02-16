import Foundation
import SwiftSoup
import SwiftUI

class FollowingArticleModel: ArticleModel, Codable {
    var link: String
    @Published var read: Date? = nil {
        didSet {
            if oldValue == nil || read == nil {
                // send notification to set navigation subtitle
                NotificationCenter.default.post(name: .followingArticleReadChanged, object: self)
            }
        }
    }
    var summary: String? = nil

    // populated when initializing
    unowned var planet: FollowingPlanetModel! = nil

    lazy var path = planet.articlesPath.appendingPathComponent("\(id.uuidString).json", isDirectory: false)
    var webviewURL: URL? {
        debugPrint("Generating webviewURL: planet.type: \(planet.planetType) planet.link: \(planet.link) article.link: \(link)")
        switch planet.planetType {
        case .planet, .dnslink, .ens, .dotbit:
            if let cid = planet.cid {
                let gateway = IPFSState.shared.getGateway()
                if link.starts(with: "https://ipfs.io/ipns/") {
                    let local: String = "\(gateway)\(link.dropFirst(15))"
                    debugPrint("Converted to use local gateway: FROM \(link) TO \(local)")
                    debugPrint("When generating webviewURL, reached branch A1")
                    return URL(string: local)
                }
                if link.startsWithInternalGateway() {
                    let local: String = "\(gateway)\(link.dropFirst(22))"
                    debugPrint("Converted to use local gateway: FROM \(link) TO \(local)")
                    debugPrint("When generating webviewURL, reached branch A2")
                    return URL(string: local)
                }
                if let linkURL = URL(string: link),
                   linkURL.isHTTP {
                    // article from a feed with an absolute HTTP URL: https://vitalik.ca/general/2022/05/25/stable.html
                    // transform URL to load with IPFS
                    debugPrint("When generating webviewURL, reached branch B")
                    return URL(string: "\(gateway)/ipfs/\(cid)\(linkURL.pathQueryFragment)")?.absoluteURL
                }
                if link.starts(with: "/ipfs/Q") || link.starts(with: "/ipfs/b") {
                    debugPrint("When generating webviewURL, reached branch D")
                    return URL(string: "\(gateway)\(link)")
                }
                if link.starts(with: "/") {
                    // article from a native planet: /12345678-90AB-CDEF-1234-567890ABCDEF/
                    // OR
                    // article from a feed with relative URL prefixed with slash: /general/2022/05/25/stable.html
                    debugPrint("When generating webviewURL, reached branch C")
                    return URL(string: "\(gateway)/ipfs/\(cid)\(link)")
                }
                if let base = URL(string: "\(gateway)/ipfs/\(cid)/") {
                    // relative URL: index.html, ./index.html, etc.
                    debugPrint("When generating webviewURL, reached branch D")
                    return URL(string: link, relativeTo: base)?.absoluteURL
                }
            }
            debugPrint("When generating webviewURL, reached nil branch")
            return nil
        case .dns:
            if link.starts(with: "https://ipfs.io/ipns/") {
                let gateway = IPFSState.shared.getGateway()
                let local: String = "\(gateway)\(link.dropFirst(15))"
                debugPrint("Converted to use local gateway: FROM \(link) TO \(local)")
                return URL(string: local)
            }
            if let planetLink = URL(string: planet.link) {
                // absolute URL in HTTP scheme: https://vitalik.ca/general/2022/05/25/stable.html
                // OR
                // relative URL: /general/2022/05/25/stable.html, index.html, ./index.html, etc.
                return URL(string: link, relativeTo: planetLink)?.absoluteURL
            }
            return nil
        }
    }
    /// URL that can be viewed and shared in a regular browser.
    var browserURL: URL? {
        debugPrint("Generating browserURL: planet.type: \(planet.planetType) planet.link: \(planet.link) article.link: \(link)")
        switch planet.planetType {
        case .planet:
            // planet article link: /12345678-90AB-CDEF-1234-567890ABCDEF/
            switch IPFSGateway.selectedGateway() {
            case .limo:
                return URL(string: "https://\(planet.link).ipfs2.eth.limo\(link)")
            case .sucks:
                return URL(string: "https://\(planet.link).eth.sucks\(link)")
            case .croptop:
                return URL(string: "https://\(planet.link).crop.top\(link)")
            case .dweblink:
                return URL(string: "https://dweb.link/ipns/\(planet.link)\(link)")
            }
        case .ens:
            if let linkURL = URL(string: link),
               linkURL.isHTTP {
                // article from a feed with an absolute HTTP URL: https://vitalik.ca/general/2022/05/25/stable.html
                // transform URL to load with limo
                return URL(string: "https://\(planet.link).limo\(linkURL.pathQueryFragment)")
            }
            if planet.link.hasSuffix(".eth") && link.hasPrefix("/") {
                switch IPFSGateway.selectedGateway() {
                case .limo:
                    return URL(string: "https://\(planet.link).limo\(link)")
                case .sucks:
                    return URL(string: "https://\(planet.link).sucks\(link)")
                case .croptop:
                    let name = planet.link.dropLast(4)
                    return URL(string: "https://\(name).crop.top\(link)")
                case .dweblink:
                    return URL(string: "https://dweb.link/ipns/\(planet.link)\(link)")
                }
            }
            if let limo = URL(string: "https://\(planet.link).limo") {
                // relative URL: /general/2022/05/25/stable.html, index.html, ./index.html, etc.
                return URL(string: link, relativeTo: limo)?.absoluteURL
            }
            return nil
        case .dotbit:
            if let linkURL = URL(string: link),
               linkURL.isHTTP {
                // article from a feed with an absolute HTTP URL: https://vitalik.ca/general/2022/05/25/stable.html
                // transform URL to load with limo
                return URL(string: "https://\(planet.link).site\(linkURL.pathQueryFragment)")
            }
            if let gateway = URL(string: "https://\(planet.link).site") {
                // relative URL: /general/2022/05/25/stable.html, index.html, ./index.html, etc.
                return URL(string: link, relativeTo: gateway)?.absoluteURL
            }
            return nil
        case .dnslink:
            // TODO: Fix how type 0 planet was mishandled as a dnslink
            // FIXME: This issue still exists as of 2024-Feb-21
            if planet.link.count == 62, planet.link.starts(with: "k51"), link.starts(with: "/") {
                if link.hasPrefix("/ipfs/Q") || link.hasPrefix("/ipfs/b") || link.hasPrefix("/ipns/") {
                    return URL(string: "https://eth.sucks\(link)")
                }
                switch IPFSGateway.selectedGateway() {
                case .limo:
                    return URL(string: "https://\(planet.link).ipfs2.eth.limo\(link)")
                case .sucks:
                    return URL(string: "https://\(planet.link).eth.sucks\(link)")
                case .croptop:
                    return URL(string: "https://\(planet.link).crop.top\(link)")
                case .dweblink:
                    return URL(string: "https://dweb.link/ipns/\(planet.link)\(link)")
                }
            }
            if link.starts(with: "/"), !planet.link.contains("://") {
                return URL(string: "https://\(planet.link)\(link)")?.absoluteURL
            }
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
            if planet.planetType == .planet || planet.planetType == .ens || planet.planetType == .dotbit {
                if let contentHTML = CMarkRenderer.renderMarkdownHTML(markdown: article.content), let summary = extractSummary(content: contentHTML) {
                    return summary
                }
            } else if planet.planetType == .dnslink || planet.planetType == .dns {
                if let summary = extractSummary(content: article.content) {
                    return summary
                }
            }
        }
        return nil
    }

    enum CodingKeys: String, CodingKey {
        case id, link, title, content, summary, created, read, starred, starType, videoFilename, audioFilename, attachments
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
        let starType: ArticleStarType = try container.decodeIfPresent(ArticleStarType.self, forKey: .starType) ?? .star
        let videoFilename = try container.decodeIfPresent(String.self, forKey: .videoFilename)
        let audioFilename = try container.decodeIfPresent(String.self, forKey: .audioFilename)
        let attachments = try container.decodeIfPresent([String].self, forKey: .attachments)
        super.init(id: id, title: title, content: content, created: created, starred: starred, starType: starType, videoFilename: videoFilename, audioFilename: audioFilename, attachments: attachments)
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
        try container.encodeIfPresent(starType, forKey: .starType)
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
        starType: ArticleStarType = .star,
        videoFilename: String?,
        audioFilename: String?,
        attachments: [String]?
    ) {
        self.link = link
        self.read = read
        self.summary = FollowingArticleModel.extractSummary(content: content)
        super.init(id: id, title: title, content: content, created: created, starred: starred, starType: starType, videoFilename: videoFilename, audioFilename: audioFilename, attachments: attachments)
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
        let articleLink: String
        if publicArticle.link.startsWithInternalGateway() {
            let path = String(publicArticle.link.dropFirst(22))
            if path.hasPrefix("/ipfs/Qm"), path.count > (6 + 46) {
                articleLink = String(path.dropFirst(6 + 46))
            } else {
                articleLink = path
            }
        } else {
            articleLink = publicArticle.link
        }
        let article = FollowingArticleModel(
//            id: UUID(),
            id: publicArticle.id,
            link: articleLink,
            title: publicArticle.title,
            content: publicArticle.content,
            created: publicArticle.created,
            read: nil,
            starred: nil,
            starType: .star,
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
