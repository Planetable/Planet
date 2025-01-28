//
//  MyPlanetModel+Aggregate.swift
//  Planet
//
//  Created by Xin Liu on 11/18/23.
//

import Foundation
import SwiftSoup
import SwiftUI

enum AggregationEndpointType: Int, Codable, CaseIterable {
    case ipns = 1
    case ens = 2
    case http = 3
    case unknown = 99
}

/// Aggregate posts from other sites.
extension MyPlanetModel {
    /// Return site type based on its name, then call the appropriate fetch function.
    func determineSiteType(site: String) -> AggregationEndpointType {
        let s = site.lowercased()
        if s.hasPrefix("k51"), s.count == 62 {
            return .ipns
        }
        if s.hasSuffix(".eth"), s.count > 4 {
            return .ens
        }
        if s.hasPrefix("https://") || s.hasPrefix("http://") {
            return .http
        }
        return .unknown
    }

    @ViewBuilder
    func batchDeleteMenu() -> some View {
        if showBatchDeleteMenu() {
            Menu {
                ForEach(getUniqueOriginalSiteDomains(), id: \.self) { domain in
                    Button {
                        Task {
                            await self.batchDeletePosts(domain: domain)
                        }
                    } label: {
                        Text("Posts from \(domain)")
                            .badge(self.getPostCount(domain: domain))
                    }
                }
            } label: {
                Text("Batch Delete")
            }
        }
    }

    func showBatchDeleteMenu() -> Bool {
        // If any article's originalSiteDomain is not nil, show the menu
        return articles.contains(where: { $0.originalSiteDomain != nil })
    }

    func getUniqueOriginalSiteDomains() -> [String] {
        var domains: [String] = []
        for article in articles {
            if let domain = article.originalSiteDomain, !domains.contains(domain) {
                domains.append(domain)
            }
        }
        return domains
    }

    func getPostCount(domain: String) -> Int {
        var count: Int = 0
        for article in articles {
            if article.originalSiteDomain == domain {
                count += 1
            }
        }
        return count
    }

    func batchDeletePosts(domain: String) async {
        // Delete all articles with the given domain
        for article in articles {
            if article.originalSiteDomain == domain {
                article.delete()
            }
        }
        self.tags = self.consolidateTags()
        try? save()
        try? await savePublic()
        Task { @MainActor in
            PlanetStore.shared.refreshSelectedArticles()
        }
    }

