//
//  PlanetAPILogEntry.swift
//  Planet
//
//  Created by Kai on 5/30/25.
//

import Foundation
import Blackbird


struct PlanetAPILogEntry: BlackbirdModel {
    static var primaryKey: [BlackbirdColumnKeyPath] = [\.$timestamp]
    static var indexes: [[BlackbirdColumnKeyPath]] = [
        [\.$statusCode],
        [\.$originIP],
        [\.$requestURL]
    ]

    @BlackbirdColumn var timestamp: Date
    @BlackbirdColumn var statusCode: Int
    @BlackbirdColumn var originIP: String
    @BlackbirdColumn var requestURL: String
    @BlackbirdColumn var errorDescription: String
}
