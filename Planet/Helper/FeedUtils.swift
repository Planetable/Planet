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

    static func findAvatarFromHTMLIcons(htmlDocument: Document, htmlURL: URL) async throws -> Data? {
        let possibleAvatarElems = try htmlDocument.select("link[rel][href]").array().filter { elem in
            guard let rel = try? elem.attr("rel").lowercased() else {
                return false
            }
            return rel.contains("icon")
        }
        let avatarElem = possibleAvatarElems.sorted { elemA, elemB in
            iconScore(for: elemA) > iconScore(for: elemB)
        }.first

        guard let avatarURLString = try? avatarElem?.attr("href"),
              let avatarURL = URL(string: avatarURLString, relativeTo: htmlURL)
        else {
            return nil
        }

        debugPrint("FeedAvatar: found avatar URL at \(avatarURLString)")
        guard let (data, response) = try? await URLSession.shared.data(from: avatarURL) else {
            return nil
        }
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.ok
        else {
            return nil
        }
        return data
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

    static func findAvatarFromHTMLOGImage(htmlDocument: Document, htmlURL: URL) async throws -> Data? {
        let possibleAvatarElems = try htmlDocument.select("meta[property='og:image']")
        let avatarElem = possibleAvatarElems.first { elem in
            if let content = try? elem.attr("content") {
                return content.contains("/")
            }
            return false
        }
        guard let avatarElem = avatarElem,
              let avatarElemContent = try? avatarElem.attr("content")
        else {
            return nil
        }
        guard let avatarURL = URL(string: avatarElemContent, relativeTo: htmlURL) else {
            return nil
        }
        guard let (data, response) = try? await URLSession.shared.data(from: avatarURL) else {
            return nil
        }
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.ok
        else {
            return nil
        }
        return data
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
