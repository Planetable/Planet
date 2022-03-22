//
//  PlanetDataController.swift
//  Planet
//
//  Created by Kai on 2/15/22.
//

import SwiftUI
import Foundation
import CoreData
import FeedKit


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
            debugPrint("Store Description: \(storeDescription)")
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

    func createPlanet(withID id: UUID, name: String, about: String, keyName: String?, keyID: String?, ipns: String?) -> Planet? {
        let ctx = persistentContainer.newBackgroundContext()
        let planet = Planet(context: ctx)
        planet.id = id
        planet.type = .planet
        planet.created = Date()
        planet.name = name.sanitized()
        planet.about = about
        planet.keyName = keyName
        planet.keyID = keyID
        planet.ipns = ipns
        do {
            try ctx.save()
            debugPrint("Type 0 Planet created: \(planet)")
            PlanetManager.shared.setupDirectory(forPlanet: planet)
            return planet
        } catch {
            debugPrint("Failed to create new Type 0 Planet: \(planet), error: \(error)")
            return nil
        }
    }

    func createPlanetENS(ens: String) -> Planet? {
        let ctx = persistentContainer.newBackgroundContext()
        let planet = Planet(context: ctx)
        planet.id = UUID()
        planet.type = .ens
        planet.created = Date()
        planet.name = ens
        planet.about = ""
        planet.ens = ens
        do {
            try ctx.save()
            debugPrint("Type 1 ENS planet created: \(ens)")
            PlanetManager.shared.setupDirectory(forPlanet: planet)
            return planet
        } catch {
            debugPrint("Failed to create new Type 1 Planet: \(ens), error: \(error)")
            return nil
        }
    }

    func checkUpdateForPlanetENS(planet: Planet) async {
        if let id = planet.id, let ens = planet.ens {
//            let url = URL(string: "http://192.168.192.80:3000/ens/\(ens)")!
            let url = URL(string: "http://192.168.1.200:3000/ens/\(ens)")!
            debugPrint("Trying to parse ENS: \(planet.ens!) with API url: \(url)")
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                debugPrint("ENS metadata retrieved: \(String(data: data, encoding: .utf8) ?? "")")
                let json = try JSONSerialization.jsonObject(with: data, options: [])
                if let dictionary = json as? [String: Any] {
                    if let contentHash = dictionary["content_hash"] as? String {
                        debugPrint("ENS IPFS content hash found: \(contentHash)")
                        if contentHash.hasPrefix("ipfs://") {
                            let ipfs = contentHash.replacingOccurrences(of: "ipfs://", with: "")
                            updatePlanetENSContentHash(forID: id, contentHash: ipfs)
                            await checkContentUpdateForPlanetENS(forID: id, ipfs: ipfs)
                        } else {
                            debugPrint("ENS content hash is not an IPFS hash: \(contentHash)")
                        }
                    }
                }
            } catch {
                debugPrint("Error loading ENS metadata: \(url): \(String(describing: error))")
            }
        }
    }

    func checkContentUpdateForPlanetENS(forID id: UUID, ipfs: String) async {
        let url = URL(string: "http://127.0.0.1:\(PlanetManager.shared.gatewayPort)/ipfs/\(ipfs)")!
        debugPrint("Trying to access IPFS content: \(url)")
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    debugPrint("IPFS content returns 200 OK: \(url)")
                    // Try detect if there is a feed
                    // The better way would be to parse the HTML and check if it has a feed
                    let feedURL = URL(string: "http://127.0.0.1:\(PlanetManager.shared.gatewayPort)/ipfs/\(ipfs)/feed.xml")!
                    Task.init(priority: .background) {
                        await parseFeedForPlanet(forID: id, feedURL: feedURL)
                    }
                } else {
                    debugPrint("IPFS content returns \(httpResponse.statusCode): \(url)")
                }
            }
        }
        catch {
           debugPrint("Error loading IPFS content: \(url): \(String(describing: error))")
        }
    }

    func parseFeedForPlanet(forID id: UUID, feedURL: URL) async {
        let parser = FeedParser(URL: feedURL)
        parser.parseAsync(queue: DispatchQueue.global(qos: .userInitiated)) { (result) in
            // Do your thing, then back to the Main thread
            switch result {
                case .success(let feed):
                    switch feed {
                        case let .atom(feed):       // Atom Syndication Format Feed Model
                            debugPrint(feed)
                        case let .rss(feed):        // Really Simple Syndication Feed Model
                            var articles: [PlanetFeedArticle] = []
                            for item in feed.items! {
                                guard let itemLink = URL(string: item.link!) else { continue }
                                guard let itemTitle = item.title else { continue }
                                let itemDescription = item.description ?? ""
                                let itemPubdate = item.pubDate ?? Date()
                                debugPrint("\(itemTitle) \(itemLink.path)")
                                let a = PlanetFeedArticle(id: UUID(), created: itemPubdate, title: itemTitle, content: itemDescription, link: itemLink.path)
                                articles.append(a)
                            }
                            debugPrint("RSS: Found \(articles.count) articles")
                            PlanetDataController.shared.batchCreateRSSArticles(articles: articles, planetID: id)
                        case let .json(feed):       // JSON Feed Model
                            debugPrint(feed)
                    }
                case .failure(let error):
                    print(error)
                }
            DispatchQueue.main.async {
                // ..and update the UI
            }
        }
    }

    func updatePlanetMetadata(forID id: UUID, name: String?, about: String?, ipns: String?) {
        let ctx = persistentContainer.newBackgroundContext()
        guard let planet = getPlanet(id: id) else { return }
        if let name = name {
            planet.name = name
        }
        if let about = about {
            planet.about = about
        }
        if let ipns = ipns {
            planet.ipns = ipns
        }
        do {
            try ctx.save()
            debugPrint("planet updated: \(planet)")
        } catch {
            debugPrint("failed to update planet: \(planet), error: \(error)")
        }
    }

    func updatePlanetFeedSHA256(forID id: UUID, feedSHA256: String) {
        let ctx = persistentContainer.newBackgroundContext()
        guard let planet = getPlanet(id: id) else { return }
        planet.feedSHA256 = feedSHA256
        do {
            try ctx.save()
            debugPrint("Planet feed SHA256 updated: \(planet.feedSHA256)")
        } catch {
            debugPrint("Failed to update planet feed SHA256: \(planet), error: \(error)")
        }
    }

    func updatePlanetENSContentHash(forID id: UUID, contentHash: String) {
        let ctx = persistentContainer.newBackgroundContext()
        guard let planet = getPlanet(id: id) else { return }
        planet.ipfs = contentHash
        do {
            try ctx.save()
            debugPrint("ENS planet IPFS content hash updated: \(planet.name) \(contentHash)")
        } catch {
            debugPrint("failed to update planet: \(planet.name), error: \(error)")
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

    func updateArticleReadStatus(article: PlanetArticle, read: Bool = true) {
        let ctx = persistentContainer.newBackgroundContext()
        guard let a = getArticle(id: article.id!) else { return }
        if read {
            a.read = Date()
        } else {
            a.setNilValueForKey("read")
        }
        do {
            try ctx.save()
            debugPrint("Read: article read status updated: \(a.read)")
        } catch {
            debugPrint("Read: failed to update article read status: \(a), error: \(error)")
        }
    }

    func createArticle(withID id: UUID, forPlanet planetID: UUID, title: String, content: String, link: String) async {
        guard _articleExists(id: id) == false else { return }
        let ctx = persistentContainer.newBackgroundContext()
        let article = PlanetArticle(context: ctx)
        article.id = UUID()
        article.planetID = planetID
        article.title = title
        article.content = content
        article.link = link
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

    func batchUpdateArticles(articles: [PlanetFeedArticle], planetID: UUID) async {
        let ctx = persistentContainer.newBackgroundContext()
        for article in articles {
            let a = PlanetDataController.shared.getArticle(id: article.id)
            if a != nil {
                a!.title = article.title
                a!.link = article.link ?? "/\(a!.id)/"
            }
        }
        do {
            try ctx.save()
            debugPrint("planet articles updated: \(articles)")
            // MARK: TODO: cache following planets' articles.
        } catch {
            debugPrint("failed to batch update planet articles: \(articles), error: \(error)")
        }
    }

    func batchCreateArticles(articles: [PlanetFeedArticle], planetID: UUID) async {
        let ctx = persistentContainer.newBackgroundContext()
        for article in articles {
            let a = PlanetArticle(context: ctx)
            a.id = UUID()
            a.planetID = planetID
            a.title = article.title
            a.link = article.link
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

    func batchCreateRSSArticles(articles: [PlanetFeedArticle], planetID: UUID) {
        let ctx = persistentContainer.newBackgroundContext()
        for article in articles {
            let a = PlanetDataController.shared.getArticle(link: article.link!, planetID: planetID)
            if a == nil {
                let newArticle = PlanetArticle(context: ctx)
                newArticle.id = UUID()
                newArticle.planetID = planetID
                newArticle.title = article.title
                newArticle.link = article.link
                newArticle.created = article.created
            }
        }
        do {
            try ctx.save()
            debugPrint("planet RSS articles created: \(articles)")
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
                            debugPrint("about to refresh article: \(article) ...")
                            NotificationCenter.default.post(name: .refreshArticle, object: id)
                        }
                    }
                }
                await PlanetManager.shared.publishForPlanet(planet: planet)
                do {
                    try await PlanetDataController.shared.pingPublicGatewayForArticle(article: article, gateway: .dweb)
                    try await PlanetDataController.shared.pingPublicGatewayForArticle(article: article, gateway: .cloudflare)
                    try await PlanetDataController.shared.pingPublicGatewayForArticle(article: article, gateway: .ipfs)
                } catch {
                    // handle the error here in some way
                }
            }
        }
    }

    func getArticlePublicLink(article: PlanetArticle, gateway: PublicGateway = .dweb) -> String {
        guard let planet = getPlanet(id: article.planetID!) else { return "" }
        switch (planet.type) {
            case .planet:
                return "https://\(gateway.rawValue)/ipns/\(planet.ipns!)\(article.link!)"
            case .ens:
                return "https://\(gateway.rawValue)/ipfs/\(planet.ipfs!)\(article.link!)"
            default:
                return "https://\(gateway.rawValue)/ipns/\(planet.ipns!)\(article.link!)"
        }
    }

    func copyPublicLinkOfArticle(_ article: PlanetArticle) {
        let publicLink = getArticlePublicLink(article: article, gateway: .cloudflare)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(publicLink, forType: .string)
    }

    func pingPublicGatewayForArticle(article: PlanetArticle, gateway: PublicGateway = .dweb) async throws {
        let publicLink = getArticlePublicLink(article: article, gateway: gateway)
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

    func getArticle(link: String, planetID: UUID) -> PlanetArticle? {
        let request: NSFetchRequest<PlanetArticle> = PlanetArticle.fetchRequest()
        let predicate1: NSPredicate = NSPredicate(format: "link == %@", link as CVarArg)
        let predicate2: NSPredicate = NSPredicate(format: "planetID == %@", planetID as CVarArg)
        let predicateCompound = NSCompoundPredicate.init(type: .and, subpredicates: [predicate1, predicate2])
        request.predicate = predicateCompound
        let context = persistentContainer.viewContext
        do {
            return try context.fetch(request).first
        } catch {
            debugPrint("failed to get article: \(error), link: \(link), planetID: \(planetID)")
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
            return !a.isRead
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

    private func _articleExists(id: UUID) -> Bool {
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

    private func _articleExists(link: String, planetID: UUID) -> Bool {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "PlanetArticle")
        let predicate1: NSPredicate = NSPredicate(format: "link == %@", link as CVarArg)
        let predicate2: NSPredicate = NSPredicate(format: "planetID == %@", planetID as CVarArg)
        let predicateCompound = NSCompoundPredicate.init(type: .and, subpredicates: [predicate1, predicate2])
        request.predicate = predicateCompound
        do {
            let count = try context.count(for: request)
            return count != 0
        } catch {
            return false
        }
    }

    private func _planetExists(id: UUID) -> Bool {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Planet")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        do {
            let count = try context.count(for: request)
            return count != 0
        } catch {
            return false
        }
    }
}
