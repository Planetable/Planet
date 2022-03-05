//
//  PlanetDataController.swift
//  Planet
//
//  Created by Kai on 2/15/22.
//

import SwiftUI
import Foundation
import CoreData


enum PublicGateway: String {
    case cloudflare = "www.cloudflare-ipfs.com"
    case ipfs = "ipfs.io"
    case dweb = "dweb.link"
}

class PlanetDataController: NSObject {
    static let shared: PlanetDataController = .init()

    let titles = ["Hello and Welcome", "Hello World", "New Content Here!"]
    let contents = ["No content yet.", "This is a demo content.", "Hello from planet demo."]

    var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Planet")
        container.loadPersistentStores { storeDescription, error in
            if let error = error {
                fatalError("Unable to load data store: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()

    // MARK: - -
    func saveContext() {
        let context = persistentContainer.viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            debugPrint("failed to save data store: \(error)")
        }
    }

    func createPlanet(withID id: UUID, name: String, about: String, keyName: String?, keyID: String?, ipns: String?) {
        let ctx = persistentContainer.newBackgroundContext()
        let planet = Planet(context: ctx)
        planet.id = id
        planet.created = Date()
        planet.name = name
        planet.about = about
        planet.keyName = keyName
        planet.keyID = keyID
        planet.ipns = ipns
        do {
            try ctx.save()
            debugPrint("planet created: \(planet)")
            PlanetManager.shared.setupDirectory(forPlanet: planet)
        } catch {
            debugPrint("failed to create new planet: \(planet), error: \(error)")
        }
    }

    func updatePlanet(withID id: UUID, name: String, about: String) {
        let ctx = persistentContainer.newBackgroundContext()
        guard let planet = getPlanet(id: id) else { return }
        planet.name = name
        planet.about = about
        do {
            try ctx.save()
            Task.init(priority: .utility) {
                await PlanetManager.shared.publishForPlanet(planet: planet)
            }
        } catch {
            debugPrint("failed to update planet: \(planet), error: \(error)")
        }
    }

    func createArticle(withID id: UUID, forPlanet planetID: UUID, title: String, content: String) async {
        guard _articleExists(id: id) == false else { return }
        let ctx = persistentContainer.newBackgroundContext()
        let article = PlanetArticle(context: ctx)
        article.id = id
        article.planetID = planetID
        article.title = title
        article.content = content
        article.created = Date()
        do {
            try ctx.save()
            debugPrint("planet article created: \(article)")
            guard let planet = getPlanet(id: planetID), planet.isMyPlanet() else { return }
            await PlanetManager.shared.renderArticleToDirectory(fromArticle: article)
            await PlanetManager.shared.publishForPlanet(planet: planet)
        } catch {
            debugPrint("failed to create new planet article: \(article), error: \(error)")
        }
    }

    func batchCreateArticles(articles: [PlanetFeedArticle], planetID: UUID) async {
        let ctx = persistentContainer.newBackgroundContext()
        for article in articles {
            let a = PlanetArticle(context: ctx)
            a.id = article.id
            a.planetID = planetID
            a.title = article.title
            a.created = article.created
        }
        do {
            try ctx.save()
            debugPrint("planet articles created: \(articles)")
            // MARK: TODO: cache following planets' articles.
        } catch {
            debugPrint("failed to batch create new planet articles: \(articles), error: \(error)")
        }
    }

    func batchDeleteArticles(articles: [PlanetArticle]) async {
        let ctx = persistentContainer.viewContext
        for a in articles {
            ctx.delete(a)
        }
        do {
            try ctx.save()
        } catch {
            debugPrint("failed to delete articles: \(error)")
        }
    }

    func updateArticle(withID id: UUID, title: String, content: String) {
        let ctx = persistentContainer.newBackgroundContext()
        guard let article = getArticle(id: id) else { return }
        article.title = title
        article.content = content
        do {
            try ctx.save()
            refreshArticle(article)
        } catch {
            debugPrint("failed to update planet article: \(article), error: \(error)")
        }
    }

    func refreshArticle(_ article: PlanetArticle) {
        Task.init(priority: .utility) {
            guard let planet = getPlanet(id: article.planetID!) else { return }
            if planet.isMyPlanet() {
                await PlanetManager.shared.renderArticleToDirectory(fromArticle: article)
                if let id = article.id {
                    DispatchQueue.global(qos: .background).async {
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: .refreshArticle, object: id)
                        }
                    }
                }
                await PlanetManager.shared.publishForPlanet(planet: planet)
                do {
                    try await PlanetDataController.shared.pingPublicGatewayForArticle(article)
                } catch {
                    // handle the error here in some way
                }
            }
        }
    }

