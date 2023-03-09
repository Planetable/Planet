//
//  PlanetKeyManagerModel.swift
//  Planet
//
//  Created by Kai on 3/10/23.
//

import Foundation


struct PlanetKeyItem: Identifiable {
    let id: UUID
    let planetID: UUID
    let planetName: String
    let keyName: String
    let keyID: String
    let created: Date
    let modified: Date
}
