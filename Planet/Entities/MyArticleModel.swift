import AVKit
import Foundation
import SwiftUI

class MyArticleModel: ArticleModel, Codable {
    @Published var articleType: ArticleType? = .blog

    @Published var link: String
    @Published var slug: String? = nil
    @Published var heroImage: String? = nil
    var heroImageWidth: Int? = nil
    var heroImageHeight: Int? = nil
    // TODO: Use more runtime flags to optimize the time to rebuild Planet
    /// hasHeroGrid is a runtime flag to indicate whether the article has a hero grid image on disk. It is not persisted in the article JSON file.
    @Published var hasHeroGrid: Bool = false
    @Published var externalLink: String? = nil

    /// Rendered HTML from content
    var contentRendered: String? = nil
    @Published var summary: String? = nil

    @Published var isIncludedInNavigation: Bool? = false
    @Published var navigationWeight: Int? = 1

    /// CIDv0 of attachments, useful for NFT metadata.
    var cids: [String: String]? = [:]

    var tags: [String: String]? = nil

    var originalSiteName: String? = nil
    var originalSiteDomain: String? = nil
    var originalPostID: String? = nil
    var originalPostDate: Date? = nil

    @Published var pinned: Date? = nil

    // populated when initializing
    unowned var planet: MyPlanetModel! = nil
    var draft: DraftModel? = nil

    lazy var path = planet.articlesPath.appendingPathComponent(
        "\(id.uuidString).json",
        isDirectory: false
    )
    lazy var publicBasePath = planet.publicBasePath.appendingPathComponent(
        id.uuidString,
        isDirectory: true
    )
    lazy var publicIndexPath = publicBasePath.appendingPathComponent(
        "index.html",
        isDirectory: false
    )
    lazy var publicSimplePath = publicBasePath.appendingPathComponent(
        "simple.html",
        isDirectory: false
    )
    lazy var publicMarkdownPath = publicBasePath.appendingPathComponent(
        "article.md",
        isDirectory: false
    )
    lazy var publicCoverImagePath = publicBasePath.appendingPathComponent(
        "_cover.png",
        isDirectory: false
    )
    lazy var publicInfoPath = publicBasePath.appendingPathComponent(
        "article.json",
        isDirectory: false
    )
    lazy var publicNFTMetadataPath = publicBasePath.appendingPathComponent(
        "nft.json",
        isDirectory: false
    )

