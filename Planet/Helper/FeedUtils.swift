import Foundation
import FeedKit
import SwiftSoup

struct AvailableFeed: Codable {
    let url: String
    let mime: String
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

    static func findFeed(url: URL) async throws -> (feed: Data?, html: Document?) {
        guard let (data, response) = try? await URLSession.shared.data(from: url) else {
            throw PlanetError.NetworkError
        }
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.ok,
              let mime = httpResponse.mimeType?.lowercased()
        else {
            return (nil, nil)
        }
        if isFeed(mime: mime) {
            return (data, nil)
        }
        if mime.contains("text/html") {
            // parse HTML and find <link rel="alternate">
            guard let homepageHTML = String(data: data, encoding: .utf8),
                  let soup = try? SwiftSoup.parse(homepageHTML)
            else {
                return (nil, nil)
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
                return (nil, soup)
            }
            guard let bestFeed = selectBestFeed(availableFeeds) else { return (nil, soup) }
            guard let feedURL = URL(string: bestFeed.url) else { return (nil, soup) }
            // fetch feed
            guard let (data, response) = try? await URLSession.shared.data(from: feedURL) else {
                throw PlanetError.NetworkError
            }
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.ok
            else {
                return (nil, soup)
            }
            return (data, soup)
        }
        // unknown HTTP response
        return (nil, nil)
    }

    static func findAvatarFromHTMLIcons(htmlDocument: Document, htmlURL: URL) async throws -> Data? {
        let possibleAvatarElems = try htmlDocument.select("link[sizes]")
        let avatarElem = possibleAvatarElems.sorted { elemA, elemB in
            let elemASizes = try? elemA.attr("sizes")
            let elemBSizes = try? elemB.attr("sizes")
            if let elemASizes = elemASizes, let elemBSizes = elemBSizes {
                let elemAWidth = elemASizes.components(separatedBy: "x").first?.trimmingCharacters(in: .whitespacesAndNewlines)
                let elemBWidth = elemBSizes.components(separatedBy: "x").first?.trimmingCharacters(in: .whitespacesAndNewlines)
                if let elemAWidth = elemAWidth, let elemBWidth = elemBWidth {
                    return Int(elemAWidth) ?? 0 > Int(elemBWidth) ?? 0
                }
                return false
            } else {
                return false
            }
        }.first

        var avatarURLString: String? = nil

        if avatarElem == nil {
            let simpleLinkElems = try htmlDocument.select("link[rel='icon']")
            let simpleLinkElem = simpleLinkElems.first
            if let simpleLinkElemHref = try? simpleLinkElem?.attr("href") {
                avatarURLString = simpleLinkElemHref
            }
        } else {
            if let avatarElemHref = try? avatarElem?.attr("href") {
                avatarURLString = avatarElemHref
            }
        }

        guard let avatarURLString = avatarURLString, let avatarURL = URL(string: avatarURLString, relativeTo: htmlURL) else {
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

    static func jsonFeedItemToArticle(item: JSONFeedItem, feed: JSONFeed) -> PublicArticleModel? {
        guard let url = item.url,
              let title = item.title
        else {
            return nil
        }
        let allowedCharacterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "/~-_."))
        let escapedURL = url.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet)

        let sanitizedLink: String
        if !url.contains("://") {
            if let feedURLString = feed.feedUrl, let feedURL = URL(string: feedURLString), let escapedURL = escapedURL {

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
        let created = item.datePublished ?? Date()
        return PublicArticleModel(
            id: UUID(),
            link: sanitizedLink,
            title: title,
            content: content,
            created: created,
            hasVideo: false,
            videoFilename: nil,
            hasAudio: false,
            audioFilename: nil,
            attachments: nil
        )
    }

    static func parseFeed(data: Data) async throws -> (
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
                let created = entry.published ?? Date()
                return PublicArticleModel(
                    id: UUID(),
                    link: sanitizedLink,
                    title: title,
                    content: content,
                    created: created,
                    hasVideo: false,
                    videoFilename: nil,
                    hasAudio: false,
                    audioFilename: nil,
                    attachments: nil
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
                let created = item.pubDate ?? Date()
                return PublicArticleModel(
                    id: UUID(),
                    link: sanitizedLink,
                    title: title,
                    content: description,
                    created: created,
                    hasVideo: false,
                    videoFilename: nil,
                    hasAudio: false,
                    audioFilename: nil,
                    attachments: nil
                )
            }
            return (name, about, nil, articles)
        case let .json(feed):
            let name = feed.title
            let about = feed.description
            var avatar: Data? = nil
            if let imageURL = feed.icon,
               let url = URL(string: imageURL),
               let data = try? Data(contentsOf: url) {
                avatar = data
            }
            let articles: [PublicArticleModel]? = feed.items?.compactMap { item in
                FeedUtils.jsonFeedItemToArticle(item: item, feed: feed)
            }
            return (name, about, avatar, articles)
        }
    }
}
