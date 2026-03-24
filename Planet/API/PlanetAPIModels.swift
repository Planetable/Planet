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
    let title: String
    let preview: String
    let planetID: UUID
    let planetName: String
    let relevanceScore: Double?
}


struct APISearchResponse: Content {
    let planets: [APISearchResultPlanet]
    let articles: [APISearchResultArticle]
}
