import Foundation
import CoreData

class PlanetArticle: NSManagedObject {
    var isRead: Bool {
        get {
            read != nil
        }

        set {
            if newValue {
                read = Date()
            } else {
                read = nil
            }
        }
    }

    var readElapsed: Int32 {
        if read == nil {
            return 0
        } else {
            let now = Date()
            let diff = now.timeIntervalSince1970 - read!.timeIntervalSince1970
            return Int32(diff)
        }
    }

    var isStarred: Bool {
        get {
            starred != nil
        }

        set {
            if newValue {
                starred = Date()
            } else {
                starred = nil
            }
        }
    }

    // var isMine: Bool {
    //     if let aPlanetID = planetID {
    //         if let aPlanet = CoreDataPersistence.shared.getPlanet(id: aPlanetID) {
    //             return aPlanet.isMyPlanet()
    //         } else {
    //             return false
    //         }
    //     } else {
    //         return false
    //     }
    // }

    var baseURL: URL {
        URLUtils.legacyPlanetsPath.appendingPathComponent(planetID!.uuidString, isDirectory: true)
            .appendingPathComponent(id!.uuidString, isDirectory: true)
    }

    var infoURL: URL {
        baseURL.appendingPathComponent("article.json", isDirectory: false)
    }

    var indexURL: URL {
        baseURL.appendingPathComponent("index.html", isDirectory: false)
    }
}
