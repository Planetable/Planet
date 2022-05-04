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
import ENSKit


enum PublicGateway: String {
    case cloudflare = "www.cloudflare-ipfs.com"
    case ipfs = "ipfs.io"
    case dweb = "dweb.link"
}

class PlanetDataController: NSObject {
    static let shared: PlanetDataController = .init()

    let titles = ["Hello and Welcome", "Hello World", "New Content Here!"]
    let contents = ["No content yet.", "This is a demo content.", "Hello from planet demo."]

    // let enskit = ENSKit(jsonrpcClient: InfuraEthereumAPI(url: URL(string: "https://mainnet.infura.io/v3/<projectid>")!))
    let enskit = ENSKit(ipfsClient: GoIPFSGateway())

    var persistentContainer: NSPersistentContainer

    override init() {
        persistentContainer = NSPersistentContainer(name: "Planet")
        persistentContainer.loadPersistentStores { storeDescription, error in
            debugPrint("Store Description: \(storeDescription)")
            if let error = error {
                fatalError("Unable to load data store: \(error)")
            }
        }
        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
    }

    func save(context: NSManagedObjectContext? = nil) {
        let ctx = context ?? persistentContainer.viewContext
        guard ctx.hasChanges else { return }
        do {
            try ctx.save()
        } catch {
            debugPrint("Failed to save persistent container: \(error)")
        }
    }

    // MARK: - Create Planet -

    func createPlanet(
            withID id: UUID,
            name: String,
            about: String,
            keyName: String?,
            keyID: String?,
            ipns: String?,
            context: NSManagedObjectContext? = nil
    ) -> Planet? {
        let ctx = context ?? persistentContainer.viewContext
        let planet = Planet(context: ctx)
        planet.id = id
        planet.type = .planet
        planet.created = Date()
        planet.name = name.sanitized()
        planet.about = about
        planet.keyName = keyName
        planet.keyID = keyID
        planet.ipns = ipns
        return planet
    }

    func createPlanet(ens: String, context: NSManagedObjectContext? = nil) -> Planet? {
        let ctx = context ?? persistentContainer.viewContext
        let planet = Planet(context: ctx)
        planet.id = UUID()
        planet.type = .ens
        planet.created = Date()
        planet.name = ens
        planet.about = ""
        planet.ens = ens
        return planet
    }

    func createPlanet(endpoint: String, context: NSManagedObjectContext? = nil) -> Planet? {
        guard let url = URL(string: endpoint) else { return nil }
        if url.path.count == 1 { return nil }
        let ctx = context ?? persistentContainer.viewContext
        let planet = Planet(context: ctx)
        planet.id = UUID()
        planet.type = .dns
        planet.created = Date()
        planet.name = url.host
        planet.about = ""
        planet.dns = url.host
        planet.feedAddress = endpoint
        return planet
    }

    // MARK: - Update Planet -

    func updateENSPlanet(planet: Planet) async throws {
        guard let ens = planet.ens else {
            // planet is not of ENS type
            throw PlanetError.InternalError
        }
        let result = try await enskit.resolve(name: ens)
        debugPrint("ENSKit.resolve(\(ens)) => \(String(describing: result))")
        if let contentHash = result,
           contentHash.scheme?.lowercased() == "ipfs" {
            // update content hash
            let s = contentHash.absoluteString
            let ipfs = String(s.suffix(from: s.index(s.startIndex, offsetBy: 7)))
            planet.ipfs = ipfs
            let url = URL(string: "\(PlanetManager.shared.ipfsGateway)/ipfs/\(ipfs)")!
            debugPrint("Trying to access IPFS content: \(url)")
            do {
                let (_, response) = try await URLSession.shared.data(from: url)
                let httpResponse = response as! HTTPURLResponse
                if !httpResponse.ok {
                    debugPrint("IPFS content returns \(httpResponse.statusCode): \(url)")
                    throw PlanetError.IPFSError
                }
            } catch {
                throw PlanetError.IPFSError
            }
            debugPrint("IPFS content OK: \(url)")
            if let IPFSContent = planet.IPFSContent {
                PlanetManager.shared.pin(IPFSContent)
            }
            // Try detect if there is a feed
            // The better way would be to parse the HTML and check if it has a feed
            let feedURL = URL(string: "\(PlanetManager.shared.ipfsGateway)/ipfs/\(ipfs)/feed.xml")!
            try await parsePlanetFeed(planet: planet, feedURL: feedURL)
        } else {
            throw PlanetError.InvalidPlanetURLError
        }

        let avatarResult = try await enskit.avatar(name: ens)
        debugPrint("ENSKit.avatar(\(ens)) => \(String(describing: avatarResult))")
        if let avatar = avatarResult, let image = NSImage(data: avatar) {
            PlanetManager.shared.updateAvatar(forPlanet: planet, image: image)
        }
    }

