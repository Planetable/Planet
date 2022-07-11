//
//  Planet.swift
//  Planet
//
//  Created by Kai on 11/12/21.
//

import Foundation
import SwiftUI
import Cocoa

enum FeedType: Int32 {
    case none = 0
    case planet = 1
    case jsonfeed = 2
    case rss = 3
    case atom = 4
}

class Planet: NSManagedObject {
    convenience init() {
        self.init(context: CoreDataPersistence.shared.viewContext)
    }

    func isMyPlanet() -> Bool {
        if let keyID = keyID, let keyName = keyName {
            return keyID != "" && keyName != ""
        }
        return false
    }

    var type: PlanetType {
        get {
            PlanetType(rawValue: Int(typeValue))!
        }

        set {
            typeValue = Int32(newValue.rawValue)
        }
    }

    var feedType: FeedType {
        get {
            FeedType(rawValue: feedTypeValue)!
        }

        set {
            feedTypeValue = newValue.rawValue
        }
    }

    var baseURL: URL {
        URLUtils.legacyPlanetsPath.appendingPathComponent(id!.uuidString, isDirectory: true)
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

    var asNewFollowingPlanet: FollowingPlanetModel? {
        guard let planetID = id else { return nil }
        let planetType = type
        guard let planetName = name else { return nil }
        guard let planetAbout = about else { return nil }
        var planetLink: String
        switch (type) {
        case .planet:
            guard let planetIPNS = ipns else { return nil }
            planetLink = planetIPNS
        case .ens:
            guard let planetENS = ens else { return nil }
            planetLink = planetENS
        case .dns:
            guard let planetFeedAddress = feedAddress else { return nil }
            planetLink = planetFeedAddress
        default:
            return nil
        }
        var planetCID: String? = nil
        if let cid = latestCID {
            if cid.starts(with: "/ipfs/") {
                planetCID = String(cid.dropFirst("/ipfs/".count))
            } else {
                planetCID = cid
            }
        }
        let planetCreated = created ?? Date()
        let planetUpdated = lastUpdated ?? planetCreated
        let planetLastRetrieved = lastUpdated ?? planetCreated
        let newModel: FollowingPlanetModel = FollowingPlanetModel(
            id: planetID,
            planetType: planetType,
            name: planetName,
            about: planetAbout,
            link: planetLink,
            cid: planetCID,
            created: planetCreated,
            updated: planetUpdated,
            lastRetrieved: planetLastRetrieved
        )
        return newModel
    }

    var asNewMyPlanet: MyPlanetModel? {
        guard let planetID = id else { return nil }
        guard let planetName = name else { return nil }
        let planetAbout = about ?? ""
        guard let planetIPNS = ipns else { return nil }
        let planetCreated = created ?? Date()
        let planetUpdated = lastUpdated ?? planetCreated
        let planetLastPublished = lastPublished ?? nil
        let planetTemplateName = templateName ?? "Plain"

        let newModel: MyPlanetModel = MyPlanetModel(
            id: planetID,
            name: planetName,
            about: planetAbout,
            ipns: planetIPNS,
            created: planetCreated,
            updated: planetUpdated,
            lastPublished: planetLastPublished,
            templateName: planetTemplateName
        )
        return newModel
    }
}