    var publicArticle: PublicArticleModel {
        PublicArticleModel(
            articleType: articleType ?? .blog,
            id: id,
            link: {
                if let slug = slug, slug.count > 0 {
                    return "/\(slug)/"
                }
                return link
            }(),
            slug: slug ?? "",
            externalLink: externalLink ?? "",
            title: title,
            content: content,
            contentRendered: contentRendered,
            created: created,
            hasVideo: hasVideo,
            videoFilename: videoFilename,
            hasAudio: hasAudio,
            audioFilename: audioFilename,
            audioDuration: getAudioDuration(name: audioFilename),
            audioByteLength: getAttachmentByteLength(name: audioFilename),
            attachments: attachments,
            heroImage: socialImageURL?.absoluteString,
            heroImageWidth: heroImageWidth,
            heroImageHeight: heroImageHeight,
            heroImageURL: socialImageURL?.absoluteString,
            heroImageFilename: socialImageURL?.lastPathComponent,
            cids: cids,
            tags: tags,
            originalSiteName: originalSiteName,
            originalSiteDomain: originalSiteDomain,
            originalPostID: originalPostID,
            originalPostDate: originalPostDate,
            pinned: pinned
        )
    }
    var localGatewayURL: URL? {
        return URL(string: "\(IPFSState.shared.getGateway())/ipns/\(planet.ipns)/\(id.uuidString)/")
    }
    var localPreviewURL: URL? {
        // If API is enabled, use the API URL
        // Otherwise, use the local gateway URL
        let apiEnabled = UserDefaults.standard.bool(forKey: String.settingsAPIEnabled)
        if apiEnabled {
            let apiPort =
                UserDefaults
                .standard.string(forKey: String.settingsAPIPort) ?? "8086"
            return URL(
                string:
                    "http://127.0.0.1:\(apiPort)/v0/planets/my/\(planet.id.uuidString)/public/\(id.uuidString)/index.html"
            )
        }
        else {
            return localGatewayURL
        }
    }
    /// The URL that can be viewed and shared in a regular browser.
    var browserURL: URL? {
        var urlPath = "/\(id.uuidString)/"
        if let slug = slug, slug.count > 0 {
            urlPath = "/\(slug)/"
        }
        if let domain = planet.domain {
            if domain.hasSuffix(".eth") {
                switch IPFSGateway.selectedGateway() {
                case .limo:
                    return URL(string: "https://\(domain).limo\(urlPath)")
                case .sucks:
                    return URL(string: "https://\(domain).sucks\(urlPath)")
                case .croptop:
                    let name = domain.replacingOccurrences(of: ".eth", with: "")
                    return URL(string: "https://\(name).crop.top\(urlPath)")
                case .dweblink:
                    return URL(string: "https://dweb.link/ipns/\(domain)\(urlPath)")
                }
            }
            if domain.hasSuffix(".bit") {
                return URL(string: "https://\(domain).site\(urlPath)")
            }
            if domain.hasCommonTLDSuffix() {
                return URL(string: "https://\(domain)\(urlPath)")
            }
        }
        switch IPFSGateway.selectedGateway() {
        case .limo:
            return URL(string: "https://\(planet.ipns).ipfs2.eth.limo\(urlPath)")
        case .sucks:
            return URL(string: "https://\(planet.ipns).eth.sucks\(urlPath)")
        case .croptop:
            return URL(string: "https://\(planet.ipns).crop.top\(urlPath)")
        case .dweblink:
            return URL(string: "https://dweb.link/ipns/\(planet.ipns)\(urlPath)")
        }
    }
    var socialImageURL: URL? {
        if let heroImage = getHeroImage(), let baseURL = browserURL {
            return baseURL.appendingPathComponent(heroImage)
        }
        return nil
    }
    var attachmentURLs: [URL] {
        var urls: [URL] = []
        if let attachments = attachments {
            for attachment in attachments {
                if let url = getAttachmentURL(name: attachment) {
                    urls.append(url)
                }
            }
        }
        if let videoFilename = videoFilename {
            if let url = getAttachmentURL(name: videoFilename) {
                // move video URL the first item (it's already in the urls array)
                if let index = urls.firstIndex(of: url) {
                    urls.remove(at: index)
                }
                urls.insert(url, at: 0)
            }
        }
        return urls
    }
    var videoURL: URL? {
        if let videoFilename = videoFilename {
            return getAttachmentURL(name: videoFilename)
        }
        return nil
    }
    var hasGIF: Bool {
        for attachment in attachments ?? [] {
            if attachment.hasSuffix(".gif") {
                return true
            }
        }
        return false
    }

