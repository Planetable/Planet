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
    @Published var isEditingPlanetCustomCode = false
    @Published var isEditingPlanetPodcastSettings = false
    @Published var isFollowingPlanet = false
    @Published var followingPlanetLink: String = ""
    @Published var isShowingPlanetInfo = false
    @Published var isImportingPlanet = false
    @Published var isMigrating = false
    @Published var isShowingAlert = false
    @Published var alertTitle: String = ""
    @Published var alertMessage: String = ""

    init() {
        // Init UserDefaults
        if UserDefaults.standard.value(forKey: String.settingsPublicGatewayIndex) == nil {
            UserDefaults.standard.set(0, forKey: String.settingsPublicGatewayIndex)
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
            navigationSubtitle = "\(planet.articles.count) articles"
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
}
