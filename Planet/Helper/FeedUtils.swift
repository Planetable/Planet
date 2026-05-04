import AppKit
import Foundation
import FeedKit
import SwiftSoup

struct AvailableFeed: Codable {
    let url: String
    let mime: String
}

struct FeedDiscoveryResult {
    let feedData: Data?
    let feedURL: URL?
    let htmlDocument: Document?
    let htmlURL: URL?
}

struct FeedUtils {
    private struct HTMLAvatarCandidate: Sendable {
        let url: URL
        let source: String
        let sourceRank: Int
    }

    private struct DownloadedHTMLAvatarCandidate: Sendable {
        let candidate: HTMLAvatarCandidate
        let data: Data
    }

    private struct AvatarDownloadTimeoutError: Error {}

    private static let htmlAvatarDownloadTimeout: TimeInterval = 2.0
    private static let maxHTMLAvatarCandidates = 12

    static func isFeed(mime: String) -> Bool {
        mime.contains("application/xml")
            || mime.contains("text/xml")
            || mime.contains("application/atom+xml")
            || mime.contains("application/rss+xml")
            || mime.contains("application/json")
            || mime.contains("application/feed+json")
    }

    static func getHTMLDocument(url: URL) async throws -> Document? {
        guard let (data, _) = try? await URLSession.shared.data(from: url)
        else {
            return nil
        }
        guard let htmlString = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        return try? SwiftSoup.parse(htmlString)
    }

    // TODO: Make an UI for this choice
    static func selectBestFeed(_ feeds: [AvailableFeed]) -> AvailableFeed? {
        if feeds.count == 1 {
            if let feed = feeds.first {
                return feed
            }
        }
        for feed in feeds {
            if feed.mime.contains("json") {
                return feed
            }
        }
        if let feed = feeds.first {
            return feed
        }
        return nil
    }

    static func findFeed(url: URL) async throws -> FeedDiscoveryResult {
        guard let (data, response) = try? await URLSession.shared.data(from: url) else {
            throw PlanetError.NetworkError
        }
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.ok,
              let mime = httpResponse.mimeType?.lowercased()
        else {
            return FeedDiscoveryResult(
                feedData: nil,
                feedURL: nil,
                htmlDocument: nil,
                htmlURL: nil
            )
        }
        if isFeed(mime: mime) {
            return FeedDiscoveryResult(
                feedData: data,
                feedURL: url,
                htmlDocument: nil,
                htmlURL: nil
            )
        }
        if mime.contains("text/html") {
            // parse HTML and find <link rel="alternate">
            guard let homepageHTML = String(data: data, encoding: .utf8),
                  let soup = try? SwiftSoup.parse(homepageHTML)
            else {
                return FeedDiscoveryResult(
                    feedData: nil,
                    feedURL: nil,
                    htmlDocument: nil,
                    htmlURL: nil
                )
            }
            let availableFeeds = try soup.select("link[rel=alternate]")
                .compactMap { elem in
                    let mime = try? elem.attr("type")
                    let href = try? elem.attr("href")
                    if let mime = mime, let href = href, isFeed(mime: mime) {
                        let availableFeedURLString = URL(string: href, relativeTo: url)?.absoluteString
                        if let urlString = availableFeedURLString {
                            return AvailableFeed(url: urlString, mime: mime)
                        }
                    }
                    return nil
                }
            debugPrint("FeedUtils: availableFeeds: \(availableFeeds)")
            if availableFeeds.count == 0 {
                return FeedDiscoveryResult(
                    feedData: nil,
                    feedURL: nil,
                    htmlDocument: soup,
                    htmlURL: url
                )
            }
            guard let bestFeed = selectBestFeed(availableFeeds) else {
                return FeedDiscoveryResult(
                    feedData: nil,
                    feedURL: nil,
                    htmlDocument: soup,
                    htmlURL: url
                )
            }
            debugPrint("FeedUtils: proceeds with the selection: \(bestFeed)")
            guard let feedURL = URL(string: bestFeed.url) else {
                return FeedDiscoveryResult(
                    feedData: nil,
                    feedURL: nil,
                    htmlDocument: soup,
                    htmlURL: url
                )
            }
            // fetch feed
            guard let (data, response) = try? await URLSession.shared.data(from: feedURL) else {
                throw PlanetError.NetworkError
            }
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.ok
            else {
                return FeedDiscoveryResult(
                    feedData: nil,
                    feedURL: nil,
                    htmlDocument: soup,
                    htmlURL: url
                )
            }
            return FeedDiscoveryResult(
                feedData: data,
                feedURL: feedURL,
                htmlDocument: soup,
                htmlURL: url
            )
        }
        // unknown HTTP response
        return FeedDiscoveryResult(
            feedData: nil,
            feedURL: nil,
            htmlDocument: nil,
            htmlURL: nil
        )
    }

