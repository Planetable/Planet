import Foundation

enum PNSourceMode: String, Codable {
    case auto
    case api
    case disk
}

struct PNGlobalOptions {
    var outputJSON = false
    var prettyJSON = true
    var libraryOverride: URL?
    var apiURLOverride: URL?
    var source: PNSourceMode = .auto
    var timeout: TimeInterval = 10
}

struct PNStatus: Codable {
    let appRunning: Bool
    let apiReachable: Bool
    let source: String
    let apiURL: String
    let libraryPath: String
}

struct PNAPIStatus: Codable {
    let reachable: Bool
    let url: String
}

struct PNTemplateRecord: Codable {
    let id: String
    let name: String
    let version: String?
    let buildNumber: Int?
    let path: String
}

struct PNPlanetRecord: Codable {
    let id: UUID
    var name: String
    var about: String
    var domain: String? = nil
    var authorName: String? = nil
    var slug: String? = nil
    var nextArticleNumber: Int? = nil
    let ipns: String
    let created: Date
    var updated: Date
    var templateName: String
    var lastPublished: Date? = nil
    var lastPublishedCID: String? = nil
    var archived: Bool? = nil
    var archivedAt: Date? = nil
    var plausibleEnabled: Bool? = nil
    var plausibleDomain: String? = nil
    var plausibleAPIServer: String? = nil
    var juiceboxEnabled: Bool? = nil
    var juiceboxProjectID: Int? = nil
    var juiceboxProjectIDGoerli: Int? = nil
    var acceptsDonation: Bool? = nil
    var acceptsDonationMessage: String? = nil
    var acceptsDonationETHAddress: String? = nil
    var twitterUsername: String? = nil
    var githubUsername: String? = nil
    var telegramUsername: String? = nil
    var mastodonUsername: String? = nil
    var discordLink: String? = nil
    var podcastCategories: [String: [String]]? = nil
    var podcastLanguage: String? = nil
    var podcastExplicit: Bool? = nil
    var tags: [String: String]? = nil

    var isArchived: Bool {
        archived ?? false
    }

    var articleReferencePrefix: String {
        if let slug = slug?.pnNilIfEmpty {
            return slug.uppercased()
        }
        return String(id.uuidString.prefix(8)).uppercased()
    }
}

struct PNArticleRecord: Codable {
    let id: UUID
    var articleType: Int? = 0
    var link: String
    var slug: String? = nil
    var articleNumber: Int? = nil
    var articleReference: String? = nil
    var heroImage: String? = nil
    var heroImageWidth: Int? = nil
    var heroImageHeight: Int? = nil
    var externalLink: String? = nil
    var title: String
    var content: String
    var contentRendered: String? = nil
    var summary: String? = nil
    var created: Date
    var modified: Date? = nil
    var starred: Date? = nil
    var starType: Int? = 0
    var videoFilename: String? = nil
    var audioFilename: String? = nil
    var attachments: [String]? = nil
    var cids: [String: String]? = nil
    var tags: [String: String]? = nil
    var pinned: Date? = nil

    func reference(in planet: PNPlanetRecord) -> String? {
        if let articleReference, !articleReference.isEmpty {
            return articleReference
        }
        guard let articleNumber, articleNumber > 0 else { return nil }
        return "\(planet.articleReferencePrefix)-\(articleNumber)"
    }
}

struct PNPublicPlanetRecord: Codable {
    let id: UUID
    let name: String
    let about: String
    let ipns: String
    let created: Date
    let updated: Date
    let articles: [PNPublicArticleRecord]

    let plausibleEnabled: Bool?
    let plausibleDomain: String?
    let plausibleAPIServer: String?

    let juiceboxEnabled: Bool?
    let juiceboxProjectID: Int?
    let juiceboxProjectIDGoerli: Int?

    let acceptsDonation: Bool?
    let acceptsDonationMessage: String?
    let acceptsDonationETHAddress: String?

    let twitterUsername: String?
    let githubUsername: String?
    let telegramUsername: String?
    let mastodonUsername: String?
    let discordLink: String?

    let podcastCategories: [String: [String]]?
    let podcastLanguage: String?
    let podcastExplicit: Bool?

    let tags: [String: String]?
}

struct PNPublicArticleRecord: Codable {
    var articleType: Int? = 0
    let id: UUID
    let link: String
    var slug: String? = nil
    var articleNumber: Int? = nil
    var articleReference: String? = nil
    var externalLink: String? = nil
    let title: String
    let content: String
    let contentRendered: String?
    let created: Date
    var modified: Date? = nil
    let hasVideo: Bool?
    let videoFilename: String?
    let hasAudio: Bool?
    let audioFilename: String?
    let audioDuration: Int?
    let audioByteLength: Int?
    let attachments: [String]?
    let heroImage: String?
    let heroImageWidth: Int?
    let heroImageHeight: Int?
    let heroImageURL: String?
    let heroImageFilename: String?
    var cids: [String: String]? = nil
    var tags: [String: String]? = nil
    var originalSiteName: String? = nil
    var originalSiteDomain: String? = nil
    var originalPostID: String? = nil
    var originalPostDate: Date? = nil
    var pinned: Date? = nil
}

struct PNSearchResponse: Codable {
    var planets: [PNSearchPlanet]
    var articles: [PNSearchArticle]
}

struct PNSearchPlanet: Codable {
    let id: UUID
    let name: String
    let about: String
    let created: Date
    let updated: Date
}

struct PNSearchArticle: Codable {
    let articleID: UUID
    let articleCreated: Date
    let articleNumber: Int?
    let articleReference: String?
    let title: String
    let preview: String
    let planetID: UUID
    let planetName: String
    let relevanceScore: Double?
    let bm25Score: Double?
    let vectorScore: Double?
    let source: String
}

struct PNInstallResult: Codable {
    let source: String
    let target: String
}