    func getArticlePublicLink(article: PlanetArticle, gateway: PublicGateway = .dweb) -> String {
        guard let planet = getPlanet(id: article.planetID!) else { return "" }
        let publicLink = "https://\(gateway.rawValue)/ipns/\(planet.ipns!)/\(article.id!.uuidString)/"
        return publicLink
    }

    func copyPublicLinkOfArticle(_ article: PlanetArticle) {
        let publicLink = getArticlePublicLink(article: article, gateway: .cloudflare)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(publicLink, forType: .string)
    }

    func pingPublicGatewayForArticle(_ article: PlanetArticle) async throws {
        let publicLink = getArticlePublicLink(article: article, gateway: .dweb)
        guard let url = URL(string: publicLink) else {
            return
        }

        // Use the async variant of URLSession to fetch data
        // Code might suspend here
        let (_, _) = try await URLSession.shared.data(from: url)

        debugPrint("Pinged public gateway: \(publicLink)")
    }

    func removePlanet(planet: Planet) {
        guard planet.id != nil else { return }
        let uuid = planet.id!
        let context = persistentContainer.viewContext
        let articlesToDelete = getArticles(byPlanetID: uuid)
        for a in articlesToDelete {
            context.delete(a)
        }
        context.delete(planet)
        do {
            try context.save()
            PlanetManager.shared.destroyDirectory(fromPlanet: uuid)
            self.reportDatabaseStatus()
            DispatchQueue.main.async {
                PlanetStore.shared.selectedPlanet = UUID().uuidString
                PlanetStore.shared.selectedArticle = UUID().uuidString
            }
        } catch {
            debugPrint("failed to delete planet: \(planet), error: \(error)")
        }
    }

    func getPlanet(id: UUID) -> Planet? {
        let request: NSFetchRequest<Planet> = Planet.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        let context = persistentContainer.viewContext
        do {
            return try context.fetch(request).first
        } catch {
            debugPrint("failed to get planet: \(error), target uuid: \(id)")
        }
        return nil
    }

    func getArticle(id: UUID) -> PlanetArticle? {
        let request: NSFetchRequest<PlanetArticle> = PlanetArticle.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        let context = persistentContainer.viewContext
        do {
            return try context.fetch(request).first
        } catch {
            debugPrint("failed to get article: \(error), target uuid: \(id)")
        }
        return nil
    }

    func getArticles(byPlanetID id: UUID) -> [PlanetArticle] {
        let request: NSFetchRequest<PlanetArticle> = PlanetArticle.fetchRequest()
        request.predicate = NSPredicate(format: "planetID == %@", id as CVarArg)
        let context = persistentContainer.viewContext
        do {
            return try context.fetch(request)
        } catch {
            debugPrint("failed to get article: \(error), target uuid: \(id)")
        }
        return []
    }

    func getArticleStatus(byPlanetID id: UUID) -> (unread: Int, total: Int) {
        var unread: Int = 0
        var total: Int = 0
        let articles = getArticles(byPlanetID: id)
        total = articles.count
        unread = articles.filter({ a in
            return !PlanetManager.shared.articleReadingStatus(article: a)
        }).count
        return (unread, total)
    }

