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
