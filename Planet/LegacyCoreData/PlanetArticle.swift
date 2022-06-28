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

    var asNewMyArticle: MyArticleModel? {
        guard let articleID = id else { return nil }
        let articleLink = link ?? "/\(articleID)/"
        let articleTitle = title ?? ""
        let articleContent = content ?? ""
        let articleCreated = created ?? Date()
        let articleStarred = starred

        let newModel: MyArticleModel = MyArticleModel(
            id: articleID,
            link: articleLink,
            title: articleTitle,
            content: articleContent,
            created: articleCreated,
            starred: articleStarred
        )
        return newModel
    }

    var asNewFollowingArticle: FollowingArticleModel? {
        guard let articleID = id else { return nil }
        let articleLink = link ?? "/\(articleID)/"
        let articleTitle = title ?? ""
        let articleContent = content ?? ""
        let articleCreated = created ?? Date()
        let articleRead = read
        let articleStarred = starred

        let newModel: FollowingArticleModel = FollowingArticleModel(
            id: articleID,
            link: articleLink,
            title: articleTitle,
            content: articleContent,
            created: articleCreated,
            read: articleRead,
            starred: articleStarred
        )
        return newModel
    }
}