    func getLocalIPNSs() -> Set<String> {
        let request: NSFetchRequest<Planet> = Planet.fetchRequest()
        request.predicate = NSPredicate(format: "keyName != null && keyID != null")
        let context = persistentContainer.viewContext
        do {
            let results = try context.fetch(request)
            let ids: [String] = results.map() { r in
                return r.ipns ?? ""
            }
            debugPrint("got local ipns: \(ids)")
            return Set(ids)
        } catch {
            debugPrint("failed to get planets: \(error)")
        }
        return Set()
    }

    func getFollowingIPNSs() -> Set<String> {
        let request: NSFetchRequest<Planet> = Planet.fetchRequest()
        request.predicate = NSPredicate(format: "keyName == null && keyID == null")
        let context = persistentContainer.viewContext
        do {
            let results = try context.fetch(request)
            let ids: [String] = results.map() { r in
                return r.ipns ?? ""
            }
            debugPrint("got following ipns: \(ids)")
            return Set(ids)
        } catch {
            debugPrint("failed to get planets: \(error)")
        }
        return Set()
    }

    func getLocalPlanets() -> Set<Planet> {
        let request: NSFetchRequest<Planet> = Planet.fetchRequest()
        request.predicate = NSPredicate(format: "keyName != null && keyID != null")
        let context = persistentContainer.viewContext
        do {
            let results = try context.fetch(request)
            let planets: [Planet] = results.map() { r in
                return r
            }
            return Set(planets)
        } catch {
            debugPrint("failed to get planets: \(error)")
        }
        return Set()
    }

    func getFollowingPlanets() -> Set<Planet> {
        let request: NSFetchRequest<Planet> = Planet.fetchRequest()
        request.predicate = NSPredicate(format: "keyName == null && keyID == null")
        let context = persistentContainer.viewContext
        do {
            let results = try context.fetch(request)
            let planets: [Planet] = results.map() { r in
                return r
            }
            return Set(planets)
        } catch {
            debugPrint("failed to get planets: \(error)")
        }
        return Set()
    }

    func removeArticle(article: PlanetArticle) {
        let uuid = article.id!
        let planetUUID = article.planetID!
        let context = persistentContainer.viewContext
        context.delete(article)
        do {
            try context.save()
            PlanetManager.shared.destroyArticleDirectory(planetUUID: planetUUID, articleUUID: uuid)
            reportDatabaseStatus()
            DispatchQueue.main.async {
                PlanetStore.shared.selectedArticle = UUID().uuidString
            }
        } catch {
            debugPrint("failed to delete article: \(article), error: \(error)")
        }
    }

    func reportDatabaseStatus() {
        let articlesCountRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "PlanetArticle")
        let articlesCount: Int = try! persistentContainer.viewContext.count(for: articlesCountRequest)
        let planetsCountRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Planet")
        let planetsCount: Int = try! persistentContainer.viewContext.count(for: planetsCountRequest)
        debugPrint("context saved, now articles count: \(articlesCount), planets count: \(planetsCount)")
        if planetsCount == 0 && articlesCount > 0 {
            debugPrint("cleanup articles without planets.")
            let context = persistentContainer.viewContext
            let removeRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "PlanetArticle")
            do {
                let articles = try context.fetch(removeRequest)
                for a in articles {
                    context.delete(a as! NSManagedObject)
                }
                try context.save()
                reportDatabaseStatus()
            } catch {
                debugPrint("failed to get articles: \(error)")
            }
        }
    }

    func resetDatabase() {
        let context = persistentContainer.viewContext
        let removePlanetRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Planet")
        let removePlanetArticleRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "PlanetArticle")
        do {
            let planets = try context.fetch(removePlanetRequest)
            let _ = planets.map() { p in
                context.delete(p as! NSManagedObject)
            }
            let articles = try context.fetch(removePlanetArticleRequest)
            let _ = articles.map() { a in
                context.delete(a as! NSManagedObject)
            }
            try context.save()
        } catch {
            debugPrint("failed to reset database: \(error)")
        }
    }

    func _articleExists(id: UUID) -> Bool {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "PlanetArticle")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        do {
            let count = try context.count(for: request)
            return count != 0
        } catch {
            return false
        }
    }
}
