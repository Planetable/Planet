import Foundation
import os

enum PlanetDetailViewType: Hashable, Equatable {
    case today
    case unread
    case starred
    case myPlanet(MyPlanetModel)
    case followingPlanet(FollowingPlanetModel)

    var stringValue: String {
        switch self {
        case .today:
            return "today"
        case .unread:
            return "unread"
        case .starred:
            return "starred"
        case .myPlanet(let planet):
            return "myPlanet:\(planet.id.uuidString)"
        case .followingPlanet(let planet):
            return "followingPlanet:\(planet.id.uuidString)"
        }
    }
}

@MainActor class PlanetStore: ObservableObject {
    static let shared = PlanetStore()
    static let version = 1
    static let repoVersionPath = URLUtils.repoPath.appendingPathComponent("Version")

    let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "PlanetStore")

    let indicatorTimer = Timer.publish(every: 1.25, tolerance: 0.25, on: .current, in: .default).autoconnect()

    @Published var myPlanets: [MyPlanetModel] = [] {
        didSet {
            Task { @MainActor in
                ArticleWebViewModel.shared.updateMyPlanets(myPlanets)
            }
            let planets = myPlanets
            Task(priority: .utility) {
                PlanetAPI.shared.updateMyPlanets(planets)
            }
        }
    }

    @Published var followingPlanets: [FollowingPlanetModel] = [] {
        didSet {
            Task { @MainActor in
                ArticleWebViewModel.shared.updateFollowingPlanets(followingPlanets)
            }
        }
    }

    @Published var myArchivedPlanets: [MyPlanetModel] = []

    @Published var followingArchivedPlanets: [FollowingPlanetModel] = []

    @Published var selectedView: PlanetDetailViewType? {
        didSet {
            if selectedView != oldValue {
                refreshSelectedArticles()
                selectedArticle = nil
                UserDefaults.standard.set(selectedView?.stringValue, forKey: "lastSelectedView")
            }
        }
    }
    @Published var selectedArticleList: [ArticleModel]? = nil
    @Published var selectedArticle: ArticleModel? {
        didSet {
            if selectedArticle != oldValue {
                if let followingArticle = selectedArticle as? FollowingArticleModel {
                    followingArticle.read = Date()
                    try? followingArticle.save()
                }
            }
        }
    }

    @Published var navigationTitle = "Planet"
    @Published var navigationSubtitle = ""

    @Published var isCreatingPlanet = false
    @Published var isEditingPlanet = false
    @Published var isShowingMyArticleSettings = false
    @Published var isEditingPlanetCustomCode = false
    @Published var isEditingPlanetPodcastSettings = false
    @Published var isShowingPlanetIPNS = false
    @Published var isFollowingPlanet = false
    @Published var followingPlanetLink: String = ""
    @Published var isShowingPlanetInfo = false
    @Published var isImportingPlanet = false
    @Published var isMigrating = false

    @Published var isShowingWalletConnectV1QRCode: Bool = false
    @Published var isShowingWalletAccount: Bool = false

    @Published var isShowingWalletTipAmount: Bool = false
    @Published var isShowingWalletTransactionProgress: Bool = false
    @Published var walletTransactionProgressMessage: String = ""
    @Published var walletTransactionMemo: String = ""

    @Published var walletConnectV1ConnectionURL: String = ""
    @Published var walletAddress: String = ""

    @Published var isShowingWalletDisconnectConfirmation: Bool = false

    @Published var walletConnectV2Ready: Bool = false
    @Published var walletConnectV2ConnectionURL: String = ""
    @Published var isShowingWalletConnectV2QRCode: Bool = false

    @Published var isShowingOnboarding = false

    @Published var isShowingAlert = false
    @Published var alertTitle: String = ""
    @Published var alertMessage: String = ""

    init() {
        // Init UserDefaults
        if UserDefaults.standard.value(forKey: String.settingsPublicGatewayIndex) == nil {
            UserDefaults.standard.set(0, forKey: String.settingsPublicGatewayIndex)
        }
        if UserDefaults.standard.value(forKey: String.settingsEthereumChainId) == nil {
            UserDefaults.standard.set(1, forKey: String.settingsEthereumChainId)
        }
        if UserDefaults.standard.value(forKey: String.settingsEthereumTipAmount) == nil {
            UserDefaults.standard.set(2, forKey: String.settingsEthereumTipAmount)
        }

        do {
            try load()
        } catch {
            fatalError("Error when accessing planet repo: \(error)")
        }

        if let lastSelectedView = UserDefaults.standard.string(forKey: "lastSelectedView") {
            if lastSelectedView.hasPrefix("myPlanet:") {
                let planetId = UUID(uuidString: String(lastSelectedView.dropFirst("myPlanet:".count)))
                if let planet = myPlanets.first(where: { $0.id == planetId }) {
                    selectedView = .myPlanet(planet)
                }
            } else if lastSelectedView.hasPrefix("followingPlanet:") {
                let planetId = UUID(uuidString: String(lastSelectedView.dropFirst("followingPlanet:".count)))
                if let planet = followingPlanets.first(where: { $0.id == planetId }) {
                    selectedView = .followingPlanet(planet)
                }
            } else if lastSelectedView == "today" {
                selectedView = .today
            } else if lastSelectedView == "unread" {
                selectedView = .unread
            } else if lastSelectedView == "starred" {
                selectedView = .starred
            }
        }
        // Publish my planets every 30 minutes
        RunLoop.main.add(Timer(timeInterval: 1800, repeats: true) { [self] timer in
            publishMyPlanets()
        }, forMode: .common)
        // Check content update every 15 minutes
        RunLoop.main.add(Timer(timeInterval: 300, repeats: true) { [self] timer in
            updateFollowingPlanets()
        }, forMode: .common)
        // Get the latest analytics data every minute
        RunLoop.main.add(Timer(timeInterval: 60, repeats: true) { [self] timer in
            updateMyPlanetsTrafficAnalytics()
        }, forMode: .common)
    }

    func load() throws {
        logger.info("Loading from planet repo")
        let myPlanetDirectories = try FileManager.default.contentsOfDirectory(
            at: MyPlanetModel.myPlanetsPath,
            includingPropertiesForKeys: nil
        ).filter { $0.hasDirectoryPath }
        logger.info("Found \(myPlanetDirectories.count) my planets in repo")
        var myAllPlanets: [MyPlanetModel] = myPlanetDirectories.compactMap { try? MyPlanetModel.load(from: $0) }
        logger.info("Loaded \(self.myPlanets.count) my planets")
        let myPlanetPartition = myAllPlanets.partition(by: { $0.archived == false || $0.archived == nil })
        myArchivedPlanets = Array(myAllPlanets[..<myPlanetPartition])
        myPlanets = Array(myAllPlanets[myPlanetPartition...])

        let followingPlanetDirectories = try FileManager.default.contentsOfDirectory(
            at: FollowingPlanetModel.followingPlanetsPath,
            includingPropertiesForKeys: nil
        ).filter { $0.hasDirectoryPath }
        logger.info("Found \(followingPlanetDirectories.count) following planets in repo")
        var followingAllPlanets = followingPlanetDirectories.compactMap { try? FollowingPlanetModel.load(from: $0) }
        let followingPlanetPartition = followingAllPlanets.partition(by: { $0.archived == false || $0.archived == nil })
        followingArchivedPlanets = Array(followingAllPlanets[..<followingPlanetPartition])
        followingPlanets = Array(followingAllPlanets[followingPlanetPartition...])
        logger.info("Loaded \(self.followingPlanets.count) following planets")
    }

    func publishMyPlanets() {
        Task {
            await withTaskGroup(of: Void.self) { taskGroup in
                for (i, myPlanet) in myPlanets.enumerated() {
                    taskGroup.addTask {
                        try? await myPlanet.publish()
                    }
                    if i >= 4 {
                        await taskGroup.next()
                    }
                }
            }
        }
    }

    func updateFollowingPlanets() {
        Task {
            await withTaskGroup(of: Void.self) { taskGroup in
                for (i, followingPlanet) in followingPlanets.enumerated() {
                    taskGroup.addTask {
                        try? await followingPlanet.update()
                    }
                    if i >= 3 {
                        await taskGroup.next()
                    }
                }
            }
            await MainActor.run {
                refreshSelectedArticles()
            }
        }
    }

    func updateMyPlanetsTrafficAnalytics() {
        Task {
            await withTaskGroup(of: Void.self) { taskGroup in
                for myPlanet in myPlanets {
                    taskGroup.addTask {
                        await myPlanet.updateTrafficAnalytics()
                    }
                }
            }
        }
    }

    func alert(title: String, message: String? = nil) {
        isShowingAlert = true
        alertTitle = title
        alertMessage = message ?? ""
    }

    func refreshSelectedArticles() {
        switch selectedView {
        case .today:
            selectedArticleList = getTodayArticles()
            navigationTitle = "Today"
            if let articles = selectedArticleList {
                navigationSubtitle = "\(articles.count) fetched today"
            }
        case .unread:
            selectedArticleList = getUnreadArticles()
            navigationTitle = "Unread"
            if let articles = selectedArticleList {
                navigationSubtitle = "\(articles.count) unread"
            }
        case .starred:
            selectedArticleList = getStarredArticles()
            navigationTitle = "Starred"
            if let articles = selectedArticleList {
                navigationSubtitle = "\(articles.count) starred"
            }
        case .myPlanet(let planet):
            selectedArticleList = planet.articles
            navigationTitle = planet.name
            navigationSubtitle = planet.navigationSubtitle()
        case .followingPlanet(let planet):
            selectedArticleList = planet.articles
            navigationTitle = planet.name
            navigationSubtitle = planet.navigationSubtitle()
        case .none:
            selectedArticleList = nil
            navigationTitle = "Planet"
            navigationSubtitle = ""
        }
    }

    func getTodayArticles() -> [ArticleModel] {
        var articles: [ArticleModel] = []
        articles.append(contentsOf: followingPlanets.flatMap { myPlanet in
            myPlanet.articles.filter { $0.created.timeIntervalSinceNow > -86400 }
        })
        articles.append(contentsOf: myPlanets.flatMap { followingPlanet in
            followingPlanet.articles.filter { $0.created.timeIntervalSinceNow > -86400 }
        })
        articles.sort { $0.created > $1.created }
        return articles
    }

    func getUnreadArticles() -> [ArticleModel] {
        var articles = followingPlanets.flatMap { followingPlanet in
            followingPlanet.articles.filter { $0.read == nil }
        }
        articles.sort { $0.created > $1.created }
        return articles
    }

    func getStarredArticles() -> [ArticleModel] {
        var articles: [ArticleModel] = []
        articles.append(contentsOf: followingPlanets.flatMap { myPlanet in
            myPlanet.articles.filter { $0.starred != nil }
        })
        articles.append(contentsOf: myPlanets.flatMap { followingPlanet in
            followingPlanet.articles.filter { $0.starred != nil }
        })
        articles.sort { $0.starred! > $1.starred! }
        return articles
    }

    func moveMyArticle(_ article: MyArticleModel, toPlanet: MyPlanetModel) async throws {
        guard let fromPlanet = article.planet else {
            throw PlanetError.InternalError
        }
        guard fromPlanet.isPublishing == false, toPlanet.isPublishing == false else {
            throw PlanetError.MovePublishingPlanetArticleError
        }
        debugPrint("moving article: \(article), from planet: \(fromPlanet), to planet: \(toPlanet)")
        fromPlanet.articles = fromPlanet.articles.filter({ a in
            return a.id != article.id
        })
        let articleIDString: String = article.id.uuidString.uppercased()
        let fromPlanetIDString: String = fromPlanet.id.uuidString.uppercased()
        let toPlanetIDString: String = toPlanet.id.uuidString.uppercased()
        let fromArticlePath = article.path
        let targetArticlePath = fromArticlePath.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(toPlanetIDString).appendingPathComponent("Articles").appendingPathComponent("\(articleIDString).json")
        debugPrint("moving article from: \(fromArticlePath), to: \(targetArticlePath) ...")
        try FileManager.default.copyItem(at: fromArticlePath, to: targetArticlePath)

        let fromArticlePublicPath = article.publicBasePath
        let targetArticlePublicPath = fromArticlePublicPath.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(toPlanet.id.uuidString.uppercased()).appendingPathComponent(article.id.uuidString.uppercased())
        debugPrint("moving public article from: \(fromArticlePublicPath), to: \(targetArticlePublicPath) ...")
        try FileManager.default.copyItem(at: fromArticlePublicPath, to: targetArticlePublicPath)

        debugPrint("delete previous article")
        try article.delete()

        let movedArticle = article
        movedArticle.planet = toPlanet
        movedArticle.path = URL(string: article.path.absoluteString.replacingOccurrences(of: fromPlanetIDString, with: toPlanetIDString))!
        movedArticle.publicBasePath = URL(string: article.path.absoluteString.replacingOccurrences(of: fromPlanetIDString, with: toPlanetIDString))!
        movedArticle.publicIndexPath = URL(string: article.path.absoluteString.replacingOccurrences(of: fromPlanetIDString, with: toPlanetIDString))!
        movedArticle.publicInfoPath = URL(string: article.path.absoluteString.replacingOccurrences(of: fromPlanetIDString, with: toPlanetIDString))!
        toPlanet.articles.append(movedArticle)
        toPlanet.articles = toPlanet.articles.sorted(by: { $0.created > $1.created })

        debugPrint("copy templates assets for target planet")
        try toPlanet.copyTemplateAssets()

        debugPrint("update target planet update date")
        toPlanet.updated = Date()

        debugPrint("target planet save")
        try toPlanet.save()

        debugPrint("target planet save public")
        try toPlanet.savePublic()

        debugPrint("update from planet update date")
        fromPlanet.updated = Date()

        debugPrint("from planet save")
        try fromPlanet.save()

        debugPrint("from planet save public")
        try fromPlanet.savePublic()

        debugPrint("refresh planet store")
        let finalPlanet = try MyPlanetModel.load(from: toPlanet.basePath)

        debugPrint("copy templates assets for final planet")
        try finalPlanet.copyTemplateAssets()

        debugPrint("final planet articles save public.")
        try finalPlanet.articles.forEach({ try $0.savePublic() })

        myPlanets = myPlanets.map() { p in
            if p.id == fromPlanet.id {
                return fromPlanet
            } else if p.id == finalPlanet.id {
                return finalPlanet
            }
            return p
        }

        debugPrint("refresh UI")

        // TODO: Make this part cleaner
        selectedArticle = nil
        selectedView = nil
        selectedArticleList = nil
        refreshSelectedArticles()

        debugPrint("publish changes ...")
        Task {
            try await finalPlanet.publish()
        }
        Task {
            try await fromPlanet.publish()
        }
    }
}
