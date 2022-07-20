import Foundation
import os
import SwiftUI
import UserNotifications

enum PlanetType: Int, Codable {
    case planet = 0
    case ens = 1
    case dnslink = 2
    case dns = 3
}

class FollowingPlanetModel: Equatable, Hashable, Identifiable, ObservableObject, Codable {
    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "FollowingPlanet")

    let id: UUID
    @Published var name: String
    @Published var about: String
    let created: Date
    let planetType: PlanetType
    let link: String
    @Published var cid: String?
    @Published var updated: Date
    @Published var lastRetrieved: Date

    @Published var isUpdating = false

    // populated when initializing
    @Published var articles: [FollowingArticleModel]! = nil
    @Published var avatar: NSImage? = nil

    static let followingPlanetsPath: URL = {
        // ~/Library/Containers/xyz.planetable.Planet/Data/Documents/Planet/Following/
        let url = URLUtils.repoPath.appendingPathComponent("Following", isDirectory: true)
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()
    lazy var basePath = Self.followingPlanetsPath.appendingPathComponent(id.uuidString, isDirectory: true)
    lazy var infoPath = basePath.appendingPathComponent("planet.json", isDirectory: false)
    lazy var articlesPath = basePath.appendingPathComponent("Articles", isDirectory: true)
    lazy var avatarPath = basePath.appendingPathComponent("avatar.png", isDirectory: false)

    var nameInitials: String {
        let initials = name.components(separatedBy: .whitespaces).map { $0.prefix(1).capitalized }.joined()
        return String(initials.prefix(2))
    }
    var webviewURL: URL? {
        if let cid = cid {
            return URL(string: "\(IPFSDaemon.shared.gateway)/ipfs/\(cid)/")
        }
        return URL(string: link)
    }
    var browserURL: URL? {
        if let cid = cid {
            return URL(string: "\(IPFSDaemon.publicGateways[0])/ipfs/\(cid)/")
        }
        return URL(string: link)
    }
    var shareLink: String {
        if link.starts(with: "https://") {
            return link
        }
        return "planet://\(link)"
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
        hasher.combine(isUpdating)
        hasher.combine(articles)
        hasher.combine(avatar)
    }

    static func ==(lhs: FollowingPlanetModel, rhs: FollowingPlanetModel) -> Bool {
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
            && lhs.isUpdating == rhs.isUpdating
            && lhs.articles == rhs.articles
            && lhs.avatar == rhs.avatar
    }

    enum CodingKeys: String, CodingKey {
        case id, planetType, name, about, link, cid, created, updated, lastRetrieved
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
    }

    init(
        id: UUID,
        planetType: PlanetType,
        name: String,
        about: String,
        link: String,
        cid: String?,
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
            Self.logger.warning("Mismatched directory name \(directoryPath.lastPathComponent) with planet info \(planet.id)")
            throw PlanetError.PersistenceError
        }
        let articleDirectory = directoryPath.appendingPathComponent("Articles", isDirectory: true)
        let articleFiles = try FileManager.default.contentsOfDirectory(
            at: articleDirectory,
            includingPropertiesForKeys: nil
        )
        planet.articles = articleFiles.compactMap { try? FollowingArticleModel.load(from: $0, planet: planet) }
        planet.articles.sort { $0.created > $1.created }
        planet.avatar = NSImage(contentsOf: planet.avatarPath)
        return planet
    }

    static func follow(link raw: String) async throws -> FollowingPlanetModel {
        let link: String
        if raw.starts(with: "planet://") {
            link = String(raw.dropFirst("planet://".count))
        } else {
            link = raw
        }
        if let existing = await PlanetStore.shared.followingPlanets.first(where: { $0.link == link }) {
            await MainActor.run {
                PlanetStore.shared.selectedView = .followingPlanet(existing)
            }
            throw PlanetError.PlanetExistsError
        }
        if link.hasSuffix(".eth") {
            return try await followENS(ens: link)
        } else if link.lowercased().hasPrefix("http://") || link.lowercased().hasPrefix("https://") {
            return try await followHTTP(link: link)
        } else {
            return try await followIPNSorDNSLink(name: link)
        }
    }

    static func followENS(ens: String) async throws -> FollowingPlanetModel {
        guard let cid = try await ENSUtils.getCID(ens: ens) else {
            throw PlanetError.ENSNoContentHashError
        }
        Self.logger.info("Follow \(ens): CID \(cid)")
        Task {
            try await IPFSDaemon.shared.pin(cid: cid)
        }
        // update a native planet if a public planet is found
        if let planetURL = URL(string: "\(IPFSDaemon.shared.gateway)/ipfs/\(cid)/planet.json"),
           let (planetData, planetResponse) = try? await URLSession.shared.data(from: planetURL),
           let httpResponse = planetResponse as? HTTPURLResponse,
           httpResponse.ok,
           let publicPlanet = try? JSONDecoder.shared.decode(PublicPlanetModel.self, from: planetData) {
            Self.logger.info("Follow \(ens): found native planet \(publicPlanet.name)")

            let planet = FollowingPlanetModel(
                id: UUID(),
                planetType: .ens,
                name: publicPlanet.name,
                about: publicPlanet.about,
                link: ens,
                cid: cid,
                created: publicPlanet.created,
                updated: publicPlanet.updated,
                lastRetrieved: Date()
            )

            try FileManager.default.createDirectory(at: planet.basePath, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: planet.articlesPath, withIntermediateDirectories: true)

            planet.articles = publicPlanet.articles.map {
                FollowingArticleModel.from(publicArticle: $0, planet: planet)
            }
            planet.articles.sort { $0.created > $1.created }

            // try to find ENS avatar
            if let data = try? await ENSUtils.shared.avatar(name: ens),
               let image = NSImage(data: data),
               let _ = try? data.write(to: planet.avatarPath) {
                Self.logger.info("Follow \(ens): found avatar from ENS")
                planet.avatar = image
            } else
            // try to find native planet avatar
            if let planetAvatarURL = URL(string: "\(IPFSDaemon.shared.gateway)/ipfs/\(cid)/avatar.png"),
               let (data, response) = try? await URLSession.shared.data(from: planetAvatarURL),
               let httpResponse = response as? HTTPURLResponse,
               httpResponse.ok,
               let image = NSImage(data: data),
               let _ = try? data.write(to: planet.avatarPath) {
                Self.logger.info("Follow \(ens): found avatar in native planet")
                planet.avatar = image
            }

            try planet.save()
            try planet.articles.forEach { try $0.save() }
            return planet
        }
        // did not get published planet file, try to get feed
        guard let feedURL = URL(string: "\(IPFSDaemon.shared.gateway)/ipfs/\(cid)/") else {
            throw PlanetError.InvalidPlanetURLError
        }
        let (feedData, htmlSoup) = try await FeedUtils.findFeed(url: feedURL)
        let now = Date()
        let planet: FollowingPlanetModel
        var feedAvatar: Data? = nil
        if let feedData = feedData {
            Self.logger.info("Follow \(ens): found feed")
            let feed = try FeedUtils.parseFeed(data: feedData)
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
            if let publicArticles = feed.articles {
                planet.articles = publicArticles.map {
                    FollowingArticleModel.from(publicArticle: $0, planet: planet)
                }
                planet.articles.sort { $0.created > $1.created }
            } else {
                planet.articles = []
            }
        } else
        if let htmlSoup = htmlSoup {
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
                created: now,
                hasVideo: false,
                videoFilename: nil,
                hasAudio: false,
                audioFilename: nil
            )
            planet.articles = [
                FollowingArticleModel.from(publicArticle: homepage, planet: planet)
            ]
        } else {
            throw PlanetError.InvalidPlanetURLError
        }

        try FileManager.default.createDirectory(at: planet.basePath, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: planet.articlesPath, withIntermediateDirectories: true)

        if let data = try? await ENSUtils.shared.avatar(name: ens),
           let image = NSImage(data: data),
           let _ = try? data.write(to: planet.avatarPath) {
            Self.logger.info("Follow \(ens): found avatar from ENS")
            planet.avatar = image
        } else
        if let data = feedAvatar,
           let image = NSImage(data: data),
           let _ = try? data.write(to: planet.avatarPath) {
            Self.logger.info("Follow \(ens): found avatar from feed")
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
        let (feedData, _) = try await FeedUtils.findFeed(url: feedURL)
        guard let feedData = feedData else {
            throw PlanetError.InvalidPlanetURLError
        }
        Self.logger.info("Follow \(link): found feed")
        let feed = try FeedUtils.parseFeed(data: feedData)
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
        try FileManager.default.createDirectory(at: planet.basePath, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: planet.articlesPath, withIntermediateDirectories: true)

        if let publicArticles = feed.articles {
            planet.articles = publicArticles.map {
                FollowingArticleModel.from(publicArticle: $0, planet: planet)
            }
            planet.articles.sort { $0.created > $1.created }
        } else {
            planet.articles = []
        }

        if let data = feed.avatar,
           let image = NSImage(data: data),
           let _ = try? data.write(to: planet.avatarPath) {
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
        Self.logger.info("Follow \(name): CID \(cid)")
        Task {
            try await IPFSDaemon.shared.pin(cid: cid)
        }
        if let planetURL = URL(string: "\(IPFSDaemon.shared.gateway)/ipfs/\(cid)/planet.json"),
           let (planetData, planetResponse) = try? await URLSession.shared.data(from: planetURL),
           let httpResponse = planetResponse as? HTTPURLResponse,
           httpResponse.ok {
            let publicPlanet = try JSONDecoder.shared.decode(PublicPlanetModel.self, from: planetData)
            let planet = FollowingPlanetModel(
                id: UUID(),
                planetType: planetType,
                name: publicPlanet.name,
                about: publicPlanet.about,
                link: name,
                cid: cid,
                created: publicPlanet.created,
                updated: publicPlanet.updated,
                lastRetrieved: Date()
            )

            try FileManager.default.createDirectory(at: planet.basePath, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: planet.articlesPath, withIntermediateDirectories: true)

            planet.articles = publicPlanet.articles.map {
                FollowingArticleModel.from(publicArticle: $0, planet: planet)
            }
            planet.articles.sort {
                $0.created > $1.created
            }

            if let planetAvatarURL = URL(string: "\(IPFSDaemon.shared.gateway)/ipfs/\(cid)/avatar.png"),
               let (data, response) = try? await URLSession.shared.data(from: planetAvatarURL),
               let httpResponse = response as? HTTPURLResponse,
               httpResponse.ok,
               let image = NSImage(data: data),
               let _ = try? data.write(to: planet.avatarPath) {
                planet.avatar = image
            }

            try planet.save()
            try planet.articles.forEach {
                try $0.save()
            }
            return planet
        }
        // did not get published planet file, try to get feed
        guard let feedURL = URL(string: "\(IPFSDaemon.shared.gateway)/ipfs/\(cid)/") else {
            throw PlanetError.InvalidPlanetURLError
        }
        let (feedData, htmlSoup) = try await FeedUtils.findFeed(url: feedURL)
        let now = Date()
        let planet: FollowingPlanetModel
        var feedAvatar: Data? = nil
        if let feedData = feedData {
            Self.logger.info("Follow \(name): found feed")
            let feed = try FeedUtils.parseFeed(data: feedData)
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
                planet.articles = publicArticles.map {
                    FollowingArticleModel.from(publicArticle: $0, planet: planet)
                }
                planet.articles.sort { $0.created > $1.created }
            } else {
                planet.articles = []
            }
        } else
        if let htmlSoup = htmlSoup {
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
                created: now,
                hasVideo: false,
                videoFilename: nil,
                hasAudio: false,
                audioFilename: nil
            )
            planet.articles = [
                FollowingArticleModel.from(publicArticle: homepage, planet: planet)
            ]
        } else {
            throw PlanetError.InvalidPlanetURLError
        }

        try FileManager.default.createDirectory(at: planet.basePath, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: planet.articlesPath, withIntermediateDirectories: true)

        if let data = feedAvatar,
           let image = NSImage(data: data),
           let _ = try? data.write(to: planet.avatarPath) {
            Self.logger.info("Follow \(name): found avatar from feed")
            planet.avatar = image
        }

        try planet.save()
        try planet.articles.forEach { try $0.save() }
        return planet
    }

    func update() async throws {
        Self.logger.info("Updating planet \(self.name)")
        await MainActor.run {
            isUpdating = true
        }
        defer {
            Task { @MainActor in
                isUpdating = false
            }
        }
        switch planetType {
        case .planet, .dnslink:
            let newCID = try await IPFSDaemon.shared.resolveIPNSorDNSLink(name: link)
            if cid == newCID {
                Self.logger.info("Planet \(self.name) has no update")
                return
            }
            Task {
                try await IPFSDaemon.shared.pin(cid: newCID)
            }
            do {
                let planetURL = URL(string: "\(IPFSDaemon.shared.gateway)/ipfs/\(newCID)/planet.json")!
                let (planetData, planetResponse) = try await URLSession.shared.data(from: planetURL)
                if let httpResponse = planetResponse as? HTTPURLResponse,
                   httpResponse.ok {
                    let publicPlanet = try JSONDecoder.shared.decode(PublicPlanetModel.self, from: planetData)
                    await MainActor.run {
                        name = publicPlanet.name
                        about = publicPlanet.about
                        updated = publicPlanet.updated
                    }

                    try await updateArticles(publicArticles: publicPlanet.articles, delete: true)

                    if let planetAvatarURL = URL(string: "\(IPFSDaemon.shared.gateway)/ipfs/\(newCID)/avatar.png"),
                       let (data, response) = try? await URLSession.shared.data(from: planetAvatarURL),
                       let httpResponse = response as? HTTPURLResponse,
                       httpResponse.ok,
                       let image = NSImage(data: data),
                       let _ = try? data.write(to: avatarPath) {
                        await MainActor.run {
                            avatar = image
                        }
                    }

                    await MainActor.run {
                        cid = newCID
                        lastRetrieved = Date()
                    }

                    try save()
                    return
                }
            } catch {
                // ignore
            }
            // did not get published planet file, try to get feed
            let feedURL = URL(string: "\(IPFSDaemon.shared.gateway)/ipfs/\(newCID)")!
            let (feedData, _) = try await FeedUtils.findFeed(url: feedURL)
            guard let feedData =  feedData else {
                throw PlanetError.InvalidPlanetURLError
            }
            let feed = try FeedUtils.parseFeed(data: feedData)
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

            if let data = feed.avatar,
               let image = NSImage(data: data),
               let _ = try? data.write(to: avatarPath) {
                await MainActor.run {
                    avatar = image
                }
            }

            try save()
            return
        case .ens:
            guard let newCID = try await ENSUtils.getCID(ens: link) else {
                throw PlanetError.InvalidPlanetURLError
            }
            if cid == newCID {
                Self.logger.info("Planet \(self.name) has no update")
                return
            }
            Task {
                try await IPFSDaemon.shared.pin(cid: newCID)
            }
            do {
                let planetURL = URL(string: "\(IPFSDaemon.shared.gateway)/ipfs/\(newCID)/planet.json")!
                let (planetData, planetResponse) = try await URLSession.shared.data(from: planetURL)
                if let httpResponse = planetResponse as? HTTPURLResponse,
                   httpResponse.ok {
                    let publicPlanet = try JSONDecoder.shared.decode(PublicPlanetModel.self, from: planetData)
                    await MainActor.run {
                        name = publicPlanet.name
                        about = publicPlanet.about
                        updated = publicPlanet.updated
                    }

                    try await updateArticles(publicArticles: publicPlanet.articles, delete: true)

                    if let data = try? await ENSUtils.shared.avatar(name: link),
                       let image = NSImage(data: data),
                       let _ = try? data.write(to: avatarPath) {
                        await MainActor.run {
                            avatar = image
                        }
                    } else
                    if let planetAvatarURL = URL(string: "\(IPFSDaemon.shared.gateway)/ipfs/\(newCID)/avatar.png"),
                       let (data, response) = try? await URLSession.shared.data(from: planetAvatarURL),
                       let httpResponse = response as? HTTPURLResponse,
                       httpResponse.ok,
                       let image = NSImage(data: data),
                       let _ = try? data.write(to: avatarPath) {
                        await MainActor.run {
                            avatar = image
                        }
                    }

                    await MainActor.run {
                        cid = newCID
                        lastRetrieved = Date()
                    }

                    try save()
                    return
                }
            } catch {
                // ignore
            }
            // did not get published planet file, try to get feed
            let feedURL = URL(string: "\(IPFSDaemon.shared.gateway)/ipfs/\(newCID)")!
            let (feedData, _) = try await FeedUtils.findFeed(url: feedURL)
            guard let feedData =  feedData else {
                throw PlanetError.InvalidPlanetURLError
            }
            let feed = try FeedUtils.parseFeed(data: feedData)
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

            if let data = try? await ENSUtils.shared.avatar(name: link),
               let image = NSImage(data: data),
               let _ = try? data.write(to: avatarPath) {
                await MainActor.run {
                    avatar = image
                }
            } else
            if let data = feed.avatar,
               let image = NSImage(data: data),
               let _ = try? data.write(to: avatarPath) {
                await MainActor.run {
                    avatar = image
                }
            }

            try save()
            return
        case .dns:
            guard let feedURL = URL(string: link) else {
                throw PlanetError.PlanetFeedError
            }
            let (feedData, _) = try await FeedUtils.findFeed(url: feedURL)
            guard let feedData = feedData else {
                throw PlanetError.PlanetFeedError
            }
            let feed = try FeedUtils.parseFeed(data: feedData)
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

            if let data = feed.avatar,
               let image = NSImage(data: data),
               let _ = try? data.write(to: avatarPath) {
                await MainActor.run {
                    avatar = image
                }
            }

            try save()
            return
        }
    }

    func updateArticles(publicArticles: [PublicArticleModel], delete: Bool = false) async throws {
        // planet file will have all the articles, so delete a planet article if it is no longer presented
        // feed will rollover old articles, so retain the article even if it is not in feed
        var existingArticleMap: [String: FollowingArticleModel] = [:]
        for existingArticle in articles {
            existingArticleMap[existingArticle.link] = existingArticle
        }

        var newArticles: [PublicArticleModel] = []
        for publicArticle in publicArticles {
            let link = publicArticle.link
            if let article = existingArticleMap[link] {
                // update
                await MainActor.run {
                    article.title = publicArticle.title
                    article.content = publicArticle.content
                }
                try article.save()
                existingArticleMap.removeValue(forKey: link)
            } else {
                // created
                newArticles.append(publicArticle)
                let articleModel = FollowingArticleModel.from(publicArticle: publicArticle, planet: self)
                try articleModel.save()
                await MainActor.run {
                    articles.append(articleModel)
                }
            }
        }
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
        sendNotification(for: newArticles)
    }

    func sendNotification(for newArticles: [PublicArticleModel]) {
        if newArticles.isEmpty {
            return
        }
        let content = UNMutableNotificationContent()
        content.title = name
        if newArticles.count == 1 {
            content.body = newArticles[0].title
        } else {
            content.body = "\(newArticles.count) new articles"
        }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.add(request) { error in
            if let error = error {
                Self.logger.warning("Cannot send user notifications for new articles: \(error.localizedDescription)")
            }
        }
    }

    func save() throws {
        try JSONEncoder.shared.encode(self).write(to: infoPath)
    }

    func delete() {
        try? FileManager.default.removeItem(at: basePath)
    }
}
