//
//  SearchResult.swift
//  Planet
//
//  Created by Xin Liu on 2/22/24.
//

import Foundation

enum PlanetKind: String, Sendable {
    case my
    case following
}

struct SearchResult: Hashable, Sendable {
    let articleID: UUID
    let articleCreated: Date
    let title: String
    let preview: String
    let planetID: UUID
    let planetName: String
    let planetKind: PlanetKind
    let relevanceScore: Double?

    init(
        articleID: UUID,
        articleCreated: Date,
        title: String,
        preview: String,
        planetID: UUID,
        planetName: String,
        planetKind: PlanetKind,
        relevanceScore: Double? = nil
    ) {
        self.articleID = articleID
        self.articleCreated = articleCreated
        self.title = title
        self.preview = preview
        self.planetID = planetID
        self.planetName = planetName
        self.planetKind = planetKind
        self.relevanceScore = relevanceScore
    }
}
