//
//  Planet.swift
//  Planet
//
//  Created by Kai on 11/12/21.
//

import Foundation
import SwiftUI
import Cocoa



struct PlanetFeed: Codable {
    let id: UUID
    let ipns: String
    let created: Date
    let updated: Date
    let name: String
    let about: String
    let articles: [PlanetFeedArticle]
}


struct PlanetFeedArticle: Codable {
    let id: UUID
    let created: Date
    let title: String
}


// MARK: - Core Data -
extension CodingUserInfoKey {
    static let managedObjectContext = CodingUserInfoKey(rawValue: "managedObjectContext")!
}

enum DecoderConfigurationError: Error {
    case missingManagedObjectContext
}


class Planet: NSManagedObject, Codable {
    enum CodingKeys: CodingKey {
        case id
        case created
        case name
        case about
        case ipns
        case keyID
        case keyName
    }
    
    required convenience init(from decoder: Decoder) throws {
        guard let context = decoder.userInfo[.managedObjectContext] as? NSManagedObjectContext else {
            throw DecoderConfigurationError.missingManagedObjectContext
        }
        
        self.init(context: context)
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        created = try container.decode(Date.self, forKey: .created)
        name = try container.decode(String.self, forKey: .name)
        about = try container.decode(String.self, forKey: .about)
        ipns = try container.decode(String.self, forKey: .ipns)
        keyID = try container.decode(String.self, forKey: .keyID)
        keyName = try container.decode(String.self, forKey: .keyName)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(created, forKey: .created)
        try container.encode(name, forKey: .name)
        try container.encode(about, forKey: .about)
        try container.encode(ipns, forKey: .ipns)
        try container.encode(keyID, forKey: .keyID)
        try container.encode(keyName, forKey: .keyName)
    }
}


extension Planet {
    func isMyPlanet() -> Bool {
        if let keyID = keyID, let keyName = keyName {
            return keyID != "" && keyName != ""
        }
        return false
    }
}


class PlanetArticle: NSManagedObject, Codable {
    enum CodingKeys: CodingKey {
        case id
        case created
        case title
        case content
        case planetID
    }
    
    required convenience init(from decoder: Decoder) throws {
        guard let context = decoder.userInfo[.managedObjectContext] as? NSManagedObjectContext else {
            throw DecoderConfigurationError.missingManagedObjectContext
        }
        
        self.init(context: context)
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        created = try container.decode(Date.self, forKey: .created)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        planetID = try container.decode(UUID.self, forKey: .planetID)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(created, forKey: .created)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encode(planetID, forKey: .planetID)
    }
}


// MARK: - Unfinished Models -
struct PlanetKeys: Codable {
    let keys: [PlanetKey]?
    
    enum CodingKeys: String, CodingKey {
        case keys = "Keys"
    }
}


struct PlanetKey: Codable {
    let id: String?
    let name: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
    }
}


struct PlanetPeers: Codable {
    let peers: [PlanetPeer]?
    
    enum CodingKeys: String, CodingKey {
        case peers = "Peers"
    }
}


struct PlanetPeer: Codable {
    let addr: String?
    
    enum CodingKeys: String, CodingKey {
        case addr = "Addr"
    }
}


struct PlanetConfig: Codable {
    let addresses: PlanetConfigAddresses?
    
    enum CodingKeys: String, CodingKey {
        case addresses = "Addresses"
    }
}


struct PlanetConfigAddresses: Codable {
    let api: String?
    let gateway: String?

    enum CodingKeys: String, CodingKey {
        case api = "API"
        case gateway = "Gateway"
    }
}


struct PlanetPublished: Codable {
    let name: String?
    let value: String?
    
    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case value = "Value"
    }
}
