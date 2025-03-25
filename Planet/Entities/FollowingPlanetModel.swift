import ENSKit
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
    @Published var articles: [FollowingArticleModel]! = nil
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
                return URL(string: "https://\(link).ipfs2.eth.limo/")
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
                    return URL(string: "https://\(cid).ipfs2.eth.limo/")
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

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(about)
        hasher.combine(created)
        hasher.combine(planetType)
        hasher.combine(link)
        hasher.combine(cid)
        hasher.combine(updated)
        hasher.combine(lastRetrieved)
        hasher.combine(archived)
        hasher.combine(archivedAt)
        hasher.combine(walletAddress)
        hasher.combine(walletAddressResolvedAt)
        hasher.combine(isUpdating)
        hasher.combine(articles)
        hasher.combine(avatar)
        hasher.combine(twitterUsername)
        hasher.combine(githubUsername)
        hasher.combine(telegramUsername)
        hasher.combine(mastodonUsername)
        hasher.combine(juiceboxEnabled)
        hasher.combine(juiceboxProjectID)
        hasher.combine(juiceboxProjectIDGoerli)
    }

    static func == (lhs: FollowingPlanetModel, rhs: FollowingPlanetModel) -> Bool {
        if lhs === rhs {
            return true
        }
        if type(of: lhs) != type(of: rhs) {
            return false
        }
        return lhs.id == rhs.id
            && lhs.name == rhs.name
            && lhs.about == rhs.about
            && lhs.created == rhs.created
            && lhs.planetType == rhs.planetType
            && lhs.link == rhs.link
            && lhs.cid == rhs.cid
            && lhs.updated == rhs.updated
            && lhs.lastRetrieved == rhs.lastRetrieved
            && lhs.archived == rhs.archived
            && lhs.archivedAt == rhs.archivedAt
            && lhs.walletAddress == rhs.walletAddress
            && lhs.walletAddressResolvedAt == rhs.walletAddressResolvedAt
            && lhs.isUpdating == rhs.isUpdating
            && lhs.articles == rhs.articles
            && lhs.avatar == rhs.avatar
            && lhs.twitterUsername == rhs.twitterUsername
            && lhs.githubUsername == rhs.githubUsername
            && lhs.telegramUsername == rhs.telegramUsername
            && lhs.mastodonUsername == rhs.mastodonUsername
            && lhs.juiceboxEnabled == rhs.juiceboxEnabled
            && lhs.juiceboxProjectID == rhs.juiceboxProjectID
            && lhs.juiceboxProjectIDGoerli == rhs.juiceboxProjectIDGoerli
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
        planet.avatar = NSImage(contentsOf: planet.avatarPath)

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
            }
            throw PlanetError.PlanetExistsError
        }
        if link.hasSuffix(".eth") {
            return try await followENS(ens: link)
        }
        if link.hasSuffix(".bit") {
            return try await followDotBit(dotbit: link)
        }
        else if link.lowercased().hasPrefix("http://") || link.lowercased().hasPrefix("https://") {
            return try await followHTTP(link: link)
        }
        else {
            return try await followIPNSorDNSLink(name: link)
        }
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
            debugPrint("Get Public Planet from CID: Invalid Planet JSON")
            let planetString = String(data: planetData, encoding: .utf8)
            debugPrint("Get Public Planet from CID: Error: \(error)")
            return nil
        }
    }

    static func followFeaturedSources() async throws {
        Task { @MainActor in
            let alert = NSAlert()
            alert.messageText = "Follow Featured Planets"
            alert.informativeText = "You will start following: \n\nplanetable.eth\nvitalik.eth"
            let _ = alert.runModal()
        }
        // Follow planetable.eth and vitalik.eth if not already followed
        debugPrint("About to follow featured planets")
        let planetableFollowed = await PlanetStore.shared.followingPlanets.contains {
            $0.link == "planetable.eth"
        }
        if !planetableFollowed {
            do {
                let planet = try await FollowingPlanetModel.follow(link: "planetable.eth")
                Task { @MainActor in
                    PlanetStore.shared.followingPlanets.insert(planet, at: 0)
                }
            }
            catch {
                debugPrint("Failed to follow planetable.eth: \(error)")
            }
        } else {
            debugPrint("Already following planetable.eth")
        }
        let vitalikFollowed = await PlanetStore.shared.followingPlanets.contains {
            $0.link == "vitalik.eth"
        }
        if !vitalikFollowed {
            do {
                let planet = try await FollowingPlanetModel.follow(link: "vitalik.eth")
                Task { @MainActor in
                    PlanetStore.shared.followingPlanets.insert(planet, at: 0)
                }
            }
            catch {
                debugPrint("Failed to follow vitalik.eth: \(error)")
            }
        } else {
            debugPrint("Already following vitalik.eth")
        }
    }

    static func followENS(ens: String) async throws -> FollowingPlanetModel {
        var enskit = ENSKit(jsonrpcClient: EthereumAPI.Flashbots, ipfsClient: GoIPFSGateway())
        var resolver = try await enskit.resolver(name: ens)
        if resolver == nil {
            enskit = ENSKit(jsonrpcClient: EthereumAPI.Cloudflare, ipfsClient: GoIPFSGateway())
            resolver = try await enskit.resolver(name: ens)
        }
        guard let resolver = resolver else {
            throw PlanetError.InvalidPlanetURLError
        }
        let result: URL?
        do {
            result = try await resolver.contenthash()
        }
        catch {
            throw PlanetError.EthereumError
        }
        Self.logger.info("Get contenthash from \(ens): \(String(describing: result))")
        guard let contenthash = result,
            let cid = try await ENSUtils.getCID(from: contenthash)
        else {
            throw PlanetError.ENSNoContentHashError
        }
        Self.logger.info("Follow \(ens): CID \(cid)")
        Task.detached(priority: .background) {
            try await IPFSDaemon.shared.pin(cid: cid)
        }
        let gateway = IPFSState.shared.getGateway()
        // update a native planet if a public planet is found
        if let publicPlanet = try await getPublicPlanet(from: cid) {
            Self.logger.info("Follow \(ens): found native planet \(publicPlanet.name)")

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

            try FileManager.default.createDirectory(
                at: planet.basePath,
                withIntermediateDirectories: true
            )
            try FileManager.default.createDirectory(
                at: planet.articlesPath,
                withIntermediateDirectories: true
            )

            planet.articles = publicPlanet.articles.map {
                FollowingArticleModel.from(publicArticle: $0, planet: planet)
            }
            planet.articles.sort { $0.created > $1.created }

            // try to find ENS avatar
            if let data = try? await resolver.avatar(),
                let image = NSImage(data: data),
                let _ = try? data.write(to: planet.avatarPath)
            {
                Self.logger.info("Follow \(ens): found avatar from ENS")
                planet.avatar = image
            }
            else
            // try to find native planet avatar
            if let planetAvatarURL = URL(
                string: "\(gateway)/ipfs/\(cid)/avatar.png"
            ),
                let (data, response) = try? await URLSession.shared.data(from: planetAvatarURL),
                let httpResponse = response as? HTTPURLResponse,
                httpResponse.ok,
                let image = NSImage(data: data),
                let _ = try? data.write(to: planet.avatarPath)
            {
                Self.logger.info("Follow \(ens): found avatar in native planet")
                planet.avatar = image
            }

            // Resolve wallet address

            if let walletAddress = try? await resolver.addr() {
                planet.walletAddress = "0x" + walletAddress
                planet.walletAddressResolvedAt = Date()
                debugPrint("Tipping: Got wallet address for \(ens): 0x\(walletAddress)")
            }
            else {
                debugPrint("Tipping: Did not get wallet address for \(ens)")
            }

            try planet.save()
            try planet.articles.forEach { try $0.save() }

            Task.detached { @MainActor in
                PlanetStore.shared.updateTotalUnreadCount()
                PlanetStore.shared.updateTotalTodayCount()
            }

            return planet
        }
        debugPrint("Follow \(ens): did not find native planet.json")
        // did not get published planet file, try to get feed
        guard let feedURL = URL(string: "\(gateway)/ipfs/\(cid)/") else {
            throw PlanetError.InvalidPlanetURLError
        }
        let (feedData, htmlSoup) = try await FeedUtils.findFeed(url: feedURL)
        let now = Date()
        let planet: FollowingPlanetModel
        var feedAvatar: Data? = nil
        if let feedData = feedData {
            Self.logger.info("Follow ENS \(ens): found feed")
            let feed = try await FeedUtils.parseFeed(data: feedData, url: feedURL)
            feedAvatar = feed.avatar
            planet = FollowingPlanetModel(
                id: UUID(),
                planetType: .ens,
                name: feed.name ?? ens,
                about: feed.about ?? "",
                link: ens,
                cid: cid,
                created: now,
                updated: now,
                lastRetrieved: now
            )
            // Resolve wallet address

            if let walletAddress = try? await resolver.addr() {
                planet.walletAddress = "0x" + walletAddress
                planet.walletAddressResolvedAt = Date()
                debugPrint("Tipping: Got wallet address for \(ens): \(walletAddress)")
            }
            else {
                debugPrint("Tipping: Did not get wallet address for \(ens)")
            }
            if let publicArticles = feed.articles {
                let items = deduplicate(publicArticles)
                planet.articles = items.map {
                    FollowingArticleModel.from(publicArticle: $0, planet: planet)
                }
                planet.articles.sort { $0.created > $1.created }
            }
            else {
                planet.articles = []
            }
        }
        else if let htmlSoup = htmlSoup {
            Self.logger.info("Follow \(ens): no feed, use homepage as the only article")
            planet = FollowingPlanetModel(
                id: UUID(),
                planetType: .ens,
                name: ens,
                about: "",
                link: ens,
                cid: cid,
                created: now,
                updated: now,
                lastRetrieved: now
            )
            let homepage = PublicArticleModel(
                id: UUID(),
                link: "/",
                title: (try? htmlSoup.title()) ?? "Homepage",
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
            planet.articles = [
                FollowingArticleModel.from(publicArticle: homepage, planet: planet)
            ]
        }
        else {
            throw PlanetError.InvalidPlanetURLError
        }

        try FileManager.default.createDirectory(
            at: planet.basePath,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: planet.articlesPath,
            withIntermediateDirectories: true
        )

        if let data = try? await resolver.avatar(),
            let image = NSImage(data: data),
            let _ = try? data.write(to: planet.avatarPath)
        {
            Self.logger.info("Follow \(ens): found avatar from ENS")
            planet.avatar = image
        }
        else if let data = feedAvatar,
            let image = NSImage(data: data),
            let _ = try? data.write(to: planet.avatarPath)
        {
            Self.logger.info("Follow \(ens): found avatar from feed")
            planet.avatar = image
        }

        try planet.save()
        try planet.articles.forEach { try $0.save() }

        if let walletAddress = try? await resolver.addr() {
            debugPrint("Tipping: got wallet address for \(planet.link): \(walletAddress)")
            var saveNow: Bool = false
            if planet.walletAddress == nil || planet.walletAddress != "0x" + walletAddress {
                saveNow = true
            }
            await MainActor.run {
                planet.walletAddress = "0x" + walletAddress
                planet.walletAddressResolvedAt = Date()
            }
            if saveNow {
                try planet.save()
            }
        }
        else {
            debugPrint("Tipping: no wallet address for \(planet.link)")
        }

        Task.detached { @MainActor in
            PlanetStore.shared.updateTotalUnreadCount()
            PlanetStore.shared.updateTotalTodayCount()
        }

        return planet
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
        Task.detached(priority: .background) {
            try await IPFSDaemon.shared.pin(cid: cid)
        }
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

            try FileManager.default.createDirectory(
                at: planet.basePath,
                withIntermediateDirectories: true
            )
            try FileManager.default.createDirectory(
                at: planet.articlesPath,
                withIntermediateDirectories: true
            )

            planet.articles = publicPlanet.articles.map {
                FollowingArticleModel.from(publicArticle: $0, planet: planet)
            }
            planet.articles.sort { $0.created > $1.created }

            // try to find native planet avatar
            if let planetAvatarURL = URL(
                string: "\(gateway)/ipfs/\(cid)/avatar.png"
            ),
                let (data, response) = try? await URLSession.shared.data(from: planetAvatarURL),
                let httpResponse = response as? HTTPURLResponse,
                httpResponse.ok,
                let image = NSImage(data: data),
                let _ = try? data.write(to: planet.avatarPath)
            {
                Self.logger.info("Follow \(dotbit): found avatar in native planet")
                planet.avatar = image
            }

            try planet.save()
            try planet.articles.forEach { try $0.save() }
            return planet
        }
        // did not get published planet file, try to get feed
        guard let feedURL = URL(string: "\(gateway)/ipfs/\(cid)/") else {
            throw PlanetError.InvalidPlanetURLError
        }
        let (feedData, htmlSoup) = try await FeedUtils.findFeed(url: feedURL)
        let now = Date()
        let planet: FollowingPlanetModel
        var feedAvatar: Data? = nil
        if let feedData = feedData {
            Self.logger.info("Follow .bit \(dotbit): found feed")
            let feed = try await FeedUtils.parseFeed(data: feedData, url: feedURL)
            feedAvatar = feed.avatar
            planet = FollowingPlanetModel(
                id: UUID(),
                planetType: .ens,
                name: feed.name ?? dotbit,
                about: feed.about ?? "",
                link: dotbit,
                cid: cid,
                created: now,
                updated: now,
                lastRetrieved: now
            )
            if let publicArticles = feed.articles {
                let items = deduplicate(publicArticles)
                planet.articles = items.map {
                    FollowingArticleModel.from(publicArticle: $0, planet: planet)
                }
                planet.articles.sort { $0.created > $1.created }
            }
            else {
                planet.articles = []
            }
        }
        else if let htmlSoup = htmlSoup {
            Self.logger.info("Follow \(dotbit): no feed, use homepage as the only article")
            planet = FollowingPlanetModel(
                id: UUID(),
                planetType: .dotbit,
                name: dotbit,
                about: "",
                link: dotbit,
                cid: cid,
                created: now,
                updated: now,
                lastRetrieved: now
            )
            let homepage = PublicArticleModel(
                id: UUID(),
                link: "/",
                title: (try? htmlSoup.title()) ?? "Homepage",
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
            planet.articles = [
                FollowingArticleModel.from(publicArticle: homepage, planet: planet)
            ]
        }
        else {
            throw PlanetError.InvalidPlanetURLError
        }

        try FileManager.default.createDirectory(
            at: planet.basePath,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: planet.articlesPath,
            withIntermediateDirectories: true
        )

        if let data = feedAvatar,
            let image = NSImage(data: data),
            let _ = try? data.write(to: planet.avatarPath)
        {
            Self.logger.info("Follow \(dotbit): found avatar from feed")
            planet.avatar = image
        }

        try planet.save()
        try planet.articles.forEach { try $0.save() }
        return planet
    }

    static func followHTTP(link: String) async throws -> FollowingPlanetModel {
        guard let feedURL = URL(string: link) else {
            throw PlanetError.InvalidPlanetURLError
        }
        let (feedData, htmlDocument) = try await FeedUtils.findFeed(url: feedURL)
        guard let feedData = feedData else {
            throw PlanetError.InvalidPlanetURLError
        }
        Self.logger.info("Follow HTTP feed \(link): found feed")
        let feed = try await FeedUtils.parseFeed(data: feedData, url: feedURL)
        let now = Date()
        let planet = FollowingPlanetModel(
            id: UUID(),
            planetType: .dns,
            name: feed.name ?? link,
            about: feed.about ?? "",
            link: link,
            cid: nil,
            created: now,
            updated: now,
            lastRetrieved: now
        )
        try FileManager.default.createDirectory(
            at: planet.basePath,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: planet.articlesPath,
            withIntermediateDirectories: true
        )

        if let publicArticles = feed.articles {
            let items: [PublicArticleModel] = deduplicate(publicArticles)
            planet.articles = items.map {
                FollowingArticleModel.from(publicArticle: $0, planet: planet)
            }
            planet.articles.sort { $0.created > $1.created }
        }
        else {
            planet.articles = []
        }

        var feedAvatar: Data? = nil
        if feed.avatar == nil {
            if let soup = htmlDocument {
                feedAvatar = try await FeedUtils.findAvatarFromHTMLOGImage(
                    htmlDocument: soup,
                    htmlURL: feedURL
                )
                if feedAvatar == nil {
                    feedAvatar = try await FeedUtils.findAvatarFromHTMLIcons(
                        htmlDocument: soup,
                        htmlURL: feedURL
                    )
                }
            }
        }

        var avatarData: Data? = nil

        if feed.avatar != nil {
            avatarData = feed.avatar
        }

        if avatarData == nil, feedAvatar != nil {
            avatarData = feedAvatar
        }

        if let data = avatarData,
            let image = NSImage(data: data),
            let _ = try? data.write(to: planet.avatarPath)
        {
            Self.logger.info("Follow \(link): found avatar from feed")
            planet.avatar = image
        }

        try planet.save()
        try planet.articles.forEach { try $0.save() }
        return planet
    }

    static func followIPNSorDNSLink(name: String) async throws -> FollowingPlanetModel {
        let planetType: PlanetType = ENSUtils.isIPNS(name) ? .planet : .dnslink
        let cid = try await IPFSDaemon.shared.resolveIPNSorDNSLink(name: name)
        let gateway = IPFSState.shared.getGateway()
        Self.logger.info("Follow \(name): CID \(cid)")
        Task.detached(priority: .background) {
            try await IPFSDaemon.shared.pin(cid: cid)
        }
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

            try FileManager.default.createDirectory(
                at: planet.basePath,
                withIntermediateDirectories: true
            )
            try FileManager.default.createDirectory(
                at: planet.articlesPath,
                withIntermediateDirectories: true
            )

            planet.articles = publicPlanet.articles.map {
                FollowingArticleModel.from(publicArticle: $0, planet: planet)
            }
            planet.articles.sort {
                $0.created > $1.created
            }

            if let planetAvatarURL = URL(
                string: "\(gateway)/ipfs/\(cid)/avatar.png"
            ),
                let (data, response) = try? await URLSession.shared.data(from: planetAvatarURL),
                let httpResponse = response as? HTTPURLResponse,
                httpResponse.ok,
                let image = NSImage(data: data),
                let _ = try? data.write(to: planet.avatarPath)
            {
                planet.avatar = image
            }

            try planet.save()
            try planet.articles.forEach {
                try $0.save()
            }

            Task.detached { @MainActor in
                PlanetStore.shared.updateTotalUnreadCount()
                PlanetStore.shared.updateTotalTodayCount()
            }

            return planet
        }
        // did not get published planet file, try to get feed
        guard let feedURL = URL(string: "\(gateway)/ipfs/\(cid)/") else {
            throw PlanetError.InvalidPlanetURLError
        }
        let (feedData, htmlSoup) = try await FeedUtils.findFeed(url: feedURL)
        let now = Date()
        let planet: FollowingPlanetModel
        var feedAvatar: Data? = nil
        if let feedData = feedData {
            Self.logger.info("Follow IPNS or DNSLink \(name): found feed")
            let feed = try await FeedUtils.parseFeed(data: feedData, url: feedURL)
            feedAvatar = feed.avatar
            planet = FollowingPlanetModel(
                id: UUID(),
                planetType: planetType,
                name: feed.name ?? name,
                about: feed.about ?? "",
                link: name,
                cid: cid,
                created: now,
                updated: now,
                lastRetrieved: now
            )
            if let publicArticles = feed.articles {
                let items: [PublicArticleModel] = deduplicate(publicArticles)
                planet.articles = items.map {
                    FollowingArticleModel.from(publicArticle: $0, planet: planet)
                }
                planet.articles.sort { $0.created > $1.created }
            }
            else {
                planet.articles = []
            }
        }
        else if let htmlSoup = htmlSoup {
            Self.logger.info("Follow \(name): no feed, use homepage as the only article")
            planet = FollowingPlanetModel(
                id: UUID(),
                planetType: .ens,
                name: name,
                about: "",
                link: name,
                cid: cid,
                created: now,
                updated: now,
                lastRetrieved: now
            )
            let homepage = PublicArticleModel(
                id: UUID(),
                link: "/",
                title: (try? htmlSoup.title()) ?? "Homepage",
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
            planet.articles = [
                FollowingArticleModel.from(publicArticle: homepage, planet: planet)
            ]
        }
        else {
            throw PlanetError.InvalidPlanetURLError
        }

        try FileManager.default.createDirectory(
            at: planet.basePath,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: planet.articlesPath,
            withIntermediateDirectories: true
        )

        if let data = feedAvatar,
            let image = NSImage(data: data),
            let _ = try? data.write(to: planet.avatarPath)
        {
            Self.logger.info("Follow \(name): found avatar from feed")
            planet.avatar = image
        }

        try planet.save()
        try planet.articles.forEach { try $0.save() }

        Task.detached { @MainActor in
            PlanetStore.shared.updateTotalUnreadCount()
            PlanetStore.shared.updateTotalTodayCount()
        }

        return planet
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
                    ),
                        let (data, response) = try? await URLSession.shared.data(
                            from: planetAvatarURL
                        ),
                        let httpResponse = response as? HTTPURLResponse,
                        httpResponse.ok,
                        let image = NSImage(data: data),
                        let _ = try? data.write(to: avatarPath)
                    {
                        await MainActor.run {
                            avatar = image
                        }
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
            let (feedData, _) = try await FeedUtils.findFeed(url: feedURL)
            guard let feedData = feedData else {
                throw PlanetError.InvalidPlanetURLError
            }
            let feed = try await FeedUtils.parseFeed(data: feedData, url: feedURL)
            let now = Date()

            await MainActor.run {
                name = feed.name ?? link
                about = feed.about ?? ""
                updated = now
                if cid != newCID {
                    cid = newCID
                }
                lastRetrieved = now
            }

            if let publicArticles = feed.articles {
                try await updateArticles(publicArticles: publicArticles)
            }

            if let data = feed.avatar,
                let image = NSImage(data: data),
                let _ = try? data.write(to: avatarPath)
            {
                await MainActor.run {
                    avatar = image
                }
            }

            await MainActor.run {
                try? save()
            }
            return
        case .ens:
            debugPrint("Updating planet (ENS type) \(name): link: \(link)")
            var enskit = ENSKit(jsonrpcClient: EthereumAPI.Flashbots, ipfsClient: GoIPFSGateway())
            var resolver = try await enskit.resolver(name: link)
            if resolver == nil {
                enskit = ENSKit(jsonrpcClient: EthereumAPI.Cloudflare, ipfsClient: GoIPFSGateway())
                resolver = try await enskit.resolver(name: link)
            }
            guard let resolver = resolver else {
                throw PlanetError.InvalidPlanetURLError
            }
            debugPrint("Updating planet (ENS type) \(name): resolver: \(resolver)")
            if let walletAddress = try? await resolver.addr() {
                debugPrint("Tipping: got wallet address for \(self.link): \(walletAddress)")
                var saveNow: Bool = false
                if self.walletAddress == nil || self.walletAddress != "0x" + walletAddress {
                    saveNow = true
                }
                await MainActor.run {
                    self.walletAddress = "0x" + walletAddress
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
            let result: URL?
            do {
                result = try await resolver.contenthash()
            }
            catch {
                throw PlanetError.EthereumError
            }
            Self.logger.info("Updating planet (ENS type) \(self.name): Get contenthash from \(self.link): \(String(describing: result))")
            guard let contenthash = result,
                let newCID = try await ENSUtils.getCID(from: contenthash)
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

                    if let data = try? await resolver.avatar(),
                        let image = NSImage(data: data),
                        let _ = try? data.write(to: avatarPath)
                    {
                        await MainActor.run {
                            avatar = image
                        }
                    }
                    else if let planetAvatarURL = URL(
                        string: "\(gateway)/ipfs/\(newCID)/avatar.png"
                    ),
                        let (data, response) = try? await URLSession.shared.data(
                            from: planetAvatarURL
                        ),
                        let httpResponse = response as? HTTPURLResponse,
                        httpResponse.ok,
                        let image = NSImage(data: data),
                        let _ = try? data.write(to: avatarPath)
                    {
                        await MainActor.run {
                            avatar = image
                        }
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
            let (feedData, _) = try await FeedUtils.findFeed(url: feedURL)
            guard let feedData = feedData else {
                throw PlanetError.InvalidPlanetURLError
            }
            Self.logger.info("Planet \(self.name) feed data fetched: \(feedData.count) bytes")
            let feed = try await FeedUtils.parseFeed(data: feedData, url: feedURL)
            let now = Date()

            await MainActor.run {
                cid = newCID
                name = feed.name ?? link
                about = feed.about ?? ""
                updated = now
                lastRetrieved = now
            }

            if let publicArticles = feed.articles {
                try await updateArticles(publicArticles: publicArticles)
            }

            if let data = try? await resolver.avatar(),
                let image = NSImage(data: data),
                let _ = try? data.write(to: avatarPath)
            {
                await MainActor.run {
                    avatar = image
                }
            }
            else if let data = feed.avatar,
                let image = NSImage(data: data),
                let _ = try? data.write(to: avatarPath)
            {
                await MainActor.run {
                    avatar = image
                }
            }

            await MainActor.run {
                try? save()
            }
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
                    ),
                        let (data, response) = try? await URLSession.shared.data(
                            from: planetAvatarURL
                        ),
                        let httpResponse = response as? HTTPURLResponse,
                        httpResponse.ok,
                        let image = NSImage(data: data),
                        let _ = try? data.write(to: avatarPath)
                    {
                        await MainActor.run {
                            avatar = image
                        }
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
            let (feedData, _) = try await FeedUtils.findFeed(url: feedURL)
            guard let feedData = feedData else {
                throw PlanetError.InvalidPlanetURLError
            }
            Self.logger.info("Planet \(self.name) feed data fetched: \(feedData.count) bytes")
            let feed = try await FeedUtils.parseFeed(data: feedData, url: feedURL)
            let now = Date()

            await MainActor.run {
                cid = newCID
                name = feed.name ?? link
                about = feed.about ?? ""
                updated = now
                lastRetrieved = now
            }

            if let publicArticles = feed.articles {
                try await updateArticles(publicArticles: publicArticles)
            }

            if let data = feed.avatar,
                let image = NSImage(data: data),
                let _ = try? data.write(to: avatarPath)
            {
                await MainActor.run {
                    avatar = image
                }
            }

            await MainActor.run {
                try? save()
            }
            return
        case .dns:
            guard let feedURL = URL(string: link) else {
                throw PlanetError.PlanetFeedError
            }
            let (feedData, htmlDocument) = try await FeedUtils.findFeed(url: feedURL)
            guard let feedData = feedData else {
                throw PlanetError.PlanetFeedError
            }
            let feed = try await FeedUtils.parseFeed(data: feedData, url: feedURL)

            var feedAvatar: Data? = nil
            if feed.avatar == nil {
                let homepageDocument: Document?
                if htmlDocument == nil {
                    var urlForFindingAvatar: URL? = nil
                    if let feedLink = FeedUtils.findLinkFromFeed(feedData: feedData),
                        let feedLinkURL = URL(string: feedLink)
                    {
                        urlForFindingAvatar = feedLinkURL
                    }
                    else {
                        if let domain = feedURL.host {
                            urlForFindingAvatar = URL(string: "https://\(domain)")
                        }
                    }
                    if let avatarPageURL = urlForFindingAvatar {
                        homepageDocument = try await FeedUtils.getHTMLDocument(url: avatarPageURL)
                    }
                    else {
                        homepageDocument = nil
                    }
                }
                else {
                    homepageDocument = htmlDocument
                }
                if let soup = homepageDocument {
                    debugPrint("FeedAvatar: Trying to fetch og:image as feed avatar")
                    feedAvatar = try await FeedUtils.findAvatarFromHTMLOGImage(
                        htmlDocument: soup,
                        htmlURL: feedURL
                    )
                    var avatarIsSquare = true
                    if let imageData = feedAvatar, let feedAvatarImage = NSImage(data: imageData) {
                        avatarIsSquare = feedAvatarImage.size.width == feedAvatarImage.size.height
                    }
                    if feedAvatar == nil || !avatarIsSquare {
                        debugPrint("FeedAvatar: Trying to fetch icons from links as feed avatar")
                        feedAvatar = try await FeedUtils.findAvatarFromHTMLIcons(
                            htmlDocument: soup,
                            htmlURL: feedURL
                        )
                    }
                }
            }

            var avatarData: Data? = nil

            if feed.avatar != nil {
                avatarData = feed.avatar
            }

            if avatarData == nil, feedAvatar != nil {
                avatarData = feedAvatar
            }

            let now = Date()
            await MainActor.run {
                name = feed.name ?? link
                about = feed.about ?? ""
                updated = now
                lastRetrieved = now
            }

            if let publicArticles = feed.articles {
                try await updateArticles(publicArticles: publicArticles)
            }

            if let data = avatarData,
                let image = NSImage(data: data),
                let _ = try? data.write(to: avatarPath)
            {
                await MainActor.run {
                    avatar = image
                }
            }

            await MainActor.run {
                try? save()
            }
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

    func removeIcon() async {
        try? FileManager.default.removeItem(at: avatarPath)
        DispatchQueue.main.async {
            self.avatar = nil
        }
    }

    func refreshIcon() async {
        switch planetType {
        case .planet:
            if let planetAvatarURL = URL(
                string: "\(IPFSState.shared.getGateway())/ipfs/\(cid)/avatar.png"
            ),
                let (data, response) = try? await URLSession.shared.data(from: planetAvatarURL),
                let httpResponse = response as? HTTPURLResponse,
                httpResponse.ok,
                let image = NSImage(data: data),
                let _ = try? data.write(to: self.avatarPath)
            {
                DispatchQueue.main.async {
                    self.avatar = image
                }
            }
        case .dns:
            guard let feedURL = URL(string: link) else {
                return
            }
            do {
                let (feedData, htmlSoup) = try await FeedUtils.findFeed(url: feedURL)

                guard let feedData = feedData else {
                    return
                }

                var feedAvatar: Data? = nil
                var urlForFindingAvatar: URL? = nil
                let homepageDocument: Document?

                if htmlSoup == nil {
                    if let domain = feedURL.host {
                        urlForFindingAvatar = URL(string: "https://\(domain)")
                    }
                    if let avatarPageURL = urlForFindingAvatar {
                        homepageDocument = try await FeedUtils.getHTMLDocument(url: avatarPageURL)
                    }
                    else {
                        homepageDocument = nil
                    }
                }
                else {
                    homepageDocument = htmlSoup
                    urlForFindingAvatar = feedURL
                }
                if let soup = homepageDocument, let url = urlForFindingAvatar {
                    debugPrint("refreshIcon: Trying to fetch og:image as feed avatar from \(url)")
                    feedAvatar = try await FeedUtils.findAvatarFromHTMLOGImage(
                        htmlDocument: soup,
                        htmlURL: url
                    )
                    var avatarIsSquare = true
                    if let imageData = feedAvatar, let feedAvatarImage = NSImage(data: imageData) {
                        avatarIsSquare = feedAvatarImage.size.width == feedAvatarImage.size.height
                    }
                    if feedAvatar == nil || !avatarIsSquare {
                        debugPrint(
                            "refreshIcon: Trying to fetch icons from links as feed avatar from \(url)"
                        )
                        feedAvatar = try await FeedUtils.findAvatarFromHTMLIcons(
                            htmlDocument: soup,
                            htmlURL: feedURL
                        )
                    }
                    if feedAvatar == nil {
                        debugPrint("refreshIcon: avatar not found for \(feedURL)")
                    }
                    else {
                        if let data = feedAvatar, let image = NSImage(data: data),
                            let _ = try? data.write(to: self.avatarPath)
                        {
                            DispatchQueue.main.async {
                                self.avatar = image
                            }
                            debugPrint(
                                "refreshIcon: written avatar for \(self.name) to \(self.avatarPath)"
                            )
                        }
                    }
                }
                else {
                    debugPrint("refreshIcon: no soup")
                }
            }
            catch {
                debugPrint("refreshIcon error: \(error)")
            }
        default:
            break
        }
    }

    func save() throws {
        try JSONEncoder.shared.encode(self).write(to: infoPath)
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
        try? FileManager.default.removeItem(at: basePath)
    }

    func resolveWalletAddress() async -> String? {
        if self.planetType == .ens {
            let enskit = ENSKit()
            do {
                if let resolver = try await enskit.resolver(name: link) {
                    let address = try await resolver.addr()
                    return address
                }
                else {
                    return nil
                }
            }
            catch {
                return nil
            }
        }
        else {
            return nil
        }
    }

    func navigationSubtitle() -> String {
        if articles.isEmpty {
            return "0 articles"
        }
        else {
            let unread = articles.filter { $0.read == nil }.count
            return "\(unread) unread · \(articles.count) total"
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