    enum CodingKeys: String, CodingKey {
        case id, articleType,
            link, slug, heroImage, heroImageWidth, heroImageHeight, externalLink,
            title, content, contentRendered, summary,
            created, starred, starType,
            videoFilename, audioFilename,
            attachments, cids, tags,
            isIncludedInNavigation,
            navigationWeight,
            originalSiteName, originalSiteDomain, originalPostID, originalPostDate,
            pinned
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        if let articleType = try container.decodeIfPresent(ArticleType.self, forKey: .articleType) {
            self.articleType = articleType
        }
        else {
            self.articleType = .blog
        }
        link = try container.decode(String.self, forKey: .link)
        slug = try container.decodeIfPresent(String.self, forKey: .slug)
        heroImage = try container.decodeIfPresent(String.self, forKey: .heroImage)
        heroImageWidth = try container.decodeIfPresent(Int.self, forKey: .heroImageWidth)
        heroImageHeight = try container.decodeIfPresent(Int.self, forKey: .heroImageHeight)
        externalLink = try container.decodeIfPresent(String.self, forKey: .externalLink)
        let title = try container.decode(String.self, forKey: .title)
        let content = try container.decode(String.self, forKey: .content)
        contentRendered = try container.decodeIfPresent(String.self, forKey: .contentRendered)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        isIncludedInNavigation =
            try container.decodeIfPresent(Bool.self, forKey: .isIncludedInNavigation) ?? false
        navigationWeight = try container.decodeIfPresent(Int.self, forKey: .navigationWeight)
        let created = try container.decode(Date.self, forKey: .created)
        let starred = try container.decodeIfPresent(Date.self, forKey: .starred)
        let starType: ArticleStarType =
            try container.decodeIfPresent(ArticleStarType.self, forKey: .starType) ?? .star
        let videoFilename = try container.decodeIfPresent(String.self, forKey: .videoFilename)
        let audioFilename = try container.decodeIfPresent(String.self, forKey: .audioFilename)
        let attachments = try container.decodeIfPresent([String].self, forKey: .attachments)
        cids = try? container.decodeIfPresent([String: String].self, forKey: .cids) ?? [:]
        tags = try? container.decodeIfPresent([String: String].self, forKey: .tags) ?? [:]
        originalSiteName = try? container.decodeIfPresent(String.self, forKey: .originalSiteName)
        originalSiteDomain = try? container.decodeIfPresent(
            String.self,
            forKey: .originalSiteDomain
        )
        originalPostID = try? container.decodeIfPresent(String.self, forKey: .originalPostID)
        originalPostDate = try? container.decodeIfPresent(Date.self, forKey: .originalPostDate)
        pinned = try? container.decodeIfPresent(Date.self, forKey: .pinned)
        super.init(
            id: id,
            title: title,
            content: content,
            created: created,
            starred: starred,
            starType: starType,
            videoFilename: videoFilename,
            audioFilename: audioFilename,
            attachments: attachments
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(articleType, forKey: .articleType)
        try container.encode(link, forKey: .link)
        try container.encodeIfPresent(slug, forKey: .slug)
        try container.encodeIfPresent(heroImage, forKey: .heroImage)
        try container.encodeIfPresent(heroImageWidth, forKey: .heroImageWidth)
        try container.encodeIfPresent(heroImageHeight, forKey: .heroImageHeight)
        try container.encodeIfPresent(externalLink, forKey: .externalLink)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(contentRendered, forKey: .contentRendered)
        try container.encode(summary, forKey: .summary)
        try container.encodeIfPresent(isIncludedInNavigation, forKey: .isIncludedInNavigation)
        try container.encodeIfPresent(navigationWeight, forKey: .navigationWeight)
        try container.encode(created, forKey: .created)
        try container.encodeIfPresent(starred, forKey: .starred)
        try container.encodeIfPresent(starType, forKey: .starType)
        try container.encodeIfPresent(videoFilename, forKey: .videoFilename)
        try container.encodeIfPresent(audioFilename, forKey: .audioFilename)
        try container.encodeIfPresent(attachments, forKey: .attachments)
        try container.encodeIfPresent(cids, forKey: .cids)
        try container.encodeIfPresent(tags, forKey: .tags)
        try container.encodeIfPresent(originalSiteName, forKey: .originalSiteName)
        try container.encodeIfPresent(originalSiteDomain, forKey: .originalSiteDomain)
        try container.encodeIfPresent(originalPostID, forKey: .originalPostID)
        try container.encodeIfPresent(originalPostDate, forKey: .originalPostDate)
        try container.encodeIfPresent(pinned, forKey: .pinned)
    }

    init(
        id: UUID,
        link: String,
        slug: String? = nil,
        heroImage: String? = nil,
        externalLink: String? = nil,
        title: String,
        content: String,
        contentRendered: String? = nil,
        summary: String?,
        created: Date,
        starred: Date?,
        starType: ArticleStarType,
        videoFilename: String?,
        audioFilename: String?,
        attachments: [String]?,
        isIncludedInNavigation: Bool? = false,
        navigationWeight: Int? = 1
    ) {
        self.link = link
        self.slug = slug
        self.heroImage = heroImage
        self.externalLink = externalLink
        self.contentRendered = contentRendered
        self.summary = summary
        self.isIncludedInNavigation = isIncludedInNavigation
        self.navigationWeight = navigationWeight
        super.init(
            id: id,
            title: title,
            content: content,
            created: created,
            starred: starred,
            starType: starType,
            videoFilename: videoFilename,
            audioFilename: audioFilename,
            attachments: attachments
        )
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
        let draftPath = planet.articleDraftsPath.appendingPathComponent(
            id.uuidString,
            isDirectory: true
        )
        if FileManager.default.fileExists(atPath: draftPath.path) {
            article.draft = try? DraftModel.load(from: draftPath, article: article)
        }
        let heroGridPath = article.publicBasePath.appendingPathComponent(
            "_grid.png",
            isDirectory: false
        )
        if FileManager.default.fileExists(atPath: heroGridPath.path) {
            article.hasHeroGrid = true
        }
        return article
    }

