import SwiftUI
import Foundation
import CoreData
import FeedKit
import ENSKit
import SwiftSoup


enum PublicGateway: String {
    case cloudflare = "www.cloudflare-ipfs.com"
    case ipfs = "ipfs.io"
    case dweb = "dweb.link"
}

class PlanetDataController: NSObject {
    static let shared = PlanetDataController()

    // let enskit = ENSKit(jsonrpcClient: InfuraEthereumAPI(url: URL(string: "https://mainnet.infura.io/v3/<projectid>")!))
    let enskit = ENSKit(ipfsClient: GoIPFSGateway())

    var persistentContainer: NSPersistentContainer

    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }

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
        if context == nil || context == persistentContainer.viewContext {
            Task { @MainActor in
                let ctx = persistentContainer.viewContext
                guard ctx.hasChanges else { return }
                do {
                    try ctx.save()
                } catch {
                    debugPrint("Failed to save main context: \(error)")
                }
            }
        } else {
            guard context!.hasChanges else { return }
            do {
                try context!.save()
            } catch {
                debugPrint("Failed to save given context: \(error)")
            }
        }
    }

    // create a following planet
    func createPlanet(
            withID id: UUID,
            name: String,
            about: String,
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
        planet.ipns = ipns
        save(context: ctx)

        try? FileManager.default.createDirectory(at: planet.baseURL, withIntermediateDirectories: true)
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
        save(context: ctx)

        try? FileManager.default.createDirectory(at: planet.baseURL, withIntermediateDirectories: true)
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
        save(context: ctx)

        try? FileManager.default.createDirectory(at: planet.baseURL, withIntermediateDirectories: true)
        return planet
    }

    // MARK: - Update Planet -

    // type 0
    func updateNativePlanet(planet: Planet) async throws {
        // check if IPNS has latest CID changes
        debugPrint("checking update for \(planet)")
        let latestCID = try await IPFSDaemon.shared.resolveIPNS(ipns: planet.ipns!)
        if latestCID == planet.latestCID {
            // no update
            debugPrint("planet \(planet) has no update")
            return
        }
        Task {
            try await IPFSDaemon.shared.pin(ipns: planet.ipns!)
        }
        planet.latestCID = latestCID
        debugPrint("planet \(planet) CID changed to \(latestCID)")

        let feedURL = URL(string: "\(await IPFSDaemon.shared.gateway)\(latestCID)/planet.json")!
        let metadataRequest = URLRequest(
            url: feedURL,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 15
        )
        let (feedData, _) = try await URLSession.shared.data(for: metadataRequest)
        let feed = try JSONDecoder().decode(PlanetFeed.self, from: feedData)

        debugPrint("updating planet \(planet) with new feed")
        planet.name = feed.name
        planet.about = feed.about

        // update planet articles
        var createArticleCount = 0
        var updateArticleCount = 0
        for article in feed.articles {
            guard let articleLink = article.link else { continue }
            if let existing = getArticle(link: articleLink, planetID: planet.id!) {
                if existing.title != article.title {
                    existing.title = article.title
                    existing.link = articleLink
                    updateArticleCount += 1
                }
            } else {
                let _ = createArticle(article, planetID: planet.id!)
                createArticleCount += 1
            }
        }
        debugPrint("updated \(updateArticleCount) articles, created \(createArticleCount) articles")

        // update planet avatar
        let avatarURL = URL(string: "\(await IPFSDaemon.shared.gateway)\(latestCID)/avatar.png")!
        let avatarRequest = URLRequest(url: avatarURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        let (avatarData, _) = try await URLSession.shared.data(for: avatarRequest)
        if let image = NSImage(data: avatarData) {
            planet.updateAvatar(image: image)
        }
    }

    func updateENSPlanet(planet: Planet) async throws {
        let ens = planet.ens!
        let result: URL?
        do {
            result = try await enskit.resolve(name: ens)
        } catch {
            throw PlanetError.EthereumError
        }
        debugPrint("ENSKit.resolve(\(ens)) => \(String(describing: result))")
        guard let contenthash = result else {
            throw PlanetError.InvalidPlanetURLError
        }
        var latestCID: String? = nil
        if contenthash.scheme?.lowercased() == "ipns" {
            let s = contenthash.absoluteString
            let ipns = String(s.suffix(from: s.index(s.startIndex, offsetBy: 7)))
            latestCID = try await IPFSDaemon.shared.resolveIPNS(ipns: ipns)
        } else if contenthash.scheme?.lowercased() == "ipfs" {
            let s = contenthash.absoluteString
            latestCID = "/ipfs/" + String(s.suffix(from: s.index(s.startIndex, offsetBy: 7)))
        }

        guard let cid = latestCID else {
            // unsupported contenthash multicodec
            throw PlanetError.InvalidPlanetURLError
        }
        if cid == planet.latestCID {
            // no update
            debugPrint("planet \(planet) has no update")
            return
        }

        Task {
            try await IPFSDaemon.shared.pin(cid: cid)
        }

        // detect if a native planet is behind ENS
        debugPrint("checking existing planet feed in planet \(planet)")
        var planetFeed: PlanetFeed? = nil
        let planetFeedURL = URL(string: "\(await IPFSDaemon.shared.gateway)\(cid)/planet.json")!
        do {
            let (planetFeedData, planetFeedResponse) = try await URLSession.shared.data(from: planetFeedURL)
            if let httpResponse = planetFeedResponse as? HTTPURLResponse,
               httpResponse.ok {
                planetFeed = try JSONDecoder().decode(PlanetFeed.self, from: planetFeedData)
            }
        } catch {
            // ignore
        }
        if let feed = planetFeed {
            debugPrint("updating planet \(planet) with new feed")
            planet.name = feed.name
            planet.about = feed.about

            // update planet articles
            var createArticleCount = 0
            var updateArticleCount = 0
            for article in feed.articles {
                guard let articleLink = article.link else { continue }
                if let existing = getArticle(link: articleLink, planetID: planet.id!) {
                    if existing.title != article.title {
                        existing.title = article.title
                        existing.link = articleLink
                        updateArticleCount += 1
                    }
                } else {
                    let _ = createArticle(article, planetID: planet.id!)
                    createArticleCount += 1
                }
            }
            debugPrint("updated \(updateArticleCount) articles, created \(createArticleCount) articles")

            // update planet avatar
            let avatarURL = URL(string: "\(await IPFSDaemon.shared.gateway)\(cid)/avatar.png")!
            let avatarRequest = URLRequest(
                url: avatarURL,
                cachePolicy: .reloadIgnoringLocalCacheData,
                timeoutInterval: 15
            )
            let (avatarData, _) = try await URLSession.shared.data(for: avatarRequest)
            if let image = NSImage(data: avatarData) {
                planet.updateAvatar(image: image)
            }
        } else {
            debugPrint("planet feed not available in planet \(planet), looking for RSS/JSON feed")
            let url = URL(string: "\(await IPFSDaemon.shared.gateway)\(cid)")!
            try await parsePlanetFeed(planet: planet, url: url)

            let avatarResult = try await enskit.avatar(name: ens)
            debugPrint("ENSKit.avatar(\(ens)) => \(String(describing: avatarResult))")
            if let avatarData = avatarResult,
               let image = NSImage(data: avatarData) {
                planet.updateAvatar(image: image)
            }
        }

        planet.latestCID = cid
    }

    func updateDNSPlanet(planet: Planet) async throws {
        if let feedAddress = planet.feedAddress {
            let url = URL(string: feedAddress)!
            try await parsePlanetFeed(planet: planet, url: url)
        } else {
            throw PlanetError.InternalError
        }
    }

    func parsePlanetFeed(planet: Planet, url: URL) async throws {
        let feedData: Data

        guard let (data, response) = try? await URLSession.shared.data(from: url) else {
            throw PlanetError.NetworkError
        }
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.ok,
              let mime = httpResponse.mimeType?.lowercased()
        else {
            throw PlanetError.PlanetFeedError
        }
        if mime.contains("application/xml")
               || mime.contains("application/atom+xml")
               || mime.contains("application/rss+xml")
               || mime.contains("application/json")
               || mime.contains("application/feed+json") {
            feedData = data
        } else
        if mime.contains("text/html") {
            // parse HTML and find <link rel="alternate">
            guard let homepageHTML = String(data: data, encoding: .utf8),
                  let soup = try? SwiftSoup.parse(homepageHTML),
                  let feedElem = try soup.select("link[rel='alternate']").first(),
                  let feedElemHref = try? feedElem.attr("href"),
                  let feedURL = URL.relativeURL(string: feedElemHref, base: url)
            else {
                // no <link rel="alternate"> in HTML
                throw PlanetError.PlanetFeedError
            }
            // fetch feed
            guard let (data, response) = try? await URLSession.shared.data(from: feedURL) else {
                throw PlanetError.NetworkError
            }
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.ok
            else {
                throw PlanetError.PlanetFeedError
            }
            feedData = data
        } else {
            throw PlanetError.PlanetFeedError
        }

        let parser = FeedParser(data: feedData)
        switch parser.parse() {
        case .success(let feed):
            let articles: [PlanetFeedArticle]
            switch feed {
            case let .atom(feed):       // Atom Syndication Format Feed
                if let name = feed.title {
                    planet.name = name
                }
                if let about = feed.subtitle?.value {
                    planet.about = about
                }
                articles = feed.entries?.compactMap { entry in
                    guard let link = entry.links?[0].attributes?.href,
                        let title = entry.title
                    else {
                        return nil
                    }
                    let content = entry.content?.attributes?.src ?? ""
                    let published = entry.published ?? Date()
                    return PlanetFeedArticle(
                        id: UUID(),
                        created: published,
                        title: title,
                        content: content,
                        link: link
                    )
                } ?? []
                debugPrint("parsed atom feed: \(articles.count) articles")
            case let .rss(feed):        // Really Simple Syndication Feed
                if let name = feed.title {
                    planet.name = name
                }
                if let about = feed.description {
                    planet.about = about
                }
                articles = feed.items?.compactMap { item in
                    guard let link = item.link,
                          let linkURL = URL(string: link),
                          let title = item.title
                    else {
                        return nil
                    }
                    let description = item.description ?? ""
                    let published = item.pubDate ?? Date()
                    return PlanetFeedArticle(
                        id: UUID(),
                        created: published,
                        title: title,
                        content: description,
                        link: link
                    )
                } ?? []
                debugPrint("parsed RSS feed: \(articles.count) articles")
            case let .json(feed):       // JSON Feed
                if let name = feed.title {
                    planet.name = name
                }
                if let about = feed.description {
                    planet.about = about
                }
                // Fetch feed avatar if any
                if let imageURL = feed.icon,
                   let url = URL(string: imageURL),
                   let data = try? Data(contentsOf: url),
                   let image = NSImage(data: data) {
                    planet.updateAvatar(image: image)
                }

                articles = feed.items?.compactMap { item in
                    guard let url = item.url,
                          let title = item.title
                    else {
                        return nil
                    }
                    let html = item.contentHtml ?? ""
                    let published = item.datePublished ?? Date()
                    return PlanetFeedArticle(
                        id: UUID(),
                        created: published,
                        title: title,
                        content: html,
                        link: url
                    )
                } ?? []
                debugPrint("parsed JSON feed: \(articles.count) articles")
            }
            PlanetDataController.shared.batchCreateFeedArticles(articles: articles, planetID: planet.id!)
        case .failure(_):
            throw PlanetError.PlanetFeedError
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
        save(context: ctx)
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
            save(context: ctx)
        }
    }

    func batchCreateFeedArticles(articles: [PlanetFeedArticle], planetID: UUID) {
        Task { @MainActor in
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
                    save(context: ctx)
                }
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

    func getArticlePublicLink(article: PlanetArticle, gateway: PublicGateway = .dweb) -> String {
        guard let planet = getPlanet(id: article.planetID!) else { return "" }
        switch (planet.type) {
        case .planet:
            return "https://\(gateway.rawValue)/ipns/\(planet.ipns!)\(article.link!)"
        case .ens:
            return "https://\(gateway.rawValue)/ipns/\(planet.ens!)\(article.link!)"
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
            if PlanetStore.shared.currentPlanet == planet {
                PlanetStore.shared.currentPlanet = nil
                PlanetStore.shared.currentArticle = nil
            }
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