    func updateDNSPlanet(planet: Planet) async throws {
        if let feedAddress = planet.feedAddress {
            let url = URL(string: feedAddress)!
            try await parsePlanetFeed(planet: planet, feedURL: url)
        } else {
            throw PlanetError.InternalError
        }
    }

    func parsePlanetFeed(planet: Planet, feedURL: URL) async throws {
        let feedData: Data
        do {
            let (data, response) = try await URLSession.shared.data(from: feedURL)
            let httpResponse = response as! HTTPURLResponse
            if !httpResponse.ok {
                debugPrint("Get feed \(httpResponse.statusCode): \(feedURL)")
                throw PlanetError.NetworkError
            }
            feedData = data
        } catch {
            throw PlanetError.NetworkError
        }

        guard let id = planet.id else {
            throw PlanetError.InternalError
        }
        let parser = FeedParser(data: feedData)
        switch parser.parse() {
        case .success(let feed):
            var articles: [PlanetFeedArticle] = []
            switch feed {
            case let .atom(feed):       // Atom Syndication Format Feed
                for entry in feed.entries! {
                    guard let entryURL = URL(string: entry.links![0].attributes!.href!) else {
                        continue
                    }
                    let entryLink = "\(entryURL.scheme!)://\(entryURL.host!)\(entryURL.path)"
                    guard let entryTitle = entry.title else {
                        continue
                    }
                    let entryContent = entry.content?.attributes?.src ?? ""
                    let entryPublished = entry.published ?? Date()
                    let a = PlanetFeedArticle(id: UUID(), created: entryPublished, title: entryTitle, content: entryContent, link: entryLink)
                    articles.append(a)
                }
                debugPrint("Atom Feed: Found \(articles.count) articles")
            case let .rss(feed):        // Really Simple Syndication Feed
                for item in feed.items! {
                    guard let itemLink = URL(string: item.link!) else {
                        continue
                    }
                    guard let itemTitle = item.title else {
                        continue
                    }
                    let itemDescription = item.description ?? ""
                    let itemPubdate = item.pubDate ?? Date()
                    debugPrint("\(itemTitle) \(itemLink.path)")
                    let a = PlanetFeedArticle(id: UUID(), created: itemPubdate, title: itemTitle, content: itemDescription, link: itemLink.path)
                    articles.append(a)
                }
                debugPrint("RSS: Found \(articles.count) articles")
            case let .json(feed):       // JSON Feed
                PlanetDataController.shared.updatePlanet(planet: planet, name: feed.title, about: feed.description)
                // Fetch feed avatar if any
                if let imageURL = feed.icon {
                    let url = URL(string: imageURL)!
                    let data = try! Data(contentsOf: url)
                    if let image = NSImage(data: data) {
                        PlanetDataController.shared.updatePlanetAvatar(planet: planet, image: image)
                    }
                }
                for item in feed.items! {
                    guard let itemLink = URL(string: item.url!) else {
                        continue
                    }
                    guard let itemTitle = item.title else {
                        continue
                    }
                    let itemContentHTML = item.contentHtml ?? ""
                    let itemDatePublished = item.datePublished ?? Date()
                    debugPrint("\(itemTitle) \(itemLink.path)")
                    let a = PlanetFeedArticle(id: UUID(), created: itemDatePublished, title: itemTitle, content: itemContentHTML, link: item.url!)
                    articles.append(a)
                }
                debugPrint("JSON Feed: Found \(articles.count) articles")
            }
            PlanetDataController.shared.batchCreateFeedArticles(articles: articles, planetID: id)
        case .failure(_):
            throw PlanetError.PlanetFeedError
        }
    }