    static func compose(
        link: String?,
        date: Date = Date(),
        title: String,
        content: String,
        summary: String?,
        planet: MyPlanetModel
    ) throws -> MyArticleModel {
        let id = UUID()
        let article = MyArticleModel(
            id: id,
            link: link ?? "/\(id.uuidString)/",
            title: title,
            content: content,
            summary: summary,
            created: date,
            starred: nil,
            starType: .star,
            videoFilename: nil,
            audioFilename: nil,
            attachments: nil
        )
        article.planet = planet
        try FileManager.default.createDirectory(
            at: article.publicBasePath,
            withIntermediateDirectories: true
        )
        return article
    }

    static func reorder(
        a: MyArticleModel,
        b: MyArticleModel
    ) -> Bool {
        switch (a.pinned, b.pinned) {
        case (nil, nil):  // Both articles are not pinned, sort by created date
            return a.created > b.created
        case (nil, _):  // Only the first article is not pinned, the second one goes first
            return false
        case (_, nil):  // Only the second article is not pinned, the first one goes first
            return true
        case (_, _):  // Both articles are pinned, sort by pinned date
            if let pinned1 = a.pinned, let pinned2 = b.pinned {
                return pinned1 > pinned2
            }
            else {
                return a.created > b.created
            }
        }
    }

    // MARK: Prewarm

    func prewarm() async {
        guard let postURL = browserURL else { return }
        let articleJSONURL = postURL.appendingPathComponent("article.json")
        // post page: /UUID/ or /slug/
        do {
            debugPrint("About to prewarm \(planet.name) post: \(postURL)")
            let (postData, _) = try await URLSession.shared.data(from: postURL)
            debugPrint("Prewarmed \(planet.name) post: \(postData.count) bytes")
        }
        catch {
            debugPrint("Failed to prewarm \(planet.name) post \(postURL): \(error)")
        }
        // metadata: /UUID/article.json or /slug/article.json
        do {
            debugPrint("About to prewarm \(planet.name) post metadata: \(articleJSONURL)")
            let (articleJSONData, _) = try await URLSession.shared.data(from: articleJSONURL)
            debugPrint("Prewarmed \(planet.name) post metadata: \(articleJSONData.count) bytes")
        }
        catch {
            debugPrint("Failed to prewarm \(planet.name) post metadata \(articleJSONURL): \(error)")
        }
        // tags
        if let tags = tags, tags.count > 0, let planetRootURL = planet.browserURL {
            let tagsURL = planetRootURL.appendingPathComponent("tags.html")
            Task.detached(priority: .background) {
                do {
                    debugPrint("About to prewarm \(self.planet.name) tags: \(tagsURL)")
                    let (tagsData, _) = try await URLSession.shared.data(from: tagsURL)
                    debugPrint("Prewarmed \(self.planet.name) tags: \(tagsData.count) bytes")
                }
                catch {
                    debugPrint("Failed to prewarm \(self.planet.name) tags \(tagsURL): \(error)")
                }
            }
        }
        // archive
        if let archiveURL = planet.browserURL?.appendingPathComponent("archive.html") {
            Task.detached(priority: .background) {
                do {
                    debugPrint("About to prewarm \(self.planet.name) archive: \(archiveURL)")
                    let (archiveData, _) = try await URLSession.shared.data(from: archiveURL)
                    debugPrint("Prewarmed \(self.planet.name) archive: \(archiveData.count) bytes")
                }
                catch {
                    debugPrint("Failed to prewarm \(self.planet.name) archive \(archiveURL): \(error)")
                }
            }
        }
        // attachments
        Task.detached(priority: .background) {
            if let attachments = self.attachments {
                for attachment in attachments {
                    let attachmentURL = postURL.appendingPathComponent(attachment)
                    do {
                        debugPrint("About to prewarm \(self.planet.name) attachment: \(attachmentURL)")
                        let (attachmentData, _) = try await URLSession.shared.data(
                            from: attachmentURL
                        )
                        debugPrint(
                            "Prewarmed \(self.planet.name) attachment: \(attachmentData.count) bytes"
                        )
                    }
                    catch {
                        debugPrint(
                            "Failed to prewarm \(self.planet.name) attachment \(attachmentURL): \(error)"
                        )
                    }
                }
            }
            if let videoFilename = self.videoFilename {
                let videoThumbnailURL = postURL.appendingPathComponent("_videoThumbnail.png")
                do {
                    debugPrint(
                        "About to prewarm \(self.planet.name) video thumbnail: \(videoThumbnailURL)"
                    )
                    let (videoThumbnailData, _) = try await URLSession.shared.data(
                        from: videoThumbnailURL
                    )
                    debugPrint(
                        "Prewarmed \(self.planet.name) video thumbnail: \(videoThumbnailData.count) bytes"
                    )
                }
                catch {
                    debugPrint(
                        "Failed to prewarm \(self.planet.name) video thumbnail \(videoThumbnailURL): \(error)"
                    )
                }
            }
            if self.hasHeroGrid {
                let heroGridURL = postURL.appendingPathComponent("_grid.png")
                do {
                    debugPrint("About to prewarm \(self.planet.name) hero grid: \(heroGridURL)")
                    let (heroGridData, _) = try await URLSession.shared.data(from: heroGridURL)
                    debugPrint("Prewarmed \(self.planet.name) hero grid: \(heroGridData.count) bytes")
                }
                catch {
                    debugPrint(
                        "Failed to prewarm \(self.planet.name) hero grid \(heroGridURL): \(error)"
                    )
                }
            }
        }
    }

