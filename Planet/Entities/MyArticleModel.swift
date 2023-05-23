import AVKit
import Foundation
import SwiftUI

class MyArticleModel: ArticleModel, Codable {
    @Published var articleType: ArticleType? = .blog

    @Published var link: String
    @Published var slug: String? = nil
    @Published var externalLink: String? = nil

    @Published var summary: String? = nil

    @Published var isIncludedInNavigation: Bool? = false
    @Published var navigationWeight: Int? = 1

    var cids: [String: String]? = [:]

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
            created: created,
            hasVideo: hasVideo,
            videoFilename: videoFilename,
            hasAudio: hasAudio,
            audioFilename: audioFilename,
            audioDuration: getAudioDuration(name: audioFilename),
            audioByteLength: getAttachmentByteLength(name: audioFilename),
            attachments: attachments,
            heroImage: socialImageURL?.absoluteString,
            cids: cids
        )
    }
    var browserURL: URL? {
        var urlPath = "/\(id.uuidString)/"
        if let slug = slug, slug.count > 0 {
            urlPath = "/\(slug)/"
        }
        if let domain = planet.domain {
            if domain.hasSuffix(".eth") {
                return URL(string: "https://\(domain).limo\(urlPath)")
            }
            if domain.hasSuffix(".bit") {
                return URL(string: "https://\(domain).cc\(urlPath)")
            }
            if domain.hasCommonTLDSuffix() {
                return URL(string: "https://\(domain)\(urlPath)")
            }
        }
        return URL(string: "\(IPFSDaemon.preferredGateway())/ipns/\(planet.ipns)\(urlPath)")
    }
    var socialImageURL: URL? {
        if let heroImage = getHeroImage(), let baseURL = browserURL {
            return baseURL.appendingPathComponent(heroImage)
        }
        return nil
    }

    enum CodingKeys: String, CodingKey {
        case id, articleType,
            link, slug, externalLink,
            title, content, summary,
            created, starred, starType,
            videoFilename, audioFilename,
            attachments, cids,
            isIncludedInNavigation,
            navigationWeight
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
        externalLink = try container.decodeIfPresent(String.self, forKey: .externalLink)
        let title = try container.decode(String.self, forKey: .title)
        let content = try container.decode(String.self, forKey: .content)
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
        cids = try container.decodeIfPresent([String: String].self, forKey: .cids)
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
        try container.encodeIfPresent(externalLink, forKey: .externalLink)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
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
    }

    init(
        id: UUID,
        link: String,
        slug: String? = nil,
        externalLink: String? = nil,
        title: String,
        content: String,
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
        self.externalLink = externalLink
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

    func getAttachmentURL(name: String) -> URL? {
        let path = publicBasePath.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: path.path) {
            return path
        }
        return nil
    }

    func getAttachmentByteLength(name: String?) -> Int? {
        guard let name = name, let url = getAttachmentURL(name: name) else {
            return nil
        }
        do {
            let attr = try FileManager.default.attributesOfItem(atPath: url.path)
            return attr[.size] as? Int
        }
        catch {
            return nil
        }
    }

    func getCIDs() -> [String: String] {
        if let attachments = self.attachments, attachments.count > 0 {
            var cids: [String: String] = [:]
            for attachment in attachments {
                if let attachmentURL = getAttachmentURL(name: attachment) {
                    if let attachmentCID = try? IPFSDaemon.shared.getFileCIDv0(url: attachmentURL) {
                        debugPrint("CID for \(attachment): \(attachmentCID)")
                        cids[attachment] = attachmentCID
                    }
                    else {
                        debugPrint("Unable to determine CID for \(attachment)")
                    }
                }
            }
            return cids
        }
        return [:]
    }

    func getNFTJSONCID() -> String? {
        if let nftJSONURL = getAttachmentURL(name: "nft.json") {
            if let nftJSONCID = try? IPFSDaemon.shared.getFileCIDv0(url: nftJSONURL) {
                debugPrint("CIDv0 for NFT metadata nft.json: \(nftJSONCID)")
                return nftJSONCID
            }
            else {
                debugPrint("Unable to determine CIDv0 for NFT metadata nft.json")
            }
        }
        return nil
    }

    func getAudioDuration(name: String?) -> Int? {
        guard let name = name, let url = getAttachmentURL(name: name) else {
            return nil
        }
        let asset = AVURLAsset(url: url)
        let duration = asset.duration
        return Int(CMTimeGetSeconds(duration))
    }

    func getHeroImage() -> String? {
        if self.hasVideoContent() {
            return "_videoThumbnail.png"
        }
        debugPrint("HeroImage: finding from \(attachments)")
        let images: [String]? = attachments?.compactMap {
            let imageNameLowercased = $0.lowercased()
            if imageNameLowercased.hasSuffix(".avif") || imageNameLowercased.hasSuffix(".jpeg")
                || imageNameLowercased.hasSuffix(".jpg") || imageNameLowercased.hasSuffix(".png")
                || imageNameLowercased.hasSuffix(".webp") || imageNameLowercased.hasSuffix(".gif")
                || imageNameLowercased.hasSuffix(".tiff")
            {
                return $0
            }
            else {
                return nil
            }
        }
        debugPrint("HeroImage candidates: \(images?.count) \(images)")
        var firstImage: String? = nil
        if let items = images {
            for item in items {
                let imagePath = publicBasePath.appendingPathComponent(item, isDirectory: false)
                if let url = URL(string: imagePath.absoluteString) {
                    debugPrint("HeroImage: checking size of \(url.absoluteString)")
                    if let image = NSImage(contentsOf: url) {
                        if firstImage == nil {
                            firstImage = item
                        }
                        debugPrint("HeroImage: created NSImage from \(url.absoluteString)")
                        debugPrint("HeroImage: candidate size: \(image.size)")
                        if image.size.width >= 600 && image.size.height >= 400 {
                            debugPrint("HeroImage: \(item)")
                            return item
                        }
                    }
                }
                else {
                    debugPrint("HeroImage: invalid URL for item: \(item) \(imagePath)")
                }
            }
        }
        if firstImage != nil {
            debugPrint("HeroImage: return the first image anyway: \(firstImage)")
            return firstImage
        }
        debugPrint("HeroImage: NOT FOUND")
        return nil
    }

    func savePublic() throws {
        guard let template = planet.template else {
            throw PlanetError.MissingTemplateError
        }
        defer {
            Task { @MainActor in
                debugPrint("Sending notification: myArticleBuilt \(self.id) \(self.title)")
                NotificationCenter.default.post(name: .myArticleBuilt, object: self)
            }
        }
        var attachmentCIDs: [String: String] = self.cids ?? [:]
        let needsToUpdateCIDs = {
            if let cids = self.cids, cids.count > 0 {
                for attachment in self.attachments ?? [] {
                    if cids[attachment] == nil {
                        return true
                    }
                    if let cid = cids[attachment], cid.hasPrefix("Qm") == false {
                        return true
                    }
                }
                return false
            }
            return true
        }()
        if needsToUpdateCIDs {
            debugPrint("CID Update for \(self.title): NEEDED")
            attachmentCIDs = getCIDs()
            self.cids = attachmentCIDs
            try? self.save()
        } else {
            debugPrint("CID Update for \(self.title): NOT NEEDED")
        }
        if attachmentCIDs.count > 0, let firstKeyValuePair = attachmentCIDs.first,
            let generateNFTMetadata = template.generateNFTMetadata, generateNFTMetadata
        {
            debugPrint("Writing NFT metadata for \(self.title) \(cids)")
            let (firstKey, firstValue) = firstKeyValuePair
            let nft = NFTMetadata(
                name: self.title,
                description: self.summary ?? firstKey,
                image: "https://ipfs.io/ipfs/\(firstValue)",
                external_url: (self.externalLink ?? self.browserURL?.absoluteString) ?? ""
            )
            let nftData = try JSONEncoder.shared.encode(nft)
            try nftData.write(to: publicNFTMetadataPath)
            let nftMetadataCID = self.getNFTJSONCID()
            debugPrint("NFT metadata CID: \(nftMetadataCID ?? "nil")")
            let nftMetadataCIDPath = publicBasePath.appendingPathComponent("nft.json.cid.txt")
            try? nftMetadataCID?.write(to: nftMetadataCIDPath, atomically: true, encoding: .utf8)
        }
        else {
            debugPrint(
                "Not writing NFT metadata for \(self.title) and CIDs: \(self.cids) \(template.generateNFTMetadata)"
            )
        }
        let articleHTML = try template.render(article: self)
        try articleHTML.data(using: .utf8)?.write(to: publicIndexPath)
        if self.hasVideoContent() {
            self.saveVideoThumbnail()
        }
        if self.hasHeroImage() || self.hasVideoContent() {
            self.saveHeroGrid()
        }
        try JSONEncoder.shared.encode(publicArticle).write(to: publicInfoPath)
        if let articleSlug = self.slug, articleSlug.count > 0 {
            let publicSlugBasePath = planet.publicBasePath.appendingPathComponent(
                articleSlug,
                isDirectory: true
            )
            if FileManager.default.fileExists(atPath: publicSlugBasePath.path) {
                try? FileManager.default.removeItem(at: publicSlugBasePath)
            }
            try? FileManager.default.copyItem(at: publicBasePath, to: publicSlugBasePath)
        }
    }

    func save() throws {
        try JSONEncoder.shared.encode(self).write(to: path)
    }

    func removeSlug(_ slugToRemove: String) {
        let slugPath = planet.publicBasePath.appendingPathComponent(
            slugToRemove,
            isDirectory: true
        )
        if FileManager.default.fileExists(atPath: slugPath.path) {
            try? FileManager.default.removeItem(at: slugPath)
        }
    }

    func delete() {
        if let slug = self.slug, slug.count > 0 {
            self.removeSlug(slug)
        }
        planet.articles.removeAll { $0.id == id }
        try? FileManager.default.removeItem(at: path)
        try? FileManager.default.removeItem(at: publicBasePath)
    }

    func hasHeroImage() -> Bool {
        return self.getHeroImage() != nil
    }

    func hasVideoContent() -> Bool {
        return videoFilename != nil
    }

    func hasAudioContent() -> Bool {
        return audioFilename != nil
    }

    func saveVideoThumbnail() {
        guard let videoFilename = self.videoFilename else { return }
        let videoThumbnailFilename = "_videoThumbnail.png"
        let opKey = "\(self.id)-video-thumbnail-\(videoFilename)"
        if let op = self.planet.ops[opKey] {
            debugPrint("Video thumbnail operation for \(opKey) is already done at \(op)")
            return
        }
        let videoThumbnailPath = publicBasePath.appendingPathComponent(videoThumbnailFilename)
        if let thumbnail = self.getVideoThumbnail(),
            let data = thumbnail.PNGData
        {
            try? data.write(to: videoThumbnailPath)
        }
        Task { @MainActor in
            self.planet.ops[opKey] = Date()
        }
    }

    func saveHeroGrid() {
        guard let heroImageFilename = self.getHeroImage() else { return }
        let opKey = "\(self.id)-hero-grid-\(heroImageFilename)"
        if let op = self.planet.ops[opKey] {
            debugPrint("Hero grid operation for \(opKey) is already done at \(op)")
            return
        }
        let heroImagePath = publicBasePath.appendingPathComponent(
            heroImageFilename,
            isDirectory: false
        )
        guard let heroImage = NSImage(contentsOf: heroImagePath) else { return }
        let heroGridPNGFilename = "_grid.png"
        let heroGridPNGPath = publicBasePath.appendingPathComponent(heroGridPNGFilename)
        let heroGridJPEGFilename = "_grid.jpg"
        let heroGridJPEGPath = publicBasePath.appendingPathComponent(heroGridJPEGFilename)
        if let grid = heroImage.resizeSquare(maxLength: 512) {
            if let gridPNGData = grid.PNGData {
                try? gridPNGData.write(to: heroGridPNGPath)
            }
            if let gridJPEGData = grid.JPEGData {
                try? gridJPEGData.write(to: heroGridJPEGPath)
            }
        }
        Task { @MainActor in
            self.planet.ops[opKey] = Date()
        }
    }

    func getVideoThumbnail() -> NSImage? {
        if self.hasVideoContent() {
            guard let videoFilename = self.videoFilename else {
                return nil
            }
            do {
                let url = self.publicBasePath.appendingPathComponent(videoFilename)
                let asset = AVURLAsset(url: url)
                let imageGenerator = AVAssetImageGenerator(asset: asset)
                imageGenerator.appliesPreferredTrackTransform = true
                let cgImage = try imageGenerator.copyCGImage(
                    at: .zero,
                    actualTime: nil
                )
                return NSImage(cgImage: cgImage, size: .zero)
            }
            catch {
                print(error.localizedDescription)

                return nil
            }
        }
        return nil
    }
}

extension MyArticleModel {
    static var placeholder: MyArticleModel {
        MyArticleModel(
            id: UUID(),
            link: "/example/",
            slug: "/example/",
            externalLink: nil,
            title: "Example Article",
            content: "This is an example article.",
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
            } catch {
                debugPrint("TODO item toggled but failed to save for \(self.title): \(error)")
            }
        } else {
            debugPrint("TODO item not found for \(self.title)")
        }
    }
}

struct BackupArticleModel: Codable {
    let id: UUID
    let link: String
    let slug: String?
    let externalLink: String?
    let title: String
    let content: String
    let summary: String?
    let starred: Date?
    let starType: ArticleStarType
    let created: Date
    let videoFilename: String?
    let audioFilename: String?
    let attachments: [String]?
    let cids: [String: String]?
    let isIncludedInNavigation: Bool?
    let navigationWeight: Int?
}

struct NFTMetadata: Codable {
    let name: String
    let description: String
    let image: String
    let external_url: String
}
