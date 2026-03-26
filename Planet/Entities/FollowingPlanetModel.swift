import ENSDataKit
import Foundation
import SwiftSoup
import SwiftUI
import UserNotifications
import os

enum PlanetType: Int, Codable {
    case planet = 0
    case ens = 1
    case dnslink = 2
    case dns = 3
    case dotbit = 4
}

class FollowingPlanetModel: Equatable, Hashable, Identifiable, ObservableObject, Codable {
    static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: "FollowingPlanet"
    )

    let id: UUID
    @Published var name: String
    @Published var about: String
    let created: Date
    let planetType: PlanetType
    let link: String
    @Published var cid: String?
    @Published var updated: Date
    @Published var lastRetrieved: Date

    @Published var archived: Bool? = false
    @Published var archivedAt: Date?

    @Published var walletAddress: String?
    @Published var walletAddressResolvedAt: Date?

    @Published var isUpdating = false

    // populated when initializing
    @Published var articles: [FollowingArticleModel]! = nil {
        didSet {
            rebuildUnreadMetadata()
        }
    }
    @Published private(set) var unreadCount: Int = 0
    @Published private(set) var unreadArticles: [FollowingArticleModel] = []
    @Published var avatar: NSImage? = nil

    // juicebox
    @Published var juiceboxEnabled: Bool? = false
    @Published var juiceboxProjectID: Int?
    @Published var juiceboxProjectIDGoerli: Int?

    // social usernames
    @Published var twitterUsername: String?
    @Published var githubUsername: String?
    @Published var telegramUsername: String?
    @Published var mastodonUsername: String?

    static func followingPlanetsPath() -> URL {
        let url = URLUtils.repoPath().appendingPathComponent("Following", isDirectory: true)
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    var basePath: URL {
        return Self.followingPlanetsPath().appendingPathComponent(
            self.id.uuidString,
            isDirectory: true
        )
    }
    var infoPath: URL {
        return Self.followingPlanetsPath().appendingPathComponent(
            self.id.uuidString,
            isDirectory: true
        ).appendingPathComponent("planet.json", isDirectory: false)
    }
    var articlesPath: URL {
        return Self.followingPlanetsPath().appendingPathComponent(
            self.id.uuidString,
            isDirectory: true
        ).appendingPathComponent("Articles", isDirectory: true)
    }
    var avatarPath: URL {
        return Self.followingPlanetsPath().appendingPathComponent(
            self.id.uuidString,
            isDirectory: true
        ).appendingPathComponent("avatar.png", isDirectory: false)
    }

    var nameInitials: String {
        let initials = name.components(separatedBy: .whitespaces).map { $0.prefix(1).capitalized }
            .joined()
        return String(initials.prefix(2))
    }
    var webviewURL: URL? {
        if let cid = cid {
            return URL(string: "\(IPFSState.shared.getGateway())/ipfs/\(cid)/")
        }
        return URL(string: link)
    }
    /// URL that can be viewed or shared in a regular browser.
    var browserURL: URL? {
        if planetType == .ens {
            switch IPFSGateway.selectedGateway() {
            case .limo:
                return URL(string: "https://\(link).limo")
            case .sucks:
                return URL(string: "https://\(link).sucks")
            case .croptop:
                let name = link.replacingOccurrences(of: ".eth", with: "")
                return URL(string: "https://\(name).crop.top")
            case .dweblink:
                return URL(string: "https://dweb.link/ipns/\(link)")
            }
        }
        // IPNS
        if link.hasPrefix("k51qaz") {
            switch IPFSGateway.selectedGateway() {
            case .limo:
                return URL(string: "https://\(link).eth.sucks/")
            case .sucks:
                return URL(string: "https://\(link).eth.sucks/")
            case .croptop:
                return URL(string: "https://\(link).crop.top/")
            case .dweblink:
                return URL(string: "https://dweb.link/ipns/\(link)")
            }
        }
        if let cid = cid {
            debugPrint("Following Planet CID: \(cid)")
            // CIDv0
            if cid.hasPrefix("Qm") {
                return URL(string: "https://dweb.link/ipfs/\(cid)/")
            }
            // CIDv1
            if cid.hasPrefix("bafy") {
                switch IPFSGateway.selectedGateway() {
                case .limo:
                    return URL(string: "https://\(cid).eth.sucks/")
                case .sucks:
                    return URL(string: "https://\(cid).eth.sucks/")
                case .croptop:
                    return URL(string: "https://\(cid).crop.top/")
                case .dweblink:
                    return URL(string: "https://dweb.link/ipfs/\(cid)/")
                }
            }
        }
        return URL(string: link)
    }
    var shareLink: URL {
        if link.starts(with: "https://") {
            return URL(string: link)!
        }
        return URL(string: "planet://\(link)")!
    }

    private func rebuildUnreadMetadata() {
        let unread = articles?.filter { $0.read == nil } ?? []
        unreadArticles = unread
        unreadCount = unread.count
    }

    func updateUnreadMetadata(for article: FollowingArticleModel, previousRead: Date?, currentRead: Date?) {
        let wasUnread = previousRead == nil
        let isUnread = currentRead == nil
        guard wasUnread != isUnread else {
            return
        }

        if isUnread {
            guard !unreadArticles.contains(where: { $0.id == article.id }) else {
                return
            }
            let insertionIndex = unreadArticles.firstIndex(where: { $0.created < article.created })
                ?? unreadArticles.endIndex
            unreadArticles.insert(article, at: insertionIndex)
        } else {
            unreadArticles.removeAll { $0.id == article.id }
        }
        unreadCount = unreadArticles.count
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: FollowingPlanetModel, rhs: FollowingPlanetModel) -> Bool {
        lhs.id == rhs.id
    }

    enum CodingKeys: String, CodingKey {
        case id, planetType, name, about, link,
            cid, created, updated, lastRetrieved,
            archived, archivedAt,
            walletAddress, walletAddressResolvedAt,
            twitterUsername,
            githubUsername,
            telegramUsername,
            mastodonUsername,
            juiceboxEnabled, juiceboxProjectID, juiceboxProjectIDGoerli
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        planetType = try container.decode(PlanetType.self, forKey: .planetType)
        name = try container.decode(String.self, forKey: .name)
        about = try container.decode(String.self, forKey: .about)
        link = try container.decode(String.self, forKey: .link)
        cid = try container.decodeIfPresent(String.self, forKey: .cid)
        created = try container.decode(Date.self, forKey: .created)
        updated = try container.decode(Date.self, forKey: .updated)
        lastRetrieved = try container.decode(Date.self, forKey: .lastRetrieved)
        archived = try container.decodeIfPresent(Bool.self, forKey: .archived)
        archivedAt = try container.decodeIfPresent(Date.self, forKey: .archivedAt)
        walletAddress = try container.decodeIfPresent(String.self, forKey: .walletAddress)
        walletAddressResolvedAt = try container.decodeIfPresent(
            Date.self,
            forKey: .walletAddressResolvedAt
        )
        twitterUsername = try container.decodeIfPresent(String.self, forKey: .twitterUsername)
        githubUsername = try container.decodeIfPresent(String.self, forKey: .githubUsername)
        telegramUsername = try container.decodeIfPresent(String.self, forKey: .telegramUsername)
        mastodonUsername = try container.decodeIfPresent(String.self, forKey: .mastodonUsername)

        juiceboxEnabled = try container.decodeIfPresent(Bool.self, forKey: .juiceboxEnabled)
        juiceboxProjectID = try container.decodeIfPresent(Int.self, forKey: .juiceboxProjectID)
        juiceboxProjectIDGoerli = try container.decodeIfPresent(
            Int.self,
            forKey: .juiceboxProjectIDGoerli
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(planetType, forKey: .planetType)
        try container.encode(name, forKey: .name)
        try container.encode(about, forKey: .about)
        try container.encode(link, forKey: .link)
        try container.encodeIfPresent(cid, forKey: .cid)
        try container.encode(created, forKey: .created)
        try container.encode(updated, forKey: .updated)
        try container.encode(lastRetrieved, forKey: .lastRetrieved)
        try container.encodeIfPresent(archived, forKey: .archived)
        try container.encodeIfPresent(archivedAt, forKey: .archivedAt)
        try container.encodeIfPresent(walletAddress, forKey: .walletAddress)
        try container.encodeIfPresent(walletAddressResolvedAt, forKey: .walletAddressResolvedAt)
        try container.encodeIfPresent(twitterUsername, forKey: .twitterUsername)
        try container.encodeIfPresent(githubUsername, forKey: .githubUsername)
        try container.encodeIfPresent(telegramUsername, forKey: .telegramUsername)
        try container.encodeIfPresent(mastodonUsername, forKey: .mastodonUsername)
        try container.encodeIfPresent(juiceboxEnabled, forKey: .juiceboxEnabled)
        try container.encodeIfPresent(juiceboxProjectID, forKey: .juiceboxProjectID)
        try container.encodeIfPresent(juiceboxProjectIDGoerli, forKey: .juiceboxProjectIDGoerli)
    }

    init(
        id: UUID,
        planetType: PlanetType,
        name: String,
        about: String,
        link: String,
        cid: String?,
        twitterUsername: String? = nil,
        githubUsername: String? = nil,
        telegramUsername: String? = nil,
        mastodonUsername: String? = nil,
        juiceboxEnabled: Bool? = false,
        juiceboxProjectID: Int? = nil,
        juiceboxProjectIDGoerli: Int? = nil,
        created: Date,
        updated: Date,
        lastRetrieved: Date
    ) {
        self.id = id
        self.name = name
        self.about = about
        self.created = created
        self.planetType = planetType
        self.link = link
        self.cid = cid
        self.twitterUsername = twitterUsername
        self.githubUsername = githubUsername
        self.telegramUsername = telegramUsername
        self.mastodonUsername = mastodonUsername
        self.juiceboxEnabled = juiceboxEnabled
        self.juiceboxProjectID = juiceboxProjectID
        self.juiceboxProjectIDGoerli = juiceboxProjectIDGoerli
        self.updated = updated
        self.lastRetrieved = lastRetrieved
    }

    static func load(from directoryPath: URL) throws -> FollowingPlanetModel {
        guard let planetID = UUID(uuidString: directoryPath.lastPathComponent) else {
            // directory name is not a UUID
            Self.logger.warning("Unknown directory name \(directoryPath.lastPathComponent)")
            throw PlanetError.PersistenceError
        }
        let planetPath = directoryPath.appendingPathComponent("planet.json", isDirectory: false)
        let planetData = try Data(contentsOf: planetPath)
        let planet = try JSONDecoder.shared.decode(FollowingPlanetModel.self, from: planetData)
        guard planet.id == planetID else {
            // directory UUID does not match planet json UUID
            Self.logger.warning(
                "Mismatched directory name \(directoryPath.lastPathComponent) with planet info \(planet.id)"
            )
            throw PlanetError.PersistenceError
        }
        let articleDirectory = directoryPath.appendingPathComponent("Articles", isDirectory: true)
        let articleFiles = try FileManager.default.contentsOfDirectory(
            at: articleDirectory,
            includingPropertiesForKeys: nil
        )
        planet.articles = articleFiles.compactMap {
            try? FollowingArticleModel.load(from: $0, planet: planet)
        }
        planet.articles.sort { $0.created > $1.created }
        if let data = try? Data(contentsOf: planet.avatarPath),
            let image = NSImage(data: data) {
            planet.avatar = image
        }
        else {
            planet.avatar = nil
        }

        if planet.articles.count > 0 {
            var links: [String] = []
            var consolidatedArticles: [FollowingArticleModel] = []

            for article in planet.articles {
                if article.link.startsWithInternalGateway() {
                    article.link = String(article.link.dropFirst(22))
                    try article.save()
                }
                if article.link.hasPrefix("/ipfs/Qm"), article.link.count > (6 + 46) {
                    article.link = String(article.link.dropFirst(6 + 46))
                    try article.save()
                }
                if !links.contains(article.link) {
                    links.append(article.link)
                    consolidatedArticles.append(article)
                }
                else {
                    article.delete()
                }
            }
            if consolidatedArticles.count != planet.articles.count {
                planet.articles = consolidatedArticles
            }
        }
        return planet
    }

    static func follow(link raw: String) async throws -> FollowingPlanetModel {
        var link = raw.trim()
        if link.starts(with: "planet://") {
            link = String(link.dropFirst("planet://".count))
        }
        if let existing = await PlanetStore.shared.followingPlanets.first(where: { $0.link == link }
        ) {
            await MainActor.run {
                PlanetStore.shared.selectedView = .followingPlanet(existing)
                PlanetStore.shared.selectedArticle = existing.articles.first
                let sidebarID = "sidebar-following-\(existing.id.uuidString)"
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .scrollToSidebarItem, object: sidebarID)
                    NotificationCenter.default.post(name: .scrollToTopArticleList, object: nil)
                }
            }
            throw PlanetError.PlanetExistsError
        }
        let planet: FollowingPlanetModel
        if link.hasSuffix(".eth") {
            planet = try await followENS(ens: link)
        }
        else if link.hasSuffix(".bit") {
            planet = try await followDotBit(dotbit: link)
        }
        else if link.lowercased().hasPrefix("http://") || link.lowercased().hasPrefix("https://") {
            planet = try await followHTTP(link: link)
        }
        else {
            planet = try await followIPNSorDNSLink(name: link)
        }
        Task.detached(priority: .background) {
            await planet.pin()
        }
        return planet
    }

    static func deduplicate(_ articles: [PublicArticleModel]) -> [PublicArticleModel] {
        var result: [PublicArticleModel] = []
        var links: [String] = []
        for article in articles {
            if !links.contains(article.link) {
                result.append(article)
                links.append(article.link)
            }
        }
        return result
    }

    private struct FeedContent {
        let name: String
        let about: String
        let articles: [PublicArticleModel]
        let avatarData: Data?
    }

    private static func prepareStorage(for planet: FollowingPlanetModel) throws {
        try FileManager.default.createDirectory(
            at: planet.basePath,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: planet.articlesPath,
            withIntermediateDirectories: true
        )
    }

    private static func savePlanet(_ planet: FollowingPlanetModel) throws {
        try planet.save()
        try planet.articles.forEach { try $0.save() }
    }

    private static func setArticles(
        _ publicArticles: [PublicArticleModel],
        on planet: FollowingPlanetModel
    ) {
        let items = deduplicate(publicArticles)
        planet.articles = items.map {
            FollowingArticleModel.from(publicArticle: $0, planet: planet)
        }
        planet.articles.sort { $0.created > $1.created }
    }

    private static func fetchData(from url: URL) async -> Data? {
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.ok
        else {
            return nil
        }
        return data
    }

    private static func fetchData(from urlString: String?) async -> Data? {
        guard let urlString,
              let url = URL(string: urlString)
        else {
            return nil
        }
        return await fetchData(from: url)
    }

    private static func imageIsValid(_ data: Data) -> Bool {
        NSImage(data: data) != nil
    }

    private static func imageIsSquare(_ data: Data) -> Bool {
        guard let image = NSImage(data: data) else {
            return false
        }
        return image.size.width == image.size.height
    }

    private static func avatarHTMLSource(
        from discovery: FeedDiscoveryResult
    ) async throws -> (document: Document, url: URL)? {
        if let htmlDocument = discovery.htmlDocument,
           let htmlURL = discovery.htmlURL
        {
            return (htmlDocument, htmlURL)
        }

        guard let feedData = discovery.feedData,
              let feedURL = discovery.feedURL
        else {
            return nil
        }

        var avatarPageURL: URL? = nil
        if let feedLink = FeedUtils.findLinkFromFeed(feedData: feedData) {
            avatarPageURL = URL(string: feedLink, relativeTo: feedURL)?.absoluteURL
        }
        if avatarPageURL == nil {
            let candidateURL = feedURL.deletingLastPathComponent()
            if candidateURL != feedURL {
                avatarPageURL = candidateURL
            }
        }
        if avatarPageURL == nil,
           let scheme = feedURL.scheme,
           let host = feedURL.host
        {
            avatarPageURL = URL(string: "\(scheme)://\(host)")
        }
        guard let avatarPageURL else {
            return nil
        }
        guard let document = try await FeedUtils.getHTMLDocument(url: avatarPageURL) else {
            return nil
        }
        return (document, avatarPageURL)
    }

    private static func resolveHTMLAvatarData(
        from discovery: FeedDiscoveryResult
    ) async throws -> Data? {
        guard let source = try await avatarHTMLSource(from: discovery) else {
            return nil
        }

        let ogImageData = try await FeedUtils.findAvatarFromHTMLOGImage(
            htmlDocument: source.document,
            htmlURL: source.url
        )
        if let ogImageData,
           imageIsValid(ogImageData),
           imageIsSquare(ogImageData)
        {
            return ogImageData
        }

        let iconData = try await FeedUtils.findAvatarFromHTMLIcons(
            htmlDocument: source.document,
            htmlURL: source.url
        )
        if let iconData, imageIsValid(iconData) {
            return iconData
        }

        if let ogImageData, imageIsValid(ogImageData) {
            return ogImageData
        }

        return nil
    }

    private static func resolveFeedAvatarData(
        preferredAvatarData: Data? = nil,
        feedAvatar: Data?,
        discovery: FeedDiscoveryResult
    ) async throws -> Data? {
        if let preferredAvatarData,
           imageIsValid(preferredAvatarData)
        {
            return preferredAvatarData
        }

        if let feedAvatar,
           imageIsValid(feedAvatar),
           imageIsSquare(feedAvatar)
        {
            return feedAvatar
        }

        if let htmlAvatarData = try await resolveHTMLAvatarData(from: discovery) {
            return htmlAvatarData
        }

        if let feedAvatar, imageIsValid(feedAvatar) {
            return feedAvatar
        }

        return nil
    }

    @MainActor
    private static func applyAvatarData(_ data: Data?, to planet: FollowingPlanetModel) {
        guard let data,
              let image = NSImage(data: data),
              let _ = try? data.write(to: planet.avatarPath)
        else {
            return
        }
        planet.avatar = image
    }

    private static func feedContent(
        from discovery: FeedDiscoveryResult,
        fallbackName: String,
        fallbackAbout: String = "",
        fallbackArticleLink: String = "/",
        preferredAvatarData: Data? = nil,
        allowHomepageFallback: Bool
    ) async throws -> FeedContent {
        if let feedData = discovery.feedData,
           let feedURL = discovery.feedURL
        {
            let feed = try await FeedUtils.parseFeed(data: feedData, url: feedURL)
            let avatarData = try await resolveFeedAvatarData(
                preferredAvatarData: preferredAvatarData,
                feedAvatar: feed.avatar,
                discovery: discovery
            )
            return FeedContent(
                name: feed.name ?? fallbackName,
                about: feed.about ?? fallbackAbout,
                articles: feed.articles ?? [],
                avatarData: avatarData
            )
        }

        if allowHomepageFallback,
           let htmlDocument = discovery.htmlDocument
        {
            let now = Date()
            let homepage = PublicArticleModel(
                id: UUID(),
                link: fallbackArticleLink,
                title: (try? htmlDocument.title()) ?? "Homepage",
                content: "",
                contentRendered: nil,
                created: now,
                hasVideo: false,
                videoFilename: nil,
                hasAudio: false,
                audioFilename: nil,
                audioDuration: nil,
                audioByteLength: nil,
                attachments: nil,
                heroImage: nil,
                heroImageWidth: nil,
                heroImageHeight: nil,
                heroImageURL: nil,
                heroImageFilename: nil
            )
            let avatarData: Data?
            if let preferredAvatarData {
                avatarData = preferredAvatarData
            }
            else {
                avatarData = try await resolveHTMLAvatarData(from: discovery)
            }
            return FeedContent(
                name: fallbackName,
                about: fallbackAbout,
                articles: [homepage],
                avatarData: avatarData
            )
        }

        throw PlanetError.InvalidPlanetURLError
    }

    private static func createFeedPlanet(
        planetType: PlanetType,
        link: String,
        cid: String?,
        fallbackName: String,
        fallbackAbout: String = "",
        discovery: FeedDiscoveryResult,
        preferredAvatarData: Data? = nil,
        walletAddress: String? = nil,
        allowHomepageFallback: Bool
    ) async throws -> FollowingPlanetModel {
        let content = try await feedContent(
            from: discovery,
            fallbackName: fallbackName,
            fallbackAbout: fallbackAbout,
            preferredAvatarData: preferredAvatarData,
            allowHomepageFallback: allowHomepageFallback
        )
        let now = Date()
        let planet = FollowingPlanetModel(
            id: UUID(),
            planetType: planetType,
            name: content.name,
            about: content.about,
            link: link,
            cid: cid,
            created: now,
            updated: now,
            lastRetrieved: now
        )
        if let walletAddress {
            planet.walletAddress = walletAddress
            planet.walletAddressResolvedAt = Date()
        }
        setArticles(content.articles, on: planet)
        try prepareStorage(for: planet)
        await applyAvatarData(content.avatarData, to: planet)
        try savePlanet(planet)
        return planet
    }

    private func updateFromFeedDiscovery(
        _ discovery: FeedDiscoveryResult,
        fallbackName: String,
        error: PlanetError,
        newCID: String? = nil,
        preferredAvatarData: Data? = nil
    ) async throws {
        guard let feedData = discovery.feedData,
              let feedURL = discovery.feedURL
        else {
            throw error
        }

        let feed = try await FeedUtils.parseFeed(data: feedData, url: feedURL)
        let avatarData = try await Self.resolveFeedAvatarData(
            preferredAvatarData: preferredAvatarData,
            feedAvatar: feed.avatar,
            discovery: discovery
        )
        let now = Date()

        await MainActor.run {
            if let newCID {
                cid = newCID
            }
            name = feed.name ?? fallbackName
            about = feed.about ?? ""
            updated = now
            lastRetrieved = now
        }

        if let publicArticles = feed.articles {
            try await updateArticles(publicArticles: Self.deduplicate(publicArticles))
        }

        await Self.applyAvatarData(avatarData, to: self)

        await MainActor.run {
            try? save()
        }
    }

    static func getPublicPlanet(from cid: String) async throws -> PublicPlanetModel? {
        guard let planetURL = URL(string: "\(IPFSState.shared.getGateway())/ipfs/\(cid)/planet.json")
        else {
            debugPrint("Get Public Planet from CID: Invalid URL")
            return nil
        }
        guard let (planetData, planetResponse) = try? await URLSession.shared.data(from: planetURL)
        else {
            debugPrint("Get Public Planet from CID: Invalid URLResponse")
            return nil
        }
        guard let httpResponse = planetResponse as? HTTPURLResponse else {
            debugPrint("Get Public Planet from CID: Invalid HTTPResponse")
            return nil
        }
        if httpResponse.statusCode != 200 {
            debugPrint(
                "Get Public Planet from CID: Invalid HTTPResponse Code \(httpResponse.statusCode)"
            )
            return nil
        }
        do {
            let publicPlanet = try JSONDecoder.shared.decode(
                PublicPlanetModel.self,
                from: planetData
            )
            return publicPlanet
        }
        catch {
            debugPrint("Get Public Planet from CID: Error: \(error)")
            if let planetString = String(data: planetData, encoding: .utf8) {
                debugPrint("Get Public Planet from CID: Invalid Planet JSON String: \(planetString)")
            } else {
                debugPrint("Get Public Planet from CID: Invalid Planet JSON")
            }
            return nil
        }
    }

    static func followFeaturedSources() async throws {
        debugPrint("About to follow featured planets")
        let ensDomains = ["planetable.eth", "docs.planetable.eth", "vitalik.eth"]
        let lines = ensDomains.joined(separator: "\n")
        Task { @MainActor in
            let alert = NSAlert()
            alert.messageText = "Follow Featured Planets"
            alert.informativeText = "You will start following: \n\n" + lines
            let _ = alert.runModal()
        }
        for domain in ensDomains {
            let isFollowed = await PlanetStore.shared.followingPlanets.contains {
                $0.link == domain
            }
            if !isFollowed {
                do {
                    let planet = try await FollowingPlanetModel.follow(link: domain)
                    Task { @MainActor in
                        PlanetStore.shared.followingPlanets.insert(planet, at: 0)
                        await PlanetStore.shared.saveFollowingPlanetsOrder()
                    }
                    debugPrint("FollowFeatured: Followed \(domain)")
                }
                catch {
                    debugPrint("FollowFeatured: Failed to follow \(domain): \(error)")
                }
            } else {
                debugPrint("FollowFeatured: Already following \(domain)")
            }
        }
    }

    static func followENS(ens: String) async throws -> FollowingPlanetModel {
        let ensdata = ENSDataClient()
        let data: ENSData
        do {
            data = try await ensdata.resolve(ens)
            print("FollowENS ENSDataClient: Resolved \(ens) with ENSDataClient: \(String(describing: data))")
        } catch {
            debugPrint("FollowENS ENSDataClient: Failed to resolve \(ens): \(error)")
            // ignore error
            throw PlanetError.EthereumError
        }

        guard let contentHash = data.contentHash else {
            debugPrint("FollowENS ENSDataClient: No content hash set for \(ens)")
            throw PlanetError.ENSNoContentHashError
        }

        guard let contentHashURL = URL(string: {
            if contentHash.hasPrefix("k51") {
                return "ipns://\(contentHash)"
            } else if contentHash.hasPrefix("Qm") {
                return "ipfs://\(contentHash)"
            } else if contentHash.hasPrefix("bafy") {
                return "ipfs://\(contentHash)"
            } else {
                return "ipfs://\(contentHash)"
            }
        }() ) else {
            debugPrint("FollowENS ENSDataClient: Invalid content hash URL for \(ens): \(contentHash)")
            throw PlanetError.ENSNoContentHashError
        }

        guard let cid = try await ENSUtils.getCID(from: contentHashURL)
        else {
            throw PlanetError.ENSNoContentHashError
        }
        Self.logger.info("FollowENS: \(ens) -> CID \(cid)")
        let gateway = IPFSState.shared.getGateway()
        let ensAvatarData = await fetchData(from: data.avatar)
        let walletAddress = data.address
        // update a native planet if a public planet is found
        if let publicPlanet = try await getPublicPlanet(from: cid) {
            Self.logger.info("FollowENS: \(ens): found native planet \(publicPlanet.name)")

            let planet = FollowingPlanetModel(
                id: UUID(),
                planetType: .ens,
                name: publicPlanet.name,
                about: publicPlanet.about,
                link: ens,
                cid: cid,
                twitterUsername: publicPlanet.twitterUsername,
                githubUsername: publicPlanet.githubUsername,
                telegramUsername: publicPlanet.telegramUsername,
                mastodonUsername: publicPlanet.mastodonUsername,
                juiceboxEnabled: publicPlanet.juiceboxEnabled,
                juiceboxProjectID: publicPlanet.juiceboxProjectID,
                juiceboxProjectIDGoerli: publicPlanet.juiceboxProjectIDGoerli,
                created: publicPlanet.created,
                updated: publicPlanet.updated,
                lastRetrieved: Date()
            )

            if let walletAddress {
                planet.walletAddress = walletAddress
                planet.walletAddressResolvedAt = Date()
            }
            setArticles(publicPlanet.articles, on: planet)
            try prepareStorage(for: planet)
            await applyAvatarData(ensAvatarData, to: planet)
            if planet.avatar == nil,
               let nativeAvatarURL = URL(string: "\(gateway)/ipfs/\(cid)/avatar.png")
            {
                await applyAvatarData(await fetchData(from: nativeAvatarURL), to: planet)
            }
            try savePlanet(planet)

            return planet
        }
        debugPrint("Follow \(ens): did not find native planet.json")
        guard let feedURL = URL(string: "\(gateway)/ipfs/\(cid)/") else {
            throw PlanetError.InvalidPlanetURLError
        }
        let discovery = try await FeedUtils.findFeed(url: feedURL)
        return try await createFeedPlanet(
            planetType: .ens,
            link: ens,
            cid: cid,
            fallbackName: ens,
            discovery: discovery,
            preferredAvatarData: ensAvatarData,
            walletAddress: walletAddress,
            allowHomepageFallback: true
        )
    }

    static func followDotBit(dotbit: String) async throws -> FollowingPlanetModel {
        let gateway = IPFSState.shared.getGateway()
        guard let dweb = await DotBitKit.shared.resolve(dotbit) else {
            throw PlanetError.DotBitNoDWebRecordError
        }
        let cid: String
        if dweb.type == .ipfs {
            cid = dweb.value
        }
        else {
            debugPrint("DotBit: resolving \(dweb)")
            guard let resolved = try? await IPFSDaemon.shared.resolveIPNSorDNSLink(name: dweb.value)
            else {
                throw PlanetError.DotBitIPNSResolveError
            }
            cid = resolved
        }
        Self.logger.info("Follow \(dotbit): CID \(cid)")
        // update a native planet if a public planet is found
        if let planetURL = URL(string: "\(gateway)/ipfs/\(cid)/planet.json"),
            let (planetData, planetResponse) = try? await URLSession.shared.data(from: planetURL),
            let httpResponse = planetResponse as? HTTPURLResponse,
            httpResponse.ok,
            let publicPlanet = try? JSONDecoder.shared.decode(
                PublicPlanetModel.self,
                from: planetData
            )
        {
            Self.logger.info("Follow \(dotbit): found native planet \(publicPlanet.name)")

            let planet = FollowingPlanetModel(
                id: UUID(),
                planetType: .dotbit,
                name: publicPlanet.name,
                about: publicPlanet.about,
                link: dotbit,
                cid: cid,
                created: publicPlanet.created,
                updated: publicPlanet.updated,
                lastRetrieved: Date()
            )

            setArticles(publicPlanet.articles, on: planet)
            try prepareStorage(for: planet)
            if let nativeAvatarURL = URL(string: "\(gateway)/ipfs/\(cid)/avatar.png") {
                await applyAvatarData(await fetchData(from: nativeAvatarURL), to: planet)
            }
            try savePlanet(planet)
            return planet
        }
        guard let feedURL = URL(string: "\(gateway)/ipfs/\(cid)/") else {
            throw PlanetError.InvalidPlanetURLError
        }
        let discovery = try await FeedUtils.findFeed(url: feedURL)
        return try await createFeedPlanet(
            planetType: .dotbit,
            link: dotbit,
            cid: cid,
            fallbackName: dotbit,
            discovery: discovery,
            allowHomepageFallback: true
        )
    }

    static func followHTTP(link: String) async throws -> FollowingPlanetModel {
        guard let feedURL = URL(string: link) else {
            throw PlanetError.InvalidPlanetURLError
        }
        let discovery = try await FeedUtils.findFeed(url: feedURL)
        guard discovery.feedData != nil else {
            throw PlanetError.InvalidPlanetURLError
        }
        return try await createFeedPlanet(
            planetType: .dns,
            link: link,
            cid: nil,
            fallbackName: link,
            discovery: discovery,
            allowHomepageFallback: false
        )
    }

    static func followIPNSorDNSLink(name: String) async throws -> FollowingPlanetModel {
        let planetType: PlanetType = ENSUtils.isIPNS(name) ? .planet : .dnslink
        let cid = try await IPFSDaemon.shared.resolveIPNSorDNSLink(name: name)
        let gateway = IPFSState.shared.getGateway()
        Self.logger.info("Follow \(name): CID \(cid)")
        if let planetURL = URL(string: "\(gateway)/ipfs/\(cid)/planet.json"),
            let (planetData, planetResponse) = try? await URLSession.shared.data(from: planetURL),
            let httpResponse = planetResponse as? HTTPURLResponse,
            httpResponse.ok
        {
            let publicPlanet = try JSONDecoder.shared.decode(
                PublicPlanetModel.self,
                from: planetData
            )
            let planet = FollowingPlanetModel(
                id: UUID(),
                planetType: planetType,
                name: publicPlanet.name,
                about: publicPlanet.about,
                link: name,
                cid: cid,
                juiceboxEnabled: publicPlanet.juiceboxEnabled,
                juiceboxProjectID: publicPlanet.juiceboxProjectID,
                juiceboxProjectIDGoerli: publicPlanet.juiceboxProjectIDGoerli,
                created: publicPlanet.created,
                updated: publicPlanet.updated,
                lastRetrieved: Date()
            )

            setArticles(publicPlanet.articles, on: planet)
            try prepareStorage(for: planet)
            if let nativeAvatarURL = URL(string: "\(gateway)/ipfs/\(cid)/avatar.png") {
                await applyAvatarData(await fetchData(from: nativeAvatarURL), to: planet)
            }
            try savePlanet(planet)
            return planet
        }
        guard let feedURL = URL(string: "\(gateway)/ipfs/\(cid)/") else {
            throw PlanetError.InvalidPlanetURLError
        }
        let discovery = try await FeedUtils.findFeed(url: feedURL)
        return try await createFeedPlanet(
            planetType: planetType,
            link: name,
            cid: cid,
            fallbackName: name,
            discovery: discovery,
            allowHomepageFallback: true
        )
    }

    func update() async throws {
        Self.logger.info("Updating planet \(self.name), link: \(self.link), id: \(self.id)")
        await MainActor.run {
            isUpdating = true
        }
        defer {
            Task { @MainActor in
                isUpdating = false
            }
        }
        let gateway = IPFSState.shared.getGateway()
        switch planetType {
        case .planet, .dnslink:
            let newCID = try await IPFSDaemon.shared.resolveIPNSorDNSLink(name: link)
            if cid == newCID {
                Self.logger.info("Planet \(self.name, privacy: .public) has no update")
                return
            }
            Task.detached(priority: .background) {
                try await IPFSDaemon.shared.pin(cid: newCID)
            }
            do {
                let planetURL = URL(
                    string: "\(gateway)/ipfs/\(newCID)/planet.json"
                )!
                let (planetData, planetResponse) = try await URLSession.shared.data(from: planetURL)
                if let httpResponse = planetResponse as? HTTPURLResponse,
                    httpResponse.ok
                {
                    let publicPlanet = try JSONDecoder.shared.decode(
                        PublicPlanetModel.self,
                        from: planetData
                    )
                    if publicPlanet.updated <= updated {
                        Self.logger.info("Planet \(self.name, privacy: .public) has no update")
                        return
                    }
                    await MainActor.run {
                        name = publicPlanet.name
                        about = publicPlanet.about
                        updated = publicPlanet.updated

                        twitterUsername = publicPlanet.twitterUsername
                        githubUsername = publicPlanet.githubUsername
                        telegramUsername = publicPlanet.telegramUsername
                        mastodonUsername = publicPlanet.mastodonUsername

                        juiceboxEnabled = publicPlanet.juiceboxEnabled
                        juiceboxProjectID = publicPlanet.juiceboxProjectID
                        juiceboxProjectIDGoerli = publicPlanet.juiceboxProjectIDGoerli
                    }

                    try await updateArticles(publicArticles: publicPlanet.articles, delete: true)

                    if let planetAvatarURL = URL(
                        string: "\(gateway)/ipfs/\(newCID)/avatar.png"
                    )
                    {
                        await Self.applyAvatarData(await Self.fetchData(from: planetAvatarURL), to: self)
                    }

                    await MainActor.run {
                        cid = newCID
                        lastRetrieved = Date()
                        try? save()
                    }

                    return
                }
            }
            catch {
                // ignore
            }
            // did not get published planet file, try to get feed
            guard let feedURL = URL(string: "\(gateway)/ipfs/\(newCID)/") else {
                throw PlanetError.InvalidPlanetURLError
            }
            let discovery = try await FeedUtils.findFeed(url: feedURL)
            try await updateFromFeedDiscovery(
                discovery,
                fallbackName: link,
                error: PlanetError.InvalidPlanetURLError,
                newCID: newCID
            )
            return
        case .ens:
            debugPrint("Updating planet (ENS type) \(name): link: \(link)")

            let ens = link
            let ensdata = ENSDataClient()
            let data: ENSData
            do {
                data = try await ensdata.resolve(ens)
                print("FollowENS ENSDataClient: Resolved \(ens) with ENSDataClient: \(String(describing: data))")
            } catch {
                debugPrint("FollowENS ENSDataClient: Failed to resolve \(ens): \(error)")
                // ignore error
                throw PlanetError.EthereumError
            }

            guard let contentHash = data.contentHash else {
                debugPrint("FollowENS ENSDataClient: No content hash set for \(ens)")
                throw PlanetError.ENSNoContentHashError
            }

            debugPrint("Updating planet (ENS type) \(name): ENS data: \(data)")
            if let walletAddress = data.address {
                debugPrint("Tipping: got wallet address for \(self.link): \(walletAddress)")
                var saveNow: Bool = false
                if self.walletAddress == nil || self.walletAddress != walletAddress {
                    saveNow = true
                }
                await MainActor.run {
                    self.walletAddress = walletAddress
                    self.walletAddressResolvedAt = Date()
                }
                if saveNow {
                    await MainActor.run {
                        try? save()
                    }
                }
            }
            else {
                debugPrint("Updating planet (ENS type) \(name): Tipping: no wallet address for \(self.link)")
            }
            debugPrint("Updating planet (ENS type) \(name): about to get contenthash")

            guard let contentHashURL = URL(string: {
                if contentHash.hasPrefix("k51") {
                    return "ipns://\(contentHash)"
                } else if contentHash.hasPrefix("Qm") {
                    return "ipfs://\(contentHash)"
                } else if contentHash.hasPrefix("bafy") {
                    return "ipfs://\(contentHash)"
                } else {
                    return "ipfs://\(contentHash)"
                }
            }() ) else {
                debugPrint("FollowENS ENSDataClient: Invalid content hash URL for \(ens): \(contentHash)")
                throw PlanetError.ENSNoContentHashError
            }

            Self.logger.info("Updating planet (ENS type) \(self.name): Get contenthash from \(self.link): \(String(describing: contentHashURL))")
            guard let newCID = try await ENSUtils.getCID(from: contentHashURL)
            else {
                throw PlanetError.ENSNoContentHashError
            }
            if cid == newCID {
                Self.logger.info("Planet \(self.name, privacy: .public) has no update")
                return
            }
            else {
                Self.logger.info("Planet \(self.name) has update")
            }
            Task.detached(priority: .background) {
                try await IPFSDaemon.shared.pin(cid: newCID)
            }
            let ensAvatarData = await Self.fetchData(from: data.avatar)
            do {
                let planetURL = URL(
                    string: "\(gateway)/ipfs/\(newCID)/planet.json"
                )!
                let (planetData, planetResponse) = try await URLSession.shared.data(from: planetURL)
                if let httpResponse = planetResponse as? HTTPURLResponse,
                    httpResponse.ok
                {
                    let publicPlanet = try JSONDecoder.shared.decode(
                        PublicPlanetModel.self,
                        from: planetData
                    )
                    if publicPlanet.updated <= updated {
                        Self.logger.info("Planet \(self.name, privacy: .public) has no update")
                        return
                    }
                    await MainActor.run {
                        name = publicPlanet.name
                        about = publicPlanet.about
                        updated = publicPlanet.updated

                        twitterUsername = publicPlanet.twitterUsername
                        githubUsername = publicPlanet.githubUsername
                        telegramUsername = publicPlanet.telegramUsername
                        mastodonUsername = publicPlanet.mastodonUsername

                        juiceboxEnabled = publicPlanet.juiceboxEnabled
                        juiceboxProjectID = publicPlanet.juiceboxProjectID
                        juiceboxProjectIDGoerli = publicPlanet.juiceboxProjectIDGoerli
                    }

                    try await updateArticles(publicArticles: publicPlanet.articles, delete: true)



                    if let ensAvatarData {
                        await Self.applyAvatarData(ensAvatarData, to: self)
                    }
                    else if let planetAvatarURL = URL(
                        string: "\(gateway)/ipfs/\(newCID)/avatar.png"
                    ) {
                        await Self.applyAvatarData(await Self.fetchData(from: planetAvatarURL), to: self)
                    }

                    await MainActor.run {
                        cid = newCID
                        lastRetrieved = Date()
                    }

                    if let _ = try? save() {
                        debugPrint("Planet \(self.name) updated and saved")
                    }
                    else {
                        debugPrint("Planet \(self.name) failed to save during update")
                    }
                    return
                }
                else {
                    Self.logger.info("Planet \(self.name) does not have planet.json")
                }
            }
            catch {
                // ignore
            }
            // did not get published planet file, try to get feed
            guard let feedURL = URL(string: "\(gateway)/ipfs/\(newCID)/") else {
                throw PlanetError.InvalidPlanetURLError
            }
            Self.logger.info("Planet \(self.name) is finding feed at \(feedURL)")
            let discovery = try await FeedUtils.findFeed(url: feedURL)
            try await updateFromFeedDiscovery(
                discovery,
                fallbackName: link,
                error: PlanetError.InvalidPlanetURLError,
                newCID: newCID,
                preferredAvatarData: ensAvatarData
            )
            return
        case .dotbit:
            guard let dweb = await DotBitKit.shared.resolve(link) else {
                throw PlanetError.DotBitNoDWebRecordError
            }
            let newCID: String
            if dweb.type == .ipfs {
                newCID = dweb.value
            }
            else {
                guard
                    let resolved = try? await IPFSDaemon.shared.resolveIPNSorDNSLink(
                        name: dweb.value
                    )
                else {
                    throw PlanetError.DotBitIPNSResolveError
                }
                newCID = resolved
            }
            if cid == newCID {
                Self.logger.info("Planet \(self.name, privacy: .public) has no update")
                return
            }
            else {
                Self.logger.info("Planet \(self.name, privacy: .public) has update")
            }
            Task.detached(priority: .background) {
                try await IPFSDaemon.shared.pin(cid: newCID)
            }
            do {
                let planetURL = URL(
                    string: "\(gateway)/ipfs/\(newCID)/planet.json"
                )!
                let (planetData, planetResponse) = try await URLSession.shared.data(from: planetURL)
                if let httpResponse = planetResponse as? HTTPURLResponse,
                    httpResponse.ok
                {
                    let publicPlanet = try JSONDecoder.shared.decode(
                        PublicPlanetModel.self,
                        from: planetData
                    )
                    if publicPlanet.updated <= updated {
                        Self.logger.info("Planet \(self.name, privacy: .public) has no update")
                        return
                    }
                    await MainActor.run {
                        name = publicPlanet.name
                        about = publicPlanet.about
                        updated = publicPlanet.updated

                        twitterUsername = publicPlanet.twitterUsername
                        githubUsername = publicPlanet.githubUsername
                        telegramUsername = publicPlanet.telegramUsername
                        mastodonUsername = publicPlanet.mastodonUsername
                    }

                    try await updateArticles(publicArticles: publicPlanet.articles, delete: true)

                    if let planetAvatarURL = URL(
                        string: "\(gateway)/ipfs/\(newCID)/avatar.png"
                    ) {
                        await Self.applyAvatarData(await Self.fetchData(from: planetAvatarURL), to: self)
                    }

                    await MainActor.run {
                        cid = newCID
                        lastRetrieved = Date()
                    }

                    if let _ = try? save() {
                        debugPrint("Planet \(self.name) updated and saved")
                    }
                    else {
                        debugPrint("Planet \(self.name) failed to save during update")
                    }
                    return
                }
                else {
                    Self.logger.info("Planet \(self.name) does not have planet.json")
                }
            }
            catch {
                // ignore
            }
            // did not get published planet file, try to get feed
            guard let feedURL = URL(string: "\(gateway)/ipfs/\(newCID)/") else {
                throw PlanetError.InvalidPlanetURLError
            }
            Self.logger.info("Planet \(self.name) is finding feed at \(feedURL)")
            let discovery = try await FeedUtils.findFeed(url: feedURL)
            try await updateFromFeedDiscovery(
                discovery,
                fallbackName: link,
                error: PlanetError.InvalidPlanetURLError,
                newCID: newCID
            )
            return
        case .dns:
            guard let feedURL = URL(string: link) else {
                throw PlanetError.PlanetFeedError
            }
            let discovery = try await FeedUtils.findFeed(url: feedURL)
            try await updateFromFeedDiscovery(
                discovery,
                fallbackName: link,
                error: PlanetError.PlanetFeedError
            )
            return
        }
    }

    func updateArticles(publicArticles: [PublicArticleModel], delete: Bool = false) async throws {
        // planet file will have all the articles, so delete a planet article if it is no longer presented
        // feed will rollover old articles, so retain the article even if it is not in feed
        var existingArticleMap: [String: FollowingArticleModel] = [:]
        var existingLinks: [String] = []
        for existingArticle in articles {
            existingArticleMap[existingArticle.link] = existingArticle
            existingLinks.append(existingArticle.link)
        }

        // debugPrint("updateArticles: current existing article map \(existingArticleMap)")

        var newArticles: [FollowingArticleModel] = []
        for publicArticle in publicArticles {
            var link: String
            link = publicArticle.link
            if link.startsWithInternalGateway() {
                link = String(publicArticle.link.dropFirst(22))
            }
            if link.hasPrefix("/ipfs/Qm"), link.count > (6 + 46) {
                link = String(link.dropFirst(6 + 46))
            }
            if existingLinks.contains(link) {
                if let article = existingArticleMap[link] {
                    // update
                    await MainActor.run {
                        article.title = publicArticle.title
                        article.content = publicArticle.content
                        // If you added a new feature to the article model
                        // Remember to take care of the updates here
                        article.audioFilename = publicArticle.audioFilename
                        article.videoFilename = publicArticle.videoFilename
                        article.attachments = publicArticle.attachments
                    }
                    let summary: String? = FollowingArticleModel.extractSummary(
                        article: article,
                        planet: self
                    )
                    await MainActor.run {
                        article.summary = summary
                    }
                    try article.save()
                    existingArticleMap.removeValue(forKey: link)
                }
            }
            else {
                debugPrint("updateArticles: adding new article \(link)")
                // created
                let articleModel = FollowingArticleModel.from(
                    publicArticle: publicArticle,
                    planet: self
                )
                try articleModel.save()
                newArticles.append(articleModel)
                await MainActor.run {
                    articles.append(articleModel)
                }
            }
        }

        sendNotification(for: newArticles)

        if delete {
            let deletedArticles = existingArticleMap.values
            await MainActor.run {
                articles.removeAll { deletedArticles.contains($0) }
            }
            deletedArticles.forEach { $0.delete() }
        }
        await MainActor.run {
            articles.sort { $0.created > $1.created }
        }
    }

    func sendNotification(for newArticles: [FollowingArticleModel]) {
        if newArticles.isEmpty {
            return
        }
        let requestID: UUID
        let content = UNMutableNotificationContent()
        content.title = name
        if newArticles.count == 1 {
            requestID = newArticles[0].id
            content.body = newArticles[0].title
            content.categoryIdentifier = "PlanetReadArticleNotification"
        }
        else {
            requestID = id
            content.body = "\(newArticles.count) new articles"
            content.categoryIdentifier = "PlanetShowPlanetNotification"
        }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(
            identifier: requestID.uuidString,
            content: content,
            trigger: trigger
        )
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.add(request) { error in
            if let error = error {
                Self.logger.warning(
                    "Cannot send user notifications for new articles: \(error.localizedDescription)"
                )
            }
            else {
                Self.logger.warning(
                    "Sent notification: \(newArticles.count) new articles, request id: \(requestID)."
                )
            }
        }
    }

    func pin() async {
        if let cid = cid {
            do {
                debugPrint("FollowingPlanet: Pinning \(cid) for \(name)")
                try await IPFSDaemon.shared.pin(cid: cid)
            }
            catch {
                debugPrint("FollowingPlanet: Unable to pin \(cid) for \(name): \(error)")
            }
        }
    }

    func removeIcon() async {
        try? FileManager.default.removeItem(at: avatarPath)
        Task { @MainActor in
            avatar = nil
        }
    }

    private func refreshGatewayAvatar(label: String) async {
        guard let cid else {
            debugPrint("Unable to refresh avatar for \(name) (type=\(label)) because CID is nil")
            return
        }
        guard let planetAvatarURL = URL(
            string: "\(IPFSState.shared.getGateway())/ipfs/\(cid)/avatar.png"
        ) else {
            debugPrint("Unable to refresh avatar for \(name) (type=\(label)) because avatar URL is invalid")
            return
        }
        if let data = await Self.fetchData(from: planetAvatarURL) {
            await Self.applyAvatarData(data, to: self)
        }
        else {
            debugPrint("Unable to refresh avatar for \(name) (type=\(label))")
        }
    }

    private func refreshFeedAvatar() async {
        guard let feedURL = URL(string: link) else {
            return
        }
        do {
            let discovery = try await FeedUtils.findFeed(url: feedURL)
            let avatarData: Data?
            if let feedData = discovery.feedData,
               let discoveredFeedURL = discovery.feedURL
            {
                let feed = try await FeedUtils.parseFeed(data: feedData, url: discoveredFeedURL)
                avatarData = try await Self.resolveFeedAvatarData(
                    feedAvatar: feed.avatar,
                    discovery: discovery
                )
            }
            else {
                avatarData = try await Self.resolveHTMLAvatarData(from: discovery)
            }
            if let avatarData {
                await Self.applyAvatarData(avatarData, to: self)
            }
            else {
                debugPrint("refreshIcon: avatar not found for \(feedURL)")
            }
        }
        catch {
            debugPrint("refreshIcon error: \(error)")
        }
    }

    func refreshIcon() async {
        debugPrint("About to refresh avatar for \(self) name=\(name) type=\(planetType) link=\(link)")
        switch planetType {
        case .ens:
            debugPrint("About to refresh avatar for \(name) (type=ens) from \(link)")
            let ensdata = ENSDataClient()
            if let data = try? await ensdata.resolve(link),
               let ensAvatarData = await Self.fetchData(from: data.avatar),
               Self.imageIsValid(ensAvatarData)
            {
                await Self.applyAvatarData(ensAvatarData, to: self)
            }
            else {
                await refreshGatewayAvatar(label: "ens")
            }
        case .planet:
            debugPrint("About to refresh avatar for \(name) (type=planet) from \(link)")
            await refreshGatewayAvatar(label: "planet")
        case .dnslink:
            debugPrint("About to refresh avatar for \(name) (type=dnslink) from \(link)")
            await refreshGatewayAvatar(label: "dnslink")
        case .dotbit:
            debugPrint("About to refresh avatar for \(name) (type=dotbit) from \(link)")
            await refreshGatewayAvatar(label: "dotbit")
        case .dns:
            debugPrint("About to fetch avatar for \(name) (type=dns) from \(link)")
            await refreshFeedAvatar()
        }
    }

    func findWalletAddress() async {
        if self.link.hasSuffix(".eth") {
            let ens = self.link
            let ensdata = ENSDataClient()
            let data: ENSData
            do {
                data = try await ensdata.resolve(self.link)
                print("FollowENS ENSDataClient: Resolved \(ens) with ENSDataClient: \(String(describing: data))")
                if let address = data.address {
                    await MainActor.run {
                        self.walletAddress = address
                        self.walletAddressResolvedAt = Date()
                        debugPrint("FollowENS ENSDataClient: found wallet address for \(self.link): \(address)")
                        try? self.save()
                    }
                }
            } catch {
                debugPrint("Tipping: Unable to find wallet address for \(self.link): \(error)")
            }
        }
    }

    func save() throws {
        try JSONEncoder.shared.encode(self).write(to: infoPath, options: .atomic)
    }

    func archive() {
        Task { @MainActor in
            self.archived = true
            self.archivedAt = Date()
            try? self.save()
        }
    }

    func unpin() {
        Task.init(priority: .background) {
            if let lastCID = cid {
                debugPrint("Unpinning \(lastCID)")
                try? await IPFSDaemon.shared.unpin(cid: lastCID)
            }
        }
    }

    func delete() {
        PlanetStore.removeSpotlightItems(forPlanetID: id)
        try? FileManager.default.removeItem(at: basePath)
    }

    func navigationSubtitle() -> String {
        if articles.isEmpty {
            return "0 articles"
        }
        else {
            return "\(unreadCount) unread · \(articles.count) total"
        }
    }

    @ViewBuilder
    func avatarView(size: CGFloat) -> some View {
        if let image = self.avatar {
            Image(nsImage: image)
                .interpolation(.high)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size, alignment: .center)
                .cornerRadius(size / 2)
                .overlay(
                    RoundedRectangle(cornerRadius: size / 2)
                        .stroke(Color("BorderColor"), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                .padding(2)
        }
        else {
            Text(self.nameInitials)
                .font(Font.custom("Arial Rounded MT Bold", size: size / 2))
                .foregroundColor(Color.white)
                .contentShape(Rectangle())
                .frame(width: size, height: size, alignment: .center)
                .background(
                    LinearGradient(
                        gradient: ViewUtils.getPresetGradient(from: self.id),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(size / 2)
                .overlay(
                    RoundedRectangle(cornerRadius: size / 2)
                        .stroke(Color("BorderColor"), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                .padding(2)
        }
    }

    func mastodonURL() -> URL? {
        guard let username = self.mastodonUsername else {
            return nil
        }
        let components = username.components(separatedBy: "@")
        guard components.count == 3 else {
            // The first component is empty
            return nil  // Invalid input
        }
        let domain = components[2]
        let user = components[1]
        return URL(string: "https://\(domain)/@\(user)")
    }

    func juiceboxURL() -> URL? {
        if self.juiceboxEnabled == false {
            return nil
        }
        if self.juiceboxProjectID == nil && self.juiceboxProjectIDGoerli == nil {
            return nil
        }
        if let projectID = self.juiceboxProjectID {
            return URL(string: "https://juicebox.money/v2/p/\(projectID)")
        }
        if let projectIDGoerli = self.juiceboxProjectIDGoerli {
            return URL(string: "https://goerli.juicebox.money/v2/p/\(projectIDGoerli)")
        }
        return nil
    }

    @ViewBuilder
    func twitterLabel() -> some View {
        if let twitterUsername = self.twitterUsername, twitterUsername.count > 0 {
            Divider()

            HStack(spacing: 10) {
                Image("custom.twitter")
                    .renderingMode(.original)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16, alignment: .center)
                Button {
                    if let twitterURL = URL(string: "https://twitter.com/@\(twitterUsername)") {
                        NSWorkspace.shared.open(twitterURL)
                    }
                } label: {
                    Text(twitterUsername)
                }.buttonStyle(.link)
            }
        }
    }

    @ViewBuilder
    func githubLabel() -> some View {
        if let githubUsername = self.githubUsername, githubUsername.count > 0 {
            Divider()

            HStack(spacing: 10) {
                Image("custom.github")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16, alignment: .center)
                Button {
                    if let githubURL = URL(string: "https://github.com/\(githubUsername)") {
                        NSWorkspace.shared.open(githubURL)
                    }
                } label: {
                    Text(githubUsername)
                }.buttonStyle(.link)
            }
        }
    }

    @ViewBuilder
    func telegramLabel() -> some View {
        if let telegramUsername = self.telegramUsername, telegramUsername.count > 0 {
            Divider()

            HStack(spacing: 10) {
                Image("custom.telegram")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16, alignment: .center)
                Button {
                    if let telegramURL = URL(string: "https://t.me/\(telegramUsername)") {
                        NSWorkspace.shared.open(telegramURL)
                    }
                } label: {
                    Text(telegramUsername)
                }.buttonStyle(.link)
            }
        }
    }

    @ViewBuilder
    func mastodonLabel() -> some View {
        if let mastodonUsername = self.mastodonUsername, mastodonUsername.count > 0 {
            Divider()

            HStack(spacing: 10) {
                Image("custom.mastodon.fill")
                    .renderingMode(.original)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16, alignment: .center)
                Button {
                    if let mastodonURL = self.mastodonURL() {
                        NSWorkspace.shared.open(mastodonURL)
                    }
                } label: {
                    Text(mastodonUsername)
                }.buttonStyle(.link)
            }
        }
    }

    @ViewBuilder
    func juiceboxLabel() -> some View {
        if let juiceboxEnabled = self.juiceboxEnabled, juiceboxEnabled,
            self.juiceboxProjectID != nil || self.juiceboxProjectIDGoerli != nil
        {
            Divider()

            HStack(spacing: 10) {
                Image("custom.juicebox")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16, alignment: .center)
                Button {
                    if let projectURL = self.juiceboxURL() {
                        NSWorkspace.shared.open(projectURL)
                    }
                } label: {
                    Text(self.juiceboxURL()?.absoluteString.dropFirst(8) ?? "Juicebox Project")
                }.buttonStyle(.link)
            }
        }
    }

    @ViewBuilder
    func socialViews() -> some View {
        self.twitterLabel()
        self.juiceboxLabel()
        self.githubLabel()
        self.telegramLabel()
        self.mastodonLabel()
    }

    @ViewBuilder
    func sourceAddressView() -> some View {
        Divider()

        HStack(spacing: 10) {
            switch self.planetType {
            case .planet:
                Image("IPFS")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16, alignment: .center)
                    .padding(.leading, 10)
            case .ens:
                Image("ENS")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16, alignment: .center)
                    .padding(.leading, 10)
            default:
                Image("RSS")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16, alignment: .center)
                    .padding(.leading, 10)
            }
            Button {
                if let url = self.browserURL {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Text(self.link)
                .lineLimit(1).truncationMode(.middle)
                .padding(.trailing, 10)
            }.buttonStyle(.link)
        }
    }
}