    // MARK: Attachment

    /// Get the on-disk URL of an attachment from its file name.
    func getAttachmentURL(name: String) -> URL? {
        let path = publicBasePath.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: path.path) {
            return path
        }
        return nil
    }

    /// If the article:
    ///   - Has no attachments
    ///   - Is not a page
    ///   - Not included in navigation
    /// Used by article item view.
    func hasNoSpecialContent() -> Bool {
        let attachmentsCount = self.attachments?.count ?? 0
        let isPage = self.articleType == .page ? true : false
        let isIncludedInNavigation = self.isIncludedInNavigation ?? false
        return attachmentsCount == 0 && !isPage && !isIncludedInNavigation
    }

    func isAggregated() -> Bool {
        if let originalSiteDomain = originalSiteDomain, originalSiteDomain.count > 0 {
            return true
        }
        return false
    }

    /// If the article is aggregated from a remote source, it can't be edited.
    func canEdit() -> Bool {
        if let originalSiteDomain = originalSiteDomain, originalSiteDomain.count > 0 {
            return false
        }
        return true
    }
}

extension MyArticleModel {
    static var placeholder: MyArticleModel {
        MyArticleModel(
            id: UUID(),
            link: "/example/",
            slug: "/example/",
            heroImage: nil,
            externalLink: nil,
            title: "Example Article",
            content: "This is an example article.",
            contentRendered: "This is an example article.",
            summary: "This is an example article.",
            created: Date(),
            starred: nil,
            starType: .star,
            videoFilename: nil,
            audioFilename: nil,
            attachments: nil
        )
    }

    func toggleToDoItem(item: String) {
        let components = item.split(separator: "-")
        guard let lastComponent = components.last else { return }
        guard let idx = Int(lastComponent) else { return }

        var lines = self.content.components(separatedBy: .newlines)
        var i = 0
        var found = false
        for (index, line) in lines.enumerated() {
            if line.starts(with: "- [ ] ") {
                i = i + 1
                if i == idx {
                    lines[index] = line.replacingOccurrences(of: "- [ ]", with: "- [x]")
                    found = true
                }
            }
            else if line.starts(with: "- [x] ") {
                i = i + 1
                if i == idx {
                    lines[index] = line.replacingOccurrences(of: "- [x]", with: "- [ ]")
                    found = true
                }
            }
        }
        if found {
            self.content = lines.joined(separator: "\n")
            do {
                try self.save()
                Task {
                    try self.savePublic()
                    NotificationCenter.default.post(name: .loadArticle, object: nil)
                }
                debugPrint("TODO item toggled and saved for \(self.title)")
            }
            catch {
                debugPrint("TODO item toggled but failed to save for \(self.title): \(error)")
            }
        }
        else {
            debugPrint("TODO item not found for \(self.title)")
        }
    }
}

struct NFTMetadata: Codable {
    let name: String
    let description: String
    let image: String
    let external_url: String
    let mimeType: String
    let animation_url: String?
    let attributes: [NFTAttribute]?
}

struct NFTAttribute: Codable {
    let trait_type: String
    let value: String
}