    /// Entry function for aggregation.
    ///
    /// Three types of sources are supported:
    /// - IPNS: IPNS name like k51qzi5uqu5di63h1nsegh29khxqvi8rkc59tdq8o5s9b3sftt7rcvr4pdkgo8
    /// - ENS: ENS name like planetable.eth
    /// - HTTP: HTTP URL of RSS feed like https://example.com/feed.xml
    ///
    /// Currently discovering feeds from domains is not supported.
    func aggregate() async {
        if isAggregating {
            debugPrint("Planet \(name) is already aggregating, skipping")
            return
        }
        await MainActor.run {
            self.isAggregating = true
        }
        DispatchQueue.main.async {
            debugPrint("Aggregation: Started for \(self.name)")
            PlanetStore.shared.currentTaskMessage = "Fetching posts from other sites..."
            PlanetStore.shared.currentTaskProgressIndicator = .progress
            PlanetStore.shared.isAggregating = true
        }
        defer {
            DispatchQueue.main.async {
                debugPrint("Aggregation: Finished for \(self.name)")
                PlanetStore.shared.currentTaskMessage = "Aggregation completed"
                PlanetStore.shared.currentTaskProgressIndicator = .done
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    PlanetStore.shared.isAggregating = false
                }
            }
            Task { @MainActor in
                self.isAggregating = false
            }
        }
        guard let aggregation = aggregation, aggregation.count > 0 else {
            return
        }
        var newArticlesCount: Int = 0
        for site in aggregation {
            // Skip comments
            if site.hasPrefix("#") || site.hasPrefix("//") {
                continue
            }
            let siteType = determineSiteType(site: site)
            debugPrint("Aggregation: fetching \(site)")
            switch siteType {
            case .ipns:
                newArticlesCount += await fetchPlanetSite(site: site)
            case .ens:
                newArticlesCount += await fetchPlanetSite(site: site)
            case .http:
                newArticlesCount += await fetchHTTPSite(site: site)
            case .unknown:
                debugPrint("Site type is unknown: \(site)")
            }
        }
        let c = newArticlesCount
        if c > 0 {
            DispatchQueue.main.async {
                PlanetStore.shared.currentTaskProgressIndicator = .done
                PlanetStore.shared.currentTaskMessage = "\(c) new posts fetched"
            }
            self.tags = self.consolidateTags()
            try? save()
            try? await savePublic()
            // So the previous message can be seen for a while
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                PlanetStore.shared.currentTaskProgressIndicator = .progress
                PlanetStore.shared.currentTaskMessage = "Publishing \(self.name)..."
            }
            try? await publish()
            Task { @MainActor in
                PlanetStore.shared.refreshSelectedArticles()
            }
        }
    }

    @discardableResult
    func fetchArticleAttachments(
        in site: String,
        from article: PublicArticleModel,
        to newArticle: MyArticleModel
    ) async -> Int {
        var saved = 0
        var attachmentCount = 0
        let gateway = IPFSState.shared.getGateway()
        if let articleAttachments = article.attachments {
            attachmentCount = articleAttachments.count
        }
        if let articleAttachments = article.attachments,
            articleAttachments.count > 0
        {
            debugPrint(
                "Aggregation: \(article.title) has \(articleAttachments.count) attachments: \(articleAttachments)"
            )
            for name in articleAttachments {
                let targetPath = newArticle.publicBasePath.appendingPathComponent(
                    name,
                    isDirectory: false
                )
                if let attachmentBaseURL = URL(
                    string:
                        "\(gateway)/ipns/\(site)/\(article.id)/"
                ) {
                    let attachmentURL = attachmentBaseURL.appendingPathComponent(
                        name
                    )
                    debugPrint(
                        "Aggregation: downloading attachment \(attachmentURL.absoluteString)"
                    )
                    do {
                        let (attachmentData, _) = try await URLSession.shared.data(
                            from: attachmentURL
                        )
                        let existingAttachmentData = try? Data(contentsOf: targetPath)
                        var shouldSave = true
                        if let existingAttachmentData = existingAttachmentData {
                            if existingAttachmentData == attachmentData {
                                shouldSave = false
                            }
                        }
                        if shouldSave {
                            debugPrint(
                                "Aggregation: saving attachment \(name): \(attachmentData.count) bytes"
                            )
                            saved += 1
                            try attachmentData.write(to: targetPath)
                        }
                        else {
                            debugPrint(
                                "Aggregation: attachment \(name) is already saved"
                            )
                        }
                    }
                    catch {
                        debugPrint(
                            "Aggregation: failed to fetch \(name) from \(site): \(error)"
                        )
                    }
                }
            }
        }
        // In early versions, sometimes when attachments are empty, videoFilename is not nil, it should be treated as an attachment
        if attachmentCount == 0, let videoFilename = article.videoFilename, videoFilename.count > 0
        {
            debugPrint("Aggregation: \(article.title) has video \(videoFilename)")
            let targetPath = newArticle.publicBasePath.appendingPathComponent(
                videoFilename,
                isDirectory: false
            )
            if let attachmentBaseURL = URL(
                string:
                    "\(gateway)/ipns/\(site)/\(article.id)/"
            ) {
                let attachmentURL = attachmentBaseURL.appendingPathComponent(
                    videoFilename
                )
                debugPrint(
                    "Aggregation: downloading video \(attachmentURL.absoluteString)"
                )
                do {
                    let (attachmentData, _) = try await URLSession.shared.data(
                        from: attachmentURL
                    )
                    let existingAttachmentData = try? Data(contentsOf: targetPath)
                    var shouldSave = true
                    if let existingAttachmentData = existingAttachmentData {
                        if existingAttachmentData == attachmentData {
                            shouldSave = false
                        }
                    }
                    if shouldSave {
                        debugPrint(
                            "Aggregation: saving video \(videoFilename): \(attachmentData.count) bytes"
                        )
                        saved += 1
                        try attachmentData.write(to: targetPath)
                        newArticle.attachments = [videoFilename]
                    }
                    else {
                        debugPrint(
                            "Aggregation: video \(videoFilename) is already saved"
                        )
                    }
                }
                catch {
                    debugPrint(
                        "Aggregation: failed to fetch \(videoFilename) from \(site): \(error)"
                    )
                }
            }
        }
        return saved
    }

    func fetchPlanetSite(site: String) async -> Int {
        let gateway = IPFSState.shared.getGateway()
        var newArticles: [MyArticleModel] = []
        if let feedURL = URL(string: "\(gateway)/ipns/\(site)/planet.json") {
            do {
                let (planetJSONData, _) = try await URLSession.shared.data(from: feedURL)
                let planet = try JSONDecoder.shared.decode(
                    PublicPlanetModel.self,
                    from: planetJSONData
                )
                debugPrint("Aggregation: fetched \(site) with \(planet.articles.count) articles")
                for article in planet.articles {
                    if let existingArticle = self.articles.first(
                        where: { $0.originalPostID == article.id.uuidString })
                    {
                        // TODO: Update existing article
                        var changed = false
                        if existingArticle.link != "/\(existingArticle.id.uuidString)/" {
                            debugPrint(
                                "Aggregation: updating \(article.id) link from \(existingArticle.link) to /\(existingArticle.id.uuidString)/"
                            )
                            await MainActor.run {
                                existingArticle.link = "/\(existingArticle.id.uuidString)/"
                            }
                            changed = true
                        }
                        if existingArticle.title != article.title {
                            debugPrint(
                                "Aggregation: updating \(article.id) title from \(existingArticle.title) to \(article.title)"
                            )
                            await MainActor.run {
                                existingArticle.title = article.title
                            }
                            changed = true
                        }
                        if existingArticle.content != article.content {
                            debugPrint(
                                "Aggregation: updating \(article.id) content from \(existingArticle.content) to \(article.content)"
                            )
                            await MainActor.run {
                                existingArticle.content = article.content
                            }
                            changed = true
                        }
                        if existingArticle.tags != article.tags {
                            debugPrint(
                                "Aggregation: updating \(article.id) tags from \(existingArticle.tags) to \(article.tags)"
                            )
                            await MainActor.run {
                                existingArticle.tags = article.tags
                            }
                            changed = true
                        }
                        let savedAttachments = await fetchArticleAttachments(
                            in: site,
                            from: article,
                            to: existingArticle
                        )
                        if savedAttachments > 0 {
                            changed = true
                        }
                        if changed {
                            try existingArticle.save()
                            Task(priority: .utility) {
                                try existingArticle.savePublic()
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                PlanetStore.shared.refreshSelectedArticles()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                    NotificationCenter.default.post(name: .loadArticle, object: nil)
                                }
                            }
                        }
                    }
                    else {
                        debugPrint("Aggregation: adding \(article.id) from \(site)")
                        let heroImageName: String?
                        if let heroImage = article.heroImage {
                            if heroImage.hasPrefix("https://") || heroImage.hasPrefix("http://") {
                                // Get the last part of the URL
                                if let heroImageURL = URL(string: heroImage) {
                                    heroImageName = heroImageURL.lastPathComponent
                                }
                                else {
                                    heroImageName = nil
                                }
                            }
                            else {
                                heroImageName = heroImage
                            }
                        }
                        else {
                            heroImageName = nil
                        }
                        // TODO: Extract summary
                        // TODO: Reuse original ID is dangerous if user do not understand the full implications
                        let postID: UUID
                        if let reuseOriginalID = self.reuseOriginalID, reuseOriginalID == true {
                            postID = article.id
                        }
                        else {
                            postID = UUID()
                        }
                        let newArticle = MyArticleModel(
                            id: postID,
                            link: "/\(postID.uuidString)/",
                            slug: nil,
                            heroImage: heroImageName,
                            externalLink: article.externalLink,
                            title: article.title,
                            content: article.content,
                            summary: "",
                            created: article.created,
                            starred: nil,
                            starType: .star,
                            videoFilename: article.videoFilename,
                            audioFilename: article.audioFilename,
                            attachments: article.attachments
                        )
                        newArticle.tags = article.tags
                        newArticle.cids = article.cids
                        newArticle.originalSiteName = planet.name
                        newArticle.originalSiteDomain = site
                        newArticle.originalPostID = article.id.uuidString
                        newArticle.originalPostDate = article.created
                        newArticle.planet = self
                        try newArticle.save()
                        let publicBasePath = newArticle.publicBasePath
                        if !FileManager.default.fileExists(atPath: publicBasePath.path) {
                            try FileManager.default.createDirectory(
                                at: publicBasePath,
                                withIntermediateDirectories: true
                            )
                        }
                        // TODO: What if attachments are not saved?
                        // TODO: This does not work well on videos.
                        await fetchArticleAttachments(in: site, from: article, to: newArticle)
                        newArticles.append(newArticle)
                        Task(priority: .utility) {
                            try newArticle.savePublic()
                        }
                        DispatchQueue.main.async {
                            self.articles.append(newArticle)
                            self.articles.sort(by: { MyArticleModel.reorder(a: $0, b: $1) })
                            PlanetStore.shared.refreshSelectedArticles()
                        }
                    }
                }
                // Delete articles that are no longer in the original site
                var deleted = 0
                for article in self.articles {
                    if article.originalSiteDomain == site,
                        !planet.articles.contains(where: { $0.id.uuidString == article.originalPostID })
                    {
                        debugPrint("Aggregation: deleting \(article.originalPostID) from \(site)")
                        article.delete()
                        deleted += 1
                    }
                }
                if deleted > 0 {
                    self.tags = self.consolidateTags()
                    try? save()
                    try? await savePublic()
                    Task { @MainActor in
                        PlanetStore.shared.refreshSelectedArticles()
                    }
                }
            }
            catch {
                debugPrint("Aggregation: failed to fetch \(site): \(error)")
            }
        }
        return newArticles.count
    }

    func fetchHTTPSite(site: String) async -> Int {
        var newArticles: [MyArticleModel] = []
        if let feedURL = URL(string: site), let feedData = try? Data(contentsOf: feedURL) {
            do {
                let feed = try? await FeedUtils.parseFeed(data: feedData, url: feedURL)
                debugPrint("Aggregation: fetched \(site): \(feed)")
                for article in feed?.articles ?? [] {
                    if let articleURL = URL(string: article.link) {
                        let articleID = article.link
                        if !self.articles.contains(where: { $0.originalPostID == articleID }) {
                            debugPrint("Aggregation: adding \(articleID) from \(site)")
                            let newArticleID = UUID()
                            let newArticle = MyArticleModel(
                                id: newArticleID,
                                link: "/\(newArticleID.uuidString)/",
                                slug: nil,
                                heroImage: nil,
                                externalLink: article.link,
                                title: article.title,
                                content: article.content,
                                summary: "",
                                created: article.created,
                                starred: nil,
                                starType: .star,
                                videoFilename: nil,
                                audioFilename: nil,
                                attachments: []
                            )
                            newArticle.tags = [:]
                            newArticle.originalSiteName = feed?.name ?? articleURL.host
                            newArticle.originalSiteDomain = articleURL.host
                            newArticle.originalPostID = article.link
                            newArticle.originalPostDate = article.created
                            newArticle.planet = self
                            try newArticle.save()
                            let publicBasePath = newArticle.publicBasePath
                            if !FileManager.default.fileExists(atPath: publicBasePath.path) {
                                try FileManager.default.createDirectory(
                                    at: publicBasePath,
                                    withIntermediateDirectories: true
                                )
                            }
                            let (socialImageData, socialImageName) = await fetchSocialImage(
                                from: articleURL
                            )
                            if let socialImageData = socialImageData,
                                let socialImageName = socialImageName
                            {
                                debugPrint(
                                    "Aggregation: saving social image \(socialImageName): \(socialImageData.count) bytes"
                                )
                                let socialImagePath = newArticle.publicBasePath
                                    .appendingPathComponent(socialImageName, isDirectory: false)
                                try socialImageData.write(to: socialImagePath)
                                newArticle.heroImage = socialImageName
                                if let size = newArticle.getImageSize(name: socialImageName) {
                                    newArticle.heroImageWidth = Int(size.width)
                                    newArticle.heroImageHeight = Int(size.height)
                                }
                                newArticle.attachments = [socialImageName]
                                try newArticle.save()
                            }
                            else {
                                debugPrint(
                                    "Aggregation: failed to fetch social image from \(articleURL)"
                                )
                            }
                            newArticles.append(newArticle)
                            Task(priority: .background) {
                                try newArticle.savePublic()
                            }
                            DispatchQueue.main.async {
                                self.articles.append(newArticle)
                                self.articles.sort(by: { MyArticleModel.reorder(a: $0, b: $1) })
                                PlanetStore.shared.refreshSelectedArticles()
                            }
                        }
                        else {
                            debugPrint("Aggregation: Skipping \(article.link), already saved")
                        }
                    }
                }
            }
            catch {
                debugPrint("Aggregation: failed to fetch \(site): \(error)")
            }
        }
        return newArticles.count
    }

    func fetchSocialImage(from url: URL) async -> (data: Data?, name: String?) {
        if url.host?.hasSuffix("youtube.com") ?? false {
            return await fetchYouTubeThumbnail(from: url)
        }
        // Fetch URL, parse it with SwiftSoup, find the first og:image, download it, and return its Data and filename
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let html = String(decoding: data, as: UTF8.self)
            let doc: Document = try SwiftSoup.parse(html)
            let ogImage = try doc.select("meta[property=og:image]").first()
            debugPrint("Aggregation: og:image: \(String(describing: ogImage)) found in \(url)")
            if let ogImage = ogImage {
                let ogImageURL = try ogImage.attr("content")
                debugPrint("Aggregation: og:image URL: \(ogImageURL)")
                if let imageURL = URL(string: ogImageURL) {
                    let ogImageData = try Data(contentsOf: imageURL)
                    return (ogImageData, imageURL.lastPathComponent)
                }
            }
        }
        catch {
            debugPrint("Failed to fetch social image from \(url): \(error)")
        }
        return (nil, nil)
    }

    func fetchYouTubeThumbnail(from url: URL) async -> (data: Data?, name: String?) {
        // Example URL: https://www.youtube.com/watch?v=YUbD3K9szaI
        // Get the content of v parameter, and fetch https://img.youtube.com/vi/<v>/maxresdefault.jpg
        do {
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                let queryItem = components.queryItems?.first(where: { $0.name == "v" }),
                let v = queryItem.value
            {
                let thumbnailURL = URL(string: "https://img.youtube.com/vi/\(v)/maxresdefault.jpg")
                if let thumbnailURL = thumbnailURL {
                    let thumbnailData = try Data(contentsOf: thumbnailURL)
                    return (thumbnailData, v + "_" + thumbnailURL.lastPathComponent)
                }
            }
        }
        catch {
            debugPrint("Failed to fetch YouTube thumbnail from \(url): \(error)")
        }
        return (nil, nil)
    }
}