    func updatePlanet(planet: Planet, name: String?, about: String?) {
        if let name = name {
            planet.name = name
        }
        if let about = about {
            planet.about = about
        }
    }

    func updatePlanetAvatar(planet: Planet, image: NSImage) {
        do {
            let planetPath = PlanetManager.shared.planetsPath().appendingPathComponent(planet.id!.uuidString)
            if !FileManager.default.fileExists(atPath: planetPath.path) {
                try FileManager.default.createDirectory(at: planetPath, withIntermediateDirectories: true, attributes: nil)
            }
            let avatarPath = planetPath.appendingPathComponent("avatar.png")

            if FileManager.default.fileExists(atPath: avatarPath.path) {
                try FileManager.default.removeItem(at: avatarPath)
            }
            image.imageSave(avatarPath)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .updateAvatar, object: nil)
            }
        } catch {
            debugPrint("Planet Avatar failed to update: \(error)")
        }
    }

    func fixPlanet(_ planet: Planet) async {
        let articles = getArticles(byPlanetID: planet.id!)
        let ctx = persistentContainer.viewContext
        for article in articles {
            if let a = PlanetDataController.shared.getArticle(id: article.id!),
               planet.isMyPlanet(),
               a.link != "/\(a.id!.uuidString)/" {
                a.link = "/\(a.id!.uuidString)/"
            }
        }
        do {
            try ctx.save()
            debugPrint("Fix Planet Done: \(planet.id!) - \(planet.name ?? "Planet \(planet.id!.uuidString)")")
        } catch {
            debugPrint("Failed to batch fix planet articles: \(planet.name ?? "Planet \(planet.id!.uuidString)"), error: \(error)")
        }
    }

    func createArticle(_ article: PlanetFeedArticle, planetID: UUID, context: NSManagedObjectContext? = nil) -> PlanetArticle {
        let ctx = context ?? persistentContainer.viewContext
        let articleModel = PlanetArticle(context: ctx)
        articleModel.id = UUID()
        articleModel.planetID = planetID
        articleModel.title = article.title
        articleModel.link = article.link
        articleModel.created = article.created
        return articleModel
    }

    func batchImportArticles(articles: [PlanetFeedArticle], planetID: UUID) async {
        let ctx = persistentContainer.viewContext
        for article in articles {
            let a = PlanetArticle(context: ctx)
            a.id = article.id
            a.planetID = planetID
            a.title = article.title
            a.link = article.link
            a.created = article.created
        }
    }

    func batchCreateFeedArticles(articles: [PlanetFeedArticle], planetID: UUID) {
        let ctx = persistentContainer.viewContext
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
    }

    @discardableResult
    func updateArticle(withID id: UUID, title: String, content: String) async throws -> PlanetArticle {
        guard let article = getArticle(id: id) else {
            throw PlanetError.InternalError
        }
        article.title = title
        article.content = content
        if article.link == nil {
            article.link = "/\(id)/"
        }
        return article
    }
    
    @discardableResult
    func updateArticleLink(withID id: UUID, link: String) async throws -> PlanetArticle {
        guard let article = getArticle(id: id) else {
            throw PlanetError.InternalError
        }
        article.link = link
        return article
    }

    func refreshArticle(_ article: PlanetArticle) async {
        guard let planet = getPlanet(id: article.planetID!), planet.isMyPlanet() else {
            return
        }

        await PlanetManager.shared.renderArticleToDirectory(fromArticle: article)
        if let id = article.id {
            if article.link == nil {
                do {
                    try await self.updateArticleLink(withID: id, link: "/\(id)/")
                    PlanetDataController.shared.save()
                } catch {
                    debugPrint("Failed to update article link: \(article)")
                }
            }
            debugPrint("about to refresh article: \(article) ...")
            NotificationCenter.default.post(name: .refreshArticle, object: id)
        }
        await PlanetManager.shared.publish(planet)
        do {
            try await PlanetDataController.shared.pingPublicGatewayForArticle(article: article, gateway: .dweb)
            try await PlanetDataController.shared.pingPublicGatewayForArticle(article: article, gateway: .cloudflare)
            try await PlanetDataController.shared.pingPublicGatewayForArticle(article: article, gateway: .ipfs)
        } catch {
            // handle the error here in some way
        }
    }

    func getArticlePublicLink(article: PlanetArticle, gateway: PublicGateway = .dweb) -> String {
        guard let planet = getPlanet(id: article.planetID!) else { return "" }
        switch (planet.type) {
        case .planet:
            return "https://\(gateway.rawValue)/ipns/\(planet.ipns!)\(article.link!)"
        case .ens:
            return "https://\(gateway.rawValue)/ipfs/\(planet.ipfs!)\(article.link!)"
        case .dns:
            return "\(article.link!)"
        default:
            return "https://\(gateway.rawValue)/ipns/\(planet.ipns!)\(article.link!)"
        }
    }

    func copyPublicLinkOfArticle(_ article: PlanetArticle) {
        let publicLink = getArticlePublicLink(article: article, gateway: .dweb)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(publicLink, forType: .string)
    }

    func openInBrowser(_ article: PlanetArticle) {
        let publicLink = getArticlePublicLink(article: article, gateway: .dweb)
        if let url = URL(string: publicLink) {
            NSWorkspace.shared.open(url)
        }
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

    func remove(_ planet: Planet) async {
        planet.softDeleted = Date()
        for article in getArticles(byPlanetID: planet.id!) {
            article.softDeleted = Date()
        }
        await MainActor.run {
            PlanetStore.shared.currentPlanet = nil
            PlanetStore.shared.currentArticle = nil
        }
    }

    func getPlanet(id: UUID, context: NSManagedObjectContext? = nil) -> Planet? {
        let request: NSFetchRequest<Planet> = Planet.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@ && softDeleted == nil", id as CVarArg)
        let ctx = context ?? persistentContainer.viewContext
        do {
            return try ctx.fetch(request).first
        } catch {
            debugPrint("failed to get planet: \(error), target uuid: \(id)")
            return nil
        }
    }

    func getArticle(id: UUID, context: NSManagedObjectContext? = nil) -> PlanetArticle? {
        let request: NSFetchRequest<PlanetArticle> = PlanetArticle.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@ && softDeleted == nil", id as CVarArg)
        let ctx = context ?? persistentContainer.viewContext
        do {
            return try ctx.fetch(request).first
        } catch {
            debugPrint("failed to get article: \(error), target uuid: \(id)")
            return nil
        }
    }

    func getArticle(link: String, planetID: UUID, context: NSManagedObjectContext? = nil) -> PlanetArticle? {
        let request: NSFetchRequest<PlanetArticle> = PlanetArticle.fetchRequest()
        request.predicate = NSPredicate(format: "link == %@ && planetID = %@ && softDeleted == nil", link as CVarArg, planetID as CVarArg)
        let ctx = context ?? persistentContainer.viewContext
        do {
            return try ctx.fetch(request).first
        } catch {
            debugPrint("failed to get article: \(error), link: \(link), planetID: \(planetID)")
        }
        return nil
    }

    func getArticles(byPlanetID id: UUID, context: NSManagedObjectContext? = nil) -> [PlanetArticle] {
        let request: NSFetchRequest<PlanetArticle> = PlanetArticle.fetchRequest()
        request.predicate = NSPredicate(format: "planetID == %@ && softDeleted == nil", id as CVarArg)
        let ctx = context ?? persistentContainer.viewContext
        do {
            return try ctx.fetch(request)
        } catch {
            debugPrint("failed to get article: \(error), target uuid: \(id)")
        }
        return []
    }

    func getArticleStatus(byPlanetID id: UUID, context: NSManagedObjectContext? = nil) -> (unread: Int, total: Int) {
        let articles = getArticles(byPlanetID: id, context: context)
        let total = articles.count
        let unread = articles.filter { a in !a.isRead }.count
        return (unread, total)
    }

    func getLocalPlanets(context: NSManagedObjectContext? = nil) -> Set<Planet> {
        let request: NSFetchRequest<Planet> = Planet.fetchRequest()
        request.predicate = NSPredicate(format: "keyName != nil && keyID != nil && softDeleted == nil")
        let ctx = context ?? persistentContainer.viewContext
        do {
            let planets: [Planet] = try ctx.fetch(request)
            return Set(planets)
        } catch {
            debugPrint("failed to get planets: \(error)")
        }
        return Set()
    }

    func getFollowingPlanets(context: NSManagedObjectContext? = nil) -> Set<Planet> {
        let request: NSFetchRequest<Planet> = Planet.fetchRequest()
        request.predicate = NSPredicate(format: "keyName == nil && keyID == nil && softDeleted == nil")
        let ctx = context ?? persistentContainer.viewContext
        do {
            let planets = try ctx.fetch(request)
            return Set(planets)
        } catch {
            debugPrint("failed to get planets: \(error)")
        }
        return Set()
    }

    func planetExists(planetURL: String, context: NSManagedObjectContext? = nil) -> Bool {
        let request: NSFetchRequest<Planet> = Planet.fetchRequest()
        let notDeleted = NSPredicate(format: "softDeleted == nil")
        let sameIPNS = NSPredicate(format: "ipns == %@", planetURL as CVarArg)
        let sameENS = NSPredicate(format: "ens == %@", planetURL as CVarArg)
        let sameDNS = NSPredicate(format: "dns == %@", planetURL as CVarArg)
        let conflict = NSCompoundPredicate(orPredicateWithSubpredicates: [sameIPNS, sameENS, sameDNS])
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [notDeleted, conflict])
        request.predicate = predicate
        let ctx = context ?? persistentContainer.viewContext
        do {
            return try ctx.fetch(request).count > 0
        } catch {
            debugPrint("failed to check planet exists: \(error)")
        }
        return false
    }

    @MainActor func removeArticle(_ article: PlanetArticle) {
        article.softDeleted = Date()
        PlanetStore.shared.currentArticle = nil
        Task {
            await PlanetManager.shared.destroyArticleDirectory(planetUUID: article.planetID!, articleUUID: article.id!)
        }
    }

    func cleanupDatabase() {
        let context = persistentContainer.viewContext

        let planetRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Planet")
        planetRequest.predicate = NSPredicate(format: "softDeleted != nil")
        let planetDeleteRequest = NSBatchDeleteRequest(fetchRequest: planetRequest)

        let articleRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "PlanetArticle")
        articleRequest.predicate = NSPredicate(format: "softDeleted != nil")
        let articleDeleteRequest = NSBatchDeleteRequest(fetchRequest: articleRequest)

        do {
            try context.execute(planetDeleteRequest)
            try context.execute(articleDeleteRequest)
            debugPrint("successfully cleaned up database")
        } catch {
            debugPrint("failed to clean up database: \(error)")
        }
    }

    func resetDatabase() {
        let context = persistentContainer.viewContext
        let removePlanetRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Planet")
        let removePlanetArticleRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "PlanetArticle")
        do {
            let planets = try context.fetch(removePlanetRequest)
            let _ = planets.map { p in
                context.delete(p as! NSManagedObject)
            }
            let articles = try context.fetch(removePlanetArticleRequest)
            let _ = articles.map { a in
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
        request.predicate = NSPredicate(format: "id == %@ && softDeleted != nil", id as CVarArg)
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
