//
//  PlanetAPIModels.swift
//  Planet
//

import Foundation
import Vapor


struct APIPlanet: Content {
    var name: String
    var about: String = ""
    var template: String = ""
    var avatar: Data?
}
