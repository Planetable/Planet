import Foundation
import os

enum PlanetAppShell: Int, Codable {
    case planet = 0
    case lite = 1
}

enum TaskProgressIndicatorType: Int, Codable {
    case none = 0
    case progress = 1
    case done = 2
}

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

    let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "PlanetStore")

    let indicatorTimer = Timer.publish(every: 1.25, tolerance: 0.25, on: .current, in: .default).autoconnect()

    @Published var myPlanets: [MyPlanetModel] = [] {
        didSet {
            let planets = myPlanets
            Task.detached {
                await MainActor.run {
                    ArticleWebViewModel.shared.updateMyPlanets(planets)
                    NotificationCenter.default.post(name: .keyManagerReloadUI, object: nil)
                }
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
                selectedArticle = nil
                refreshSelectedArticles()
                UserDefaults.standard.set(selectedView?.stringValue, forKey: "lastSelectedView")

                Task { @MainActor in
                    switch selectedView {
                    case .myPlanet(let planet):
                        KeyboardShortcutHelper.shared.activeMyPlanet = planet
                        // Update Planet Lite Window Titles
                        let liteSubtitle = "ipns://\(planet.ipns.shortIPNS())"
                        navigationSubtitle = liteSubtitle
                    default:
                        KeyboardShortcutHelper.shared.activeMyPlanet = nil
                        // Reset Planet Lite Window Titles
                        navigationSubtitle = ""
                    }
                }
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
                    Task.detached {
                        await PlanetStore.shared.updateTotalUnreadCount()
                        await PlanetStore.shared.updateTotalTodayCount()
                    }
                }
            }
        }
    }

    @Published var navigationTitle = "Planet"
    @Published var navigationSubtitle = ""

    @Published var isCreatingPlanet = false
    @Published var isEditingPlanet = false
    @Published var isConfiguringPlanetTemplate = false
    @Published var isConfiguringMint = false
    @Published var isConfiguringAggregation = false
    @Published var isShowingMyArticleSettings = false
    @Published var isEditingPlanetCustomCode = false
    @Published var isEditingPlanetPodcastSettings = false
    @Published var isShowingPlanetIPNS = false
    @Published var isFollowingPlanet = false
    @Published var followingPlanetLink: String = ""
    @Published var isShowingPlanetInfo = false
    @Published var isShowingPlanetAvatarPicker: Bool = false
    @Published var isMigrating = false
    @Published var isRebuilding = false
    @Published var rebuildTasks: Int = 0
    @Published var isQuickSharing = false  // use in macOS 12 only.
    @Published var isQuickPosting = false

    @Published var isAggregating: Bool = false  // at any time, only one aggregation task is allowed.
    @Published var currentTaskMessage: String = ""
    @Published var currentTaskProgressIndicator: TaskProgressIndicatorType = .none

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

    @Published var isShowingIconGallery: Bool = false

    @Published var isShowingPlanetPicker: Bool = false
    var importingArticleURLs: [URL] = []

    @Published var isShowingSearch: Bool = false
    @Published var searchText: String = UserDefaults.standard.string(forKey: "searchText") ?? "" {
        didSet {
            UserDefaults.standard.set(searchText, forKey: "searchText")
        }
    }

    @Published var isShowingIPFSOpen: Bool = false

    @Published var isShowingOnboarding = false

    @Published var isShowingAlert = false
    @Published var alertTitle: String = ""
    @Published var alertMessage: String = ""

    @Published var totalTodayCount: Int = 0
    @Published var totalUnreadCount: Int = 0
    @Published var totalStarredCount: Int = 0

    nonisolated static let app: PlanetAppShell = (Bundle.main.executableURL?.lastPathComponent == "Croptop") ? .lite : .planet

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

        if PlanetStore.app == .lite {
            navigationTitle = "Croptop"
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

        // Publish my planets every 10 minutes
        RunLoop.main.add(Timer(timeInterval: 600, repeats: true) { [self] timer in
            publishMyPlanets()
        }, forMode: .common)
        // Check content update every 5 minutes
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
            at: MyPlanetModel.myPlanetsPath(),
            includingPropertiesForKeys: nil
        ).filter { $0.hasDirectoryPath }
        logger.info("Found \(myPlanetDirectories.count) my planets in repo")
        var myAllPlanets: [MyPlanetModel] = myPlanetDirectories.compactMap { try? MyPlanetModel.load(from: $0) }
        logger.info("Loaded \(self.myPlanets.count) my planets")
        let myPlanetPartition = myAllPlanets.partition(by: { $0.archived == false || $0.archived == nil })
        myArchivedPlanets = Array(myAllPlanets[..<myPlanetPartition])
        myPlanets = Array(myAllPlanets[myPlanetPartition...])
        loadMyPlanetsOrder()

        let followingPlanetDirectories = try FileManager.default.contentsOfDirectory(
            at: FollowingPlanetModel.followingPlanetsPath(),
            includingPropertiesForKeys: nil
        ).filter { $0.hasDirectoryPath }
        logger.info("Found \(followingPlanetDirectories.count) following planets in repo")
        var followingAllPlanets = followingPlanetDirectories.compactMap { try? FollowingPlanetModel.load(from: $0) }
        let followingPlanetPartition = followingAllPlanets.partition(by: { $0.archived == false || $0.archived == nil })
        followingArchivedPlanets = Array(followingAllPlanets[..<followingPlanetPartition])
        followingPlanets = Array(followingAllPlanets[followingPlanetPartition...])
        loadFollowingPlanetsOrder()
        logger.info("Loaded \(self.followingPlanets.count) following planets")
        updateTotalUnreadCount()
        updateTotalStarredCount()
        updateTotalTodayCount()
    }

    func publishMyPlanets() {
        Task {
            await withTaskGroup(of: Void.self) { taskGroup in
                for (i, myPlanet) in myPlanets.enumerated() {
                    taskGroup.addTask {
                        try? await myPlanet.publish()
                    }
                    if i >= 2 {
                        await taskGroup.next()
                    }
                }
            }
        }
    }

    func updateTotalTodayCount() {
        let b = followingPlanets.reduce(0) { $0 + $1.articles.filter { $0.read == nil && $0.created.timeIntervalSinceNow > -86400 }.count }
        totalTodayCount = b
    }

    func updateTotalUnreadCount() {
        totalUnreadCount = followingPlanets.reduce(0) { $0 + $1.articles.filter { $0.read == nil }.count }
    }

    func updateTotalStarredCount() {
        let a = myPlanets.reduce(0) { $0 + $1.articles.filter { $0.starred != nil }.count }
        let b = followingPlanets.reduce(0) { $0 + $1.articles.filter { $0.starred != nil }.count }
        totalStarredCount = a + b
    }

    private let myPlanetsOrderKey = "myPlanetsOrder"

    func moveMyPlanets(fromOffsets source: IndexSet, toOffset destination: Int) {
        myPlanets.move(fromOffsets: source, toOffset: destination)
        Task {
            await saveMyPlanetsOrder()
        }
    }

    func saveMyPlanetsOrder() async {
        let ids = myPlanets.map { $0.id.uuidString }
        UserDefaults.standard.set(ids, forKey: myPlanetsOrderKey)
    }

    func loadMyPlanetsOrder() {
        guard let storedIds = UserDefaults.standard.array(forKey: myPlanetsOrderKey) as? [String] else {
            return
        }

        let uuids = storedIds.compactMap { UUID(uuidString: $0) }
        myPlanets.sort {
            guard let index1 = uuids.firstIndex(of: $0.id), let index2 = uuids.firstIndex(of: $1.id) else {
                return false
            }
            return index1 < index2
        }
    }

    private let followingPlanetsOrderKey = "followingPlanetsOrder"

    func moveFollowingPlanets(fromOffsets source: IndexSet, toOffset destination: Int) {
        followingPlanets.move(fromOffsets: source, toOffset: destination)
        Task {
            await saveFollowingPlanetsOrder()
        }
    }

    func saveFollowingPlanetsOrder() async {
        let ids = followingPlanets.map { $0.id.uuidString }
        UserDefaults.standard.set(ids, forKey: followingPlanetsOrderKey)
    }

    func loadFollowingPlanetsOrder() {
        guard let storedIds = UserDefaults.standard.array(forKey: followingPlanetsOrderKey) as? [String] else {
            return
        }

        let uuids = storedIds.compactMap { UUID(uuidString: $0) }
        followingPlanets.sort {
            guard let index1 = uuids.firstIndex(of: $0.id), let index2 = uuids.firstIndex(of: $1.id) else {
                return false
            }
            return index1 < index2
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
            navigationTitle = PlanetStore.app == .lite ? "Croptop" : "Planet"
            navigationSubtitle = ""
        }
        if let articles = selectedArticleList {
            ArticleListViewModel.shared.articles = articles
        } else {
            ArticleListViewModel.shared.articles = []
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
            followingPlanet.articles.filter {
                if ($0.read == nil) {
                    return true
                } else {
                    return false
                }
            }
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
        article.delete()

        let movedArticle = article
        movedArticle.planet = toPlanet

        movedArticle.path = URL(string: article.path.absoluteString.replacingOccurrences(of: fromPlanetIDString, with: toPlanetIDString))!
        movedArticle.publicBasePath = URL(string: article.publicBasePath.absoluteString.replacingOccurrences(of: fromPlanetIDString, with: toPlanetIDString))!
        movedArticle.publicIndexPath = URL(string: article.publicIndexPath.absoluteString.replacingOccurrences(of: fromPlanetIDString, with: toPlanetIDString))!
        movedArticle.publicInfoPath = URL(string: article.publicInfoPath.absoluteString.replacingOccurrences(of: fromPlanetIDString, with: toPlanetIDString))!
        movedArticle.publicNFTMetadataPath = URL(string: article.publicNFTMetadataPath.absoluteString.replacingOccurrences(of: fromPlanetIDString, with: toPlanetIDString))!

        toPlanet.articles.append(movedArticle)
        toPlanet.articles = toPlanet.articles.sorted(by: { $0.created > $1.created })

        // debugPrint("copy templates assets for target planet")
        // try toPlanet.copyTemplateAssets()

        debugPrint("update target planet update date")
        toPlanet.updated = Date()

        debugPrint("target planet save")
        try toPlanet.save()

        debugPrint("target planet save public")
        try await toPlanet.savePublic()

        debugPrint("update from planet update date")
        fromPlanet.updated = Date()

        debugPrint("from planet save")
        try fromPlanet.save()

        debugPrint("from planet save public")
        try await fromPlanet.savePublic()

        debugPrint("refresh planet store")
        let refreshedFromPlanet = try MyPlanetModel.load(from: fromPlanet.basePath)
        let refreshedToPlanet = try MyPlanetModel.load(from: toPlanet.basePath)

        // debugPrint("copy templates assets for final planet")
        // try refreshedToPlanet.copyTemplateAssets()

        // debugPrint("final planet articles save public.")
        // try refreshedToPlanet.articles.forEach({ try $0.savePublic() })

        let refreshedArticle = try MyArticleModel.load(from: movedArticle.path, planet: refreshedToPlanet)
        try refreshedArticle.savePublic()

        myPlanets = myPlanets.map() { p in
            if p.id == refreshedFromPlanet.id {
                return refreshedFromPlanet
            } else if p.id == refreshedToPlanet.id {
                return refreshedToPlanet
            }
            return p
        }

        debugPrint("refresh UI")
        selectedArticle = nil
        selectedView = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.selectedView = .myPlanet(refreshedToPlanet)
            let movedArticleID = movedArticle.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                if let myArticle = self?.selectedArticleList?.first{ $0.id == movedArticleID } as? MyArticleModel {
                    if let refreshed = try? MyArticleModel.load(from: myArticle.path, planet: refreshedToPlanet) {
                        self?.selectedArticle = refreshed
                    }
                }
            }
        }

        debugPrint("publish changes ...")
        Task {
            try await refreshedToPlanet.publish()
        }
        Task {
            try await refreshedFromPlanet.publish()
        }
    }
}