    static func findAvatarFromHTMLImages(htmlDocument: Document, htmlURL: URL) async throws -> Data? {
        let candidates = try htmlAvatarCandidates(htmlDocument: htmlDocument, htmlURL: htmlURL)
        guard !candidates.isEmpty else {
            return nil
        }

        let downloads = await downloadHTMLAvatarCandidates(candidates)
        guard let bestDownload = downloads.max(by: { lhs, rhs in
            if lhs.data.count == rhs.data.count {
                return lhs.candidate.sourceRank < rhs.candidate.sourceRank
            }
            return lhs.data.count < rhs.data.count
        })
        else {
            return nil
        }

        debugPrint(
            "FeedAvatar: selected \(bestDownload.candidate.source) at \(bestDownload.candidate.url.absoluteString) (\(bestDownload.data.count) bytes)"
        )
        return bestDownload.data
    }

    private static func htmlAvatarCandidates(htmlDocument: Document, htmlURL: URL) throws -> [HTMLAvatarCandidate] {
        var candidates: [HTMLAvatarCandidate] = []

        for elem in try htmlDocument.select("meta[content]").array() {
            guard let content = try? elem.attr("content"),
                  let avatarURL = avatarURL(from: content, relativeTo: htmlURL)
            else {
                continue
            }

            let property = (try? elem.attr("property").lowercased()) ?? ""
            let name = (try? elem.attr("name").lowercased()) ?? ""
            let itemprop = (try? elem.attr("itemprop").lowercased()) ?? ""
            let itempropTokens = itemprop.split(separator: " ").map(String.init)

            if property == "og:image" {
                candidates.append(HTMLAvatarCandidate(url: avatarURL, source: "og:image", sourceRank: 4000))
            }
            else if property == "twitter:image" || name == "twitter:image" {
                candidates.append(HTMLAvatarCandidate(url: avatarURL, source: "twitter:image", sourceRank: 3500))
            }
            else if itempropTokens.contains("logo") {
                candidates.append(HTMLAvatarCandidate(url: avatarURL, source: "itemprop=logo", sourceRank: 3000))
            }
        }

        let iconElems = try htmlDocument.select("link[rel][href]").array().filter { elem in
            guard let rel = try? elem.attr("rel").lowercased() else {
                return false
            }
            return rel.contains("icon")
        }

        for elem in iconElems.sorted(by: { elemA, elemB in
            iconScore(for: elemA) > iconScore(for: elemB)
        }) {
            guard let avatarURLString = try? elem.attr("href"),
                  let avatarURL = avatarURL(from: avatarURLString, relativeTo: htmlURL)
            else {
                continue
            }

            let rel = (try? elem.attr("rel")) ?? "icon"
            let sourceRank = min(iconScore(for: elem), 1000)
            candidates.append(HTMLAvatarCandidate(url: avatarURL, source: "link rel=\(rel)", sourceRank: sourceRank))
        }

        var seen: Set<String> = []
        return candidates.filter { candidate in
            seen.insert(candidate.url.absoluteString).inserted
        }
    }

    private static func avatarURL(from string: String, relativeTo htmlURL: URL) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.lowercased().hasPrefix("data:")
        else {
            return nil
        }

