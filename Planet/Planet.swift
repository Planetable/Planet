//
//  Planet.swift
//  Planet
//
//  Created by Kai on 11/12/21.
//

import Foundation
import SwiftUI
import Cocoa


struct PlanetFeed: Codable, Hashable {
    let id: UUID
    let ipns: String
    let created: Date
    let updated: Date
    let name: String
    let about: String
    let articles: [PlanetFeedArticle]
}


struct PlanetFeedArticle: Codable, Hashable {
    let id: UUID
    let created: Date
    let title: String
    var content: String?
}


// MARK: - Core Data -
extension CodingUserInfoKey {
    static let managedObjectContext = CodingUserInfoKey(rawValue: "managedObjectContext")!
}

enum DecoderConfigurationError: Error {
    case missingManagedObjectContext
}

enum PlanetType: Int32 {
    case planet = 0
    case ens = 1
    case dnslink = 2
    case dns = 3
}

enum FeedType: Int32 {
    case none = 0
    case planet = 1
    case jsonfeed = 2
    case rss = 3
    case atom = 4
}

class Planet: NSManagedObject, Codable {
    enum CodingKeys: CodingKey {
        case id
        case typeValue
        case created
        case name
        case about
        case ipns
        case ipfs
        case ens
        case dns
        case dnslink
        case feedTypeValue
        case feedAddress
        case feedSHA256
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
        typeValue = try container.decode(Int32.self, forKey: .typeValue)
        created = try container.decode(Date.self, forKey: .created)
        name = try container.decode(String.self, forKey: .name)
        about = try container.decode(String.self, forKey: .about)
        ipns = try container.decode(String.self, forKey: .ipns)
        ipfs = try container.decode(String.self, forKey: .ipfs)
        ens = try container.decode(String.self, forKey: .ens)
        dnslink = try container.decode(String.self, forKey: .dnslink)
        dns = try container.decode(String.self, forKey: .dns)
        feedTypeValue = try container.decode(Int32.self, forKey: .feedTypeValue)
        feedAddress = try container.decode(String.self, forKey: .feedAddress)
        feedSHA256 = try container.decode(String.self, forKey: .feedSHA256)
        keyID = try container.decode(String.self, forKey: .keyID)
        keyName = try container.decode(String.self, forKey: .keyName)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(typeValue, forKey: .typeValue)
        try container.encode(created, forKey: .created)
        try container.encode(name, forKey: .name)
        try container.encode(about, forKey: .about)
        try container.encode(ipns, forKey: .ipns)
        try container.encode(ipfs, forKey: .ipfs)
        try container.encode(ens, forKey: .ens)
        try container.encode(dnslink, forKey: .dnslink)
        try container.encode(dns, forKey: .dns)
        try container.encode(feedTypeValue, forKey: .feedTypeValue)
        try container.encode(feedAddress, forKey: .feedAddress)
        try container.encode(feedSHA256, forKey: .feedSHA256)
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
    
    var type: PlanetType {
        get {
            return PlanetType(rawValue: self.typeValue)!
        }

        set {
            self.typeValue = newValue.rawValue
        }
    }
    
    var feedType: FeedType {
        get {
            return FeedType(rawValue: self.feedTypeValue)!
        }

        set {
            self.feedTypeValue = newValue.rawValue
        }
    }
    
    

    func generateAvatarName() -> String {
        guard let name = name else {
            return ""
        }
        if name.contains(" ") {
            let initials: [String] = name.components(separatedBy: " ").map { n in
                n.prefix(1).capitalized
            }
            return String(initials.joined(separator: "").prefix(2))
        } else {
            return name.prefix(1).capitalized
        }
    }

    var gradients: [Gradient] {
        [
            Gradient(colors: [Color(hex: 0x88D3FA), Color(hex: 0x4C9FED)]), // Sky Blue
            Gradient(colors: [Color(hex: 0xFACE76), Color(hex: 0xF5AD67)]), // Orange
            Gradient(colors: [Color(hex: 0xD8A9F0), Color(hex: 0xCA77E9)]), // Pink
            Gradient(colors: [Color(hex: 0xF39066), Color(hex: 0xF0636E)]), // Red
            Gradient(colors: [Color(hex: 0xACDB86), Color(hex: 0x74C771)]), // Green
            Gradient(colors: [Color(hex: 0x8AB2FB), Color(hex: 0x6469FA)]), // Violet
            Gradient(colors: [Color(hex: 0x7FE9D7), Color(hex: 0x5DC6B8)]), // Cyan
        ]
    }

    func gradient() -> Gradient {
        guard let id = id else { return gradients.randomElement()! }
        let gs = gradients
        let parts = id.integers
        let a: Int64 = abs(parts.0)
        let c = Int((a % Int64(31)) % Int64(gs.count))
        let g = gs[c]
        return g
    }
}


class PlanetArticle: NSManagedObject, Codable {
    enum CodingKeys: CodingKey {
        case id
        case created
        case read
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
        read = try container.decode(Date.self, forKey: .read)
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
struct PlanetIPFSVersionInfo: Codable {
    let version: String?
    let system: String?

    enum CodingKeys: String, CodingKey {
        case version = "Version"
        case system = "System"
    }
}

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
