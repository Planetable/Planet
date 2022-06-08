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
}
