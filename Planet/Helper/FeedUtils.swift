import Foundation
import FeedKit
import SwiftSoup

struct FeedUtils {
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
        if mime.contains("application/xml")
               || mime.contains("text/xml")
               || mime.contains("application/atom+xml")
               || mime.contains("application/rss+xml")
               || mime.contains("application/json")
               || mime.contains("application/feed+json") {
            return (data, nil)
        }
        if mime.contains("text/html") {
            // parse HTML and find <link rel="alternate">
            guard let homepageHTML = String(data: data, encoding: .utf8),
                  let soup = try? SwiftSoup.parse(homepageHTML)
            else {
                return (nil, nil)
            }
            guard let feedElem = try soup.select("link[rel='alternate']").first(),
                  let feedElemHref = try? feedElem.attr("href"),
                  let feedURL = URL(string: feedElemHref, relativeTo: url)?.absoluteURL
            else {
                // no <link rel="alternate"> in HTML
                return (nil, soup)
            }
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

    static func parseFeed(data: Data) throws -> (
        name: String?,
        about: String?,
        avatar: Data?,
        articles: [PublicArticleModel]?
    ) {
        let feedResult = FeedParser(data: data).parse()
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
                let content = entry.content?.attributes?.src ?? ""
                let created = entry.published ?? Date()
                return PublicArticleModel(
                    id: UUID(),
                    link: link,
                    title: title,
                    content: content,
                    created: created,
                    hasVideo: false,
                    videoFilename: nil,
                    hasAudio: false,
                    audioFilename: nil
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
                let description = item.description ?? ""
                let created = item.pubDate ?? Date()
                return PublicArticleModel(
                    id: UUID(),
                    link: link,
                    title: title,
                    content: description,
                    created: created,
                    hasVideo: false,
                    videoFilename: nil,
                    hasAudio: false,
                    audioFilename: nil
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
                guard let url = item.url,
                      let title = item.title
                else {
                    return nil
                }
                let content = item.contentHtml ?? ""
                let created = item.datePublished ?? Date()
                return PublicArticleModel(
                    id: UUID(),
                    link: url,
                    title: title,
                    content: content,
                    created: created,
                    hasVideo: false,
                    videoFilename: nil,
                    hasAudio: false,
                    audioFilename: nil
                )
            }
            return (name, about, avatar, articles)
        }
    }
}
