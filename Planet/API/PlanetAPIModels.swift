//
//  PlanetAPIModels.swift
//  Planet
//

import Vapor


struct APIPlanet: Content {
    var name: String
    var about: String = ""
    var template: String = ""
    var avatar: Data?
}


struct APIModifyPlanet: Content {
    var name: String?
    var about: String?
    var template: String?
    var avatar: Data?
}
