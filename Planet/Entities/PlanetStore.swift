import Foundation
import os

enum PlanetDetailViewType: Hashable, Equatable {
    case today
    case unread
    case starred
    case myPlanet(MyPlanetModel)
    case followingPlanet(FollowingPlanetModel)
}

@MainActor class PlanetStore: ObservableObject {
    static let shared = PlanetStore()
    static let version = 1
    static let repoVersionPath = URLUtils.repoPath.appendingPathComponent("Version")

    let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "PlanetStore")

    let indicatorTimer = Timer.publish(every: 1.25, tolerance: 0.25, on: .current, in: .default).autoconnect()

    @Published var myPlanets: [MyPlanetModel] = []
    @Published var followingPlanets: [FollowingPlanetModel] = []
    @Published var selectedView: PlanetDetailViewType? {
        didSet {
            if selectedView != oldValue {
                refreshSelectedArticles()
                selectedArticle = nil
            }
        }
    }
    @Published var selectedArticleList: [ArticleModel]? = nil
    @Published var selectedArticle: ArticleModel? {
        didSet {
            if let followingArticle = selectedArticle as? FollowingArticleModel {
                followingArticle.read = Date()
                try? followingArticle.save()
            }
        }
    }

    @Published var navigationTitle = "Planet"
    @Published var navigationSubtitle = ""

    @Published var isCreatingPlanet = false
    @Published var isEditingPlanet = false
    @Published var isFollowingPlanet = false
    @Published var isShowingPlanetInfo = false
    @Published var isImportingPlanet = false
    @Published var isMigrating = false
    @Published var isShowingAlert = false
    @Published var alertTitle: String = ""
    @Published var alertMessage: String = ""

    init() {
        do {
            try load()
        } catch {
            fatalError("Error when accessing planet repo: \(error)")
        }

        RunLoop.main.add(Timer(timeInterval: 600, repeats: true) { [self] timer in
            publishMyPlanets()
        }, forMode: .common)
        RunLoop.main.add(Timer(timeInterval: 300, repeats: true) { [self] timer in
            updateFollowingPlanets()
        }, forMode: .common)
    }

    func load() throws {
        logger.info("Loading from planet repo")
        let myPlanetDirectories = try FileManager.default.contentsOfDirectory(
            at: MyPlanetModel.myPlanetsPath,
            includingPropertiesForKeys: nil
        ).filter { $0.hasDirectoryPath }
        logger.info("Found \(myPlanetDirectories.count) my planets in repo")
        myPlanets = myPlanetDirectories.compactMap { try? MyPlanetModel.load(from: $0) }
        logger.info("Loaded \(self.myPlanets.count) my planets")

        let followingPlanetDirectories = try FileManager.default.contentsOfDirectory(
            at: FollowingPlanetModel.followingPlanetsPath,
            includingPropertiesForKeys: nil
        ).filter { $0.hasDirectoryPath }
        logger.info("Found \(followingPlanetDirectories.count) following planets in repo")
        followingPlanets = followingPlanetDirectories.compactMap { try? FollowingPlanetModel.load(from: $0) }
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
                    if i >= 4 {
                        await taskGroup.next()
                    }
                }
            }
            await MainActor.run {
                refreshSelectedArticles()
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
        case .unread:
            selectedArticleList = getUnreadArticles()
        case .starred:
            selectedArticleList = getStarredArticles()
        case .myPlanet(let planet):
            selectedArticleList = planet.articles
        case .followingPlanet(let planet):
            selectedArticleList = planet.articles
        case .none:
            selectedArticleList = nil
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
