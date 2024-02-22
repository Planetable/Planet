//
//  SearchResult.swift
//  Planet
//
//  Created by Xin Liu on 2/22/24.
//

import Foundation

enum PlanetKind: String {
    case my
    case following
}

struct SearchResult: Hashable {
    let articleID: UUID
    let articleCreated: Date
    let title: String
    let preview: String
    let planetID: UUID
    let planetName: String
    let planetKind: PlanetKind
}
