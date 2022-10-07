//
//  PlanetPublishedFolderModel.swift
//  Planet
//
//  Created by Kai on 10/3/22.
//

import Foundation


struct PlanetPublishedFolder: Codable {
    let id: UUID
    let url: URL
    let created: Date
    var published: Date?
    var publishedLink: String?
}


struct PlanetPublishedFolderVersion: Codable {
    let id: UUID
    let cid: String
    let created: Date
}
