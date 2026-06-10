//
//  PlanetAPIModels.swift
//  Planet
//

import Vapor


struct APIPlanet: Content {
    var name: String?
    var about: String?
    var template: String?
    var avatar: Data?
}


struct APIPlanetArticle: Content {
    var title: String?
    var date: String?
    var content: String?
    var attachments: [File]?
}

/// How an article-modify request should treat its attachments.
/// - keep: leave existing attachments untouched (default when none are sent).
/// - append: add the sent attachments, upserting by filename, keeping the rest.
/// - replace: drop all existing attachments, then add the sent ones (default
///   when attachments are sent; sending none clears all).
enum APIAttachmentMode: String {
    case keep
    case append
    case replace
}


struct APISearchResultPlanet: Content {
    let id: UUID
    let name: String
    let about: String
    let created: Date
    let updated: Date
}


struct APISearchResultArticle: Content {
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


struct APISearchResponse: Content {
    let planets: [APISearchResultPlanet]
    let articles: [APISearchResultArticle]
}
