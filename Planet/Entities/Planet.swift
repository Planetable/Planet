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
    let name: String
    let about: String
    let ipns: String
    let created: Date
    let updated: Date
    let articles: [PlanetFeedArticle]
    let templateName: String?
}


struct PlanetFeedArticle: Codable, Hashable {
    let id: UUID
    let created: Date
    let title: String
    var content: String?
    var link: String?
}

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
        case lastUpdated
        case lastPublished
        case softDeleted
        case name
        case about
        case ipns
        case ipfs
        case ens
        case dns
        case dnslink
        case feedTypeValue
        case feedAddress
        case latestCID
        case keyID
        case keyName
        case templateName
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
        lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)
        lastPublished = try container.decode(Date.self, forKey: .lastPublished)
        softDeleted = try container.decode(Date.self, forKey: .softDeleted)
        name = try container.decode(String.self, forKey: .name)
        about = try container.decode(String.self, forKey: .about)
        ipns = try container.decode(String.self, forKey: .ipns)
        ipfs = try container.decode(String.self, forKey: .ipfs)
        ens = try container.decode(String.self, forKey: .ens)
        dnslink = try container.decode(String.self, forKey: .dnslink)
        dns = try container.decode(String.self, forKey: .dns)
        feedTypeValue = try container.decode(Int32.self, forKey: .feedTypeValue)
        feedAddress = try container.decode(String.self, forKey: .feedAddress)
        latestCID = try container.decode(String.self, forKey: .latestCID)
        keyID = try container.decode(String.self, forKey: .keyID)
        keyName = try container.decode(String.self, forKey: .keyName)
        templateName = try container.decode(String.self, forKey: .templateName)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(typeValue, forKey: .typeValue)
        try container.encode(created, forKey: .created)
        try container.encode(lastUpdated, forKey: .lastUpdated)
        try container.encode(lastPublished, forKey: .lastPublished)
        try container.encode(softDeleted, forKey: .softDeleted)
        try container.encode(name, forKey: .name)
        try container.encode(about, forKey: .about)
        try container.encode(ipns, forKey: .ipns)
        try container.encode(ipfs, forKey: .ipfs)
        try container.encode(ens, forKey: .ens)
        try container.encode(dnslink, forKey: .dnslink)
        try container.encode(dns, forKey: .dns)
        try container.encode(feedTypeValue, forKey: .feedTypeValue)
        try container.encode(feedAddress, forKey: .feedAddress)
        try container.encode(latestCID, forKey: .latestCID)
        try container.encode(keyID, forKey: .keyID)
        try container.encode(keyName, forKey: .keyName)
        try container.encode(templateName, forKey: .templateName)
    }

    override public var description: String {
        switch type {
            case .planet:
            if let name = name {
                return "Planet Type 0: \(name)"
            } else {
                return "Planet Type 0: \(String(describing: id?.uuidString))"
            }
            case .ens:
                return "Planet Type 1: \(name!)"
            case .dns:
                return "Planet Type 3: \(dns!)"
            default:
                return "Planet Type \(type.rawValue): \(name!)"
        }
    }

    convenience init() {
        self.init(context: PlanetDataController.shared.viewContext)
    }

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

    var IPFSContent: String? {
        get {
            switch type {
            case .planet:
                return "/ipns/\(ipns!)"
            case .ens:
                // TODO: .ens Content Hash could also carry IPNS or domain name
                return "/ipfs/\(ipfs!)"
            default:
                return nil
            }
        }
    }

    var baseURL: URL {
        URLUtils.planetsPath.appendingPathComponent(id!.uuidString, isDirectory: true)
    }

    var infoURL: URL {
        baseURL.appendingPathComponent("planet.json", isDirectory: false)
    }

    var avatarURL: URL {
        baseURL.appendingPathComponent("avatar.png", isDirectory: false)
    }

    var indexURL: URL {
        baseURL.appendingPathComponent("index.html", isDirectory: false)
    }

    var assetsURL: URL {
        baseURL.appendingPathComponent("assets", isDirectory: true)
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

    func updateAvatar(image: NSImage) {
        let targetImage = PlanetManager.shared.resizedAvatarImage(image: image)
        guard let imageData = targetImage.tiffRepresentation else { return }
        let imageRep = NSBitmapImageRep(data: imageData)
        let data = imageRep?.representation(using: .png, properties: [:])
        do {
            try data?.write(to: avatarURL, options: .atomic)
        } catch {
            debugPrint("failed to save planet avatar for \(self): \(error)")
        }
        Task.init { @MainActor in
            NotificationCenter.default.post(name: .updateAvatar, object: nil)
        }
    }

    func removeAvatar() {
        try? FileManager.default.removeItem(at: avatarURL)
    }

    func avatar() -> NSImage? {
        if FileManager.default.fileExists(atPath: avatarURL.path) {
            return NSImage(contentsOf: avatarURL)
        }
        return nil
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

    @MainActor var isUpdating: Bool {
        get {
            PlanetStatusViewModel.shared.updatingPlanets.contains(id!)
        }
        set {
            if newValue {
                PlanetStatusViewModel.shared.updatingPlanets.insert(id!)
            } else {
                PlanetStatusViewModel.shared.updatingPlanets.remove(id!)
            }
        }
    }

    @MainActor var isPublishing: Bool {
        get {
            PlanetStatusViewModel.shared.publishingPlanets.contains(id!)
        }
        set {
            if newValue {
                PlanetStatusViewModel.shared.publishingPlanets.insert(id!)
            } else {
                PlanetStatusViewModel.shared.publishingPlanets.remove(id!)
            }
        }
    }

    static func createMyPlanet(name: String, about: String, templateName: String) async throws -> Planet {
        let id = UUID()
        let key = try await IPFSDaemon.shared.generateKey(name: id.uuidString)
        let planet = Planet()
        planet.id = id
        planet.type = .planet
        planet.created = Date()
        planet.name = name.sanitized()
        planet.about = about
        // representation of my planet: keyName != nil && keyID != nil
        // keyName stores name of key in IPFS keystore, which is planet UUID
        // keyID stores the "k5" public key of IPNS, which is the same as IPNS
        // TODO: simplify CoreData properties
        planet.keyName = id.uuidString
        planet.keyID = key
        planet.ipns = key
        planet.templateName = templateName
        PlanetDataController.shared.save()

        try? FileManager.default.createDirectory(at: planet.baseURL, withIntermediateDirectories: true)
        return planet
    }

    static func importMyPlanet(importURL: URL) throws -> Planet {
        let infoURL = importURL.appendingPathComponent("planet.json", isDirectory: false)
        let assetsURL = importURL.appendingPathComponent("assets", isDirectory: true)
        let indexURL = importURL.appendingPathComponent("index.html", isDirectory: false)
        let keyURL = importURL.appendingPathComponent("planet.key", isDirectory: false)
        let avatarURL = importURL.appendingPathComponent("avatar.png", isDirectory: false)

        guard FileManager.default.fileExists(atPath: infoURL.path),
              FileManager.default.fileExists(atPath: keyURL.path)
        else {
            throw PlanetError.ImportPlanetError
        }

        let decoder = JSONDecoder()
        guard let data = try? Data.init(contentsOf: infoURL),
              let planetInfo = try? decoder.decode(PlanetFeed.self, from: data)
        else {
            throw PlanetError.ImportPlanetError
        }

        guard PlanetDataController.shared.getPlanet(id: planetInfo.id) == nil else {
            throw PlanetError.PlanetExistsError
        }

        do {
            try IPFSCommand.importKey(name: planetInfo.id.uuidString, target: keyURL).run()
        } catch {
            throw PlanetError.IPFSError
        }

        // create planet
        let planet = Planet()
        planet.id = planetInfo.id
        planet.name = planetInfo.name
        planet.about = planetInfo.about
        planet.created = planetInfo.created
        planet.lastUpdated = planetInfo.updated
        planet.keyName = planetInfo.id.uuidString
        planet.keyID = planetInfo.ipns
        planet.ipns = planetInfo.ipns
        if let templateName = planetInfo.templateName, TemplateBrowserStore.shared.hasTemplate(named: templateName) {
            planet.templateName = templateName
        } else {
            planet.templateName = "Plain"
        }

        // delete existing local planet file if exists
        if FileManager.default.fileExists(atPath: planet.baseURL.path) {
            try? FileManager.default.removeItem(at: planet.baseURL)
        }
        do {
            try FileManager.default.createDirectory(at: planet.baseURL, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: infoURL, to: planet.infoURL)
            if FileManager.default.fileExists(atPath: assetsURL.path) {
                try FileManager.default.copyItem(at: assetsURL, to: planet.assetsURL)
            }
            if FileManager.default.fileExists(atPath: indexURL.path) {
                try FileManager.default.copyItem(at: indexURL, to: planet.indexURL)
            }
            if FileManager.default.fileExists(atPath: avatarURL.path) {
                try FileManager.default.copyItem(at: avatarURL, to: planet.avatarURL)
            }
            // import articles
            for articleInfo in planetInfo.articles {
                let articleURL = importURL.appendingPathComponent(articleInfo.id.uuidString, isDirectory: true)
                if FileManager.default.fileExists(atPath: articleURL.path) {
                    let article = PlanetArticle()
                    article.id = articleInfo.id
                    article.title = articleInfo.title
                    article.content = articleInfo.content
                    article.planetID = planet.id
                    article.link = articleInfo.link
                    article.created = articleInfo.created
                    PlanetDataController.shared.save()
                    try FileManager.default.copyItem(at: articleURL, to: article.baseURL)
                }
            }
        } catch {
            planet.softDeleted = Date()
            throw PlanetError.ImportPlanetError
        }

        return planet
    }

    func export(exportDirectory: URL) throws {
        let exportURL = exportDirectory.appendingPathComponent("\(name!.sanitized()).planet", isDirectory: true)
        guard !FileManager.default.fileExists(atPath: exportURL.path) else {
            throw PlanetError.FileExistsError
        }

        guard isMyPlanet(),
              FileManager.default.fileExists(atPath: infoURL.path),
              FileManager.default.fileExists(atPath: indexURL.path)
        else {
            throw PlanetError.ExportPlanetError
        }

        do {
            try FileManager.default.copyItem(at: baseURL, to: exportURL)
            let keyPath = exportURL.appendingPathComponent("planet.key", isDirectory: false)
            try IPFSCommand.exportKey(name: id!.uuidString, target: keyPath).run()
        } catch {
            throw PlanetError.ExportPlanetError
        }

        NSWorkspace.shared.activateFileViewerSelecting([exportURL])
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

struct PlanetPublished: Codable {
    let name: String
    let value: String

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case value = "Value"
    }
}