        return URL(string: trimmed, relativeTo: htmlURL)?.absoluteURL
    }

    private static func iconScore(for element: Element) -> Int {
        guard let sizes = try? element.attr("sizes").lowercased() else {
            return 0
        }
        if sizes == "any" {
            return Int.max
        }
        let bestSize = sizes
            .split(separator: " ")
            .compactMap { size -> Int? in
                let components = size.split(separator: "x")
                guard let first = components.first else {
                    return nil
                }
                return Int(first)
            }
            .max()
        return bestSize ?? 0
    }

    private static func downloadHTMLAvatarCandidates(_ candidates: [HTMLAvatarCandidate]) async -> [DownloadedHTMLAvatarCandidate] {
        let limitedCandidates = Array(
            candidates
                .sorted {
                    $0.sourceRank > $1.sourceRank
                }
                .prefix(maxHTMLAvatarCandidates)
        )

        return await withTaskGroup(of: DownloadedHTMLAvatarCandidate?.self) { group in
            for candidate in limitedCandidates {
                group.addTask {
                    await fetchHTMLAvatarCandidate(candidate)
                }
            }

            var downloads: [DownloadedHTMLAvatarCandidate] = []
            for await download in group {
                if let download {
                    downloads.append(download)
                }
            }

            return downloads
        }
    }

    private static func fetchHTMLAvatarCandidate(_ candidate: HTMLAvatarCandidate) async -> DownloadedHTMLAvatarCandidate? {
        var request = URLRequest(url: candidate.url, timeoutInterval: htmlAvatarDownloadTimeout)
        request.cachePolicy = .returnCacheDataElseLoad

        guard let (data, response) = try? await withTimeout(seconds: htmlAvatarDownloadTimeout, operation: {
            try await URLSession.shared.data(for: request)
        }) else {
            return nil
        }

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.ok
        else {
            return nil
        }

        guard !data.isEmpty,
              NSImage(data: data) != nil
        else {
            return nil
        }

        debugPrint("FeedAvatar: downloaded \(candidate.source) at \(candidate.url.absoluteString) (\(data.count) bytes)")
        return DownloadedHTMLAvatarCandidate(candidate: candidate, data: data)
    }

    private static func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                let nanoseconds = UInt64(max(seconds, 0) * 1_000_000_000)
                try await Task.sleep(nanoseconds: nanoseconds)
                throw AvatarDownloadTimeoutError()
            }

            do {
                guard let result = try await group.next() else {
                    throw AvatarDownloadTimeoutError()
                }
                group.cancelAll()
                return result
            }
            catch {
                group.cancelAll()
                throw error
            }
        }
    }

    static func findLinkFromFeed(feedData: Data) -> String? {
        let feedResult = FeedParser(data: feedData).parse()
        guard case .success(let feed) = feedResult else {
            return nil
        }
        switch feed {
        case let .atom(feed):
            if let links = feed.links {
                for link in links {
                    if let rel = link.attributes?.rel, rel == "alternate" {
                        return link.attributes?.href
                    }
                }
            }
        case let .rss(feed):
            if let link = feed.link {
                return link
            }
        case let .json(feed):
            if let link = feed.homePageURL {
                return link
            }
        }
        return nil
    }

    static func jsonFeedItemToArticle(item: JSONFeedItem, feed: JSONFeed, feedURL: URL) -> PublicArticleModel? {
        guard let url = item.url,
              let title = item.title
        else {
            return nil
        }
        let allowedCharacterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "/~-_."))
        let escapedURL = url.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet)

        let sanitizedLink: String
        if !url.contains("://") {
            if let escapedURL = escapedURL {
                guard let linkURL = URL(string: escapedURL, relativeTo: feedURL) else {
                    debugPrint("Failed to construct linkURL: \(url) \(feedURL)")
                    return nil
                }
                sanitizedLink = linkURL.sanitizedLink()
            } else {
                debugPrint("FeedUtils: during parsing, found item with invalid url \(url)")
                return nil
            }
        } else {
            if let linkURL = URL(string: url) {
                sanitizedLink = linkURL.sanitizedLink()
            } else {
                return nil
            }
        }
        let content = item.contentHtml ?? ""
        let created = item.datePublished ?? item.dateModified ?? Date()
        return PublicArticleModel(
            id: UUID(),
            link: sanitizedLink,
            title: title,
            content: content,
            contentRendered: content, // TODO: Should prefer HTML from the feed
            created: created,
            hasVideo: false,
            videoFilename: nil,
            hasAudio: false,
            audioFilename: nil,
            audioDuration: nil,
            audioByteLength: nil,
            attachments: nil,
            heroImage: nil,
            heroImageWidth: nil,
            heroImageHeight: nil,
            heroImageURL: nil,  // TODO: Extract og:image and put it here
            heroImageFilename: nil
        )
    }

    static func parseFeed(data: Data, url: URL) async throws -> (
        name: String?,
        about: String?,
        avatar: Data?,
        articles: [PublicArticleModel]?
    ) {
        let feedResult = FeedParser(data: data).parse()
        debugPrint("FeedUtils: parsing result \(feedResult)")
        guard case .success(let feed) = feedResult else {
            throw PlanetError.PlanetFeedError
        }
        switch feed {
        case let .atom(feed):
            let name = feed.title
            let about = feed.subtitle?.value
            let articles: [PublicArticleModel]? = feed.entries?.compactMap { entry in
                guard let link = entry.links?[0].attributes?.href,
                      let title = entry.title
                else {
                    return nil
                }
                let sanitizedLink: String
                if let linkURL = URL(string: link) {
                    sanitizedLink = linkURL.sanitizedLink()
                } else {
                    return nil
                }
                let content = entry.content?.value ?? ""
                // GitHub releases feeds expose entry timestamps via <updated> without <published>.
                let created = entry.published ?? entry.updated ?? Date()
                return PublicArticleModel(
                    id: UUID(),
                    link: sanitizedLink,
                    title: title,
                    content: content,
                    contentRendered: content,
                    created: created,
                    hasVideo: false,
                    videoFilename: nil,
                    hasAudio: false,
                    audioFilename: nil,
                    audioDuration: nil,
                    audioByteLength: nil,
                    attachments: nil,
                    heroImage: nil,
                    heroImageWidth: nil,
                    heroImageHeight: nil,
                    heroImageURL: nil,
                    heroImageFilename: nil
                )
            }
            return (name, about, nil, articles)
        case let .rss(feed):
            let name = feed.title
            let about = feed.description
            let articles: [PublicArticleModel]? = feed.items?.compactMap { item in
                guard let link = item.link,
                      let title = item.title
                else {
                    return nil
                }
                let sanitizedLink: String
                if let linkURL = URL(string: link) {
                    sanitizedLink = linkURL.sanitizedLink()
                } else {
                    return nil
                }
                let description = item.description ?? ""
                let contentEncoded = item.content?.contentEncoded ?? ""
                let bestContent = contentEncoded.count >= description.count ? contentEncoded : description
                let created = item.pubDate ?? Date()
                return PublicArticleModel(
                    id: UUID(),
                    link: sanitizedLink,
                    title: title,
                    content: bestContent,
                    contentRendered: bestContent,
                    created: created,
                    hasVideo: false,
                    videoFilename: nil,
                    hasAudio: false,
                    audioFilename: nil,
                    audioDuration: nil,
                    audioByteLength: nil,
                    attachments: nil,
                    heroImage: nil,
                    heroImageWidth: nil,
                    heroImageHeight: nil,
                    heroImageURL: nil,
                    heroImageFilename: nil
                )
            }
            return (name, about, nil, articles)
        case let .json(feed):
            let name = feed.title
            let about = feed.description
            var avatar: Data? = nil
            if let imageURL = feed.icon,
               let url = URL(string: imageURL),
               let (data, response) = try? await URLSession.shared.data(from: url),
               let httpResponse = response as? HTTPURLResponse,
               httpResponse.ok
            {
                avatar = data
            }
            let articles: [PublicArticleModel]? = feed.items?.compactMap { item in
                FeedUtils.jsonFeedItemToArticle(item: item, feed: feed, feedURL: url)
            }
            return (name, about, avatar, articles)
        }
    }
}
