import Foundation

enum PlanetDetailViewType: Hashable {
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

    @MainActor let indicatorTimer = Timer.publish(every: 1.25, tolerance: 0.25, on: .current, in: .default).autoconnect()

    @Published var myPlanets: [MyPlanetModel] = []
    @Published var followingPlanets: [FollowingPlanetModel] = []
    @Published var selectedView: PlanetDetailViewType? {
        didSet {
            selectedArticle = nil
        }
    }
    @Published var selectedArticle: ArticleModel? {
        didSet {
            if let followingArticle = selectedArticle as? FollowingArticleModel {
                followingArticle.read = Date()
                try? followingArticle.save()
            }
        }
    }

    @Published var isCreatingPlanet = false
    @Published var isEditingPlanet = false
    @Published var isFollowingPlanet = false
    @Published var isShowingPlanetInfo = false
    @Published var isImportingPlanet = false
    @Published var isExportingPlanet = false
    @Published var isShowingAlert = false
    @Published var isAlert = false
    @Published var alertTitle: String = ""
    @Published var alertMessage: String = ""

    init() {
        do {
            try load()
        } catch {
            fatalError("Error when accessing planet repo: \(error)")
        }
    }

    func load() throws {
        let myPlanetDirectories = try FileManager.default.contentsOfDirectory(
            at: MyPlanetModel.myPlanetsPath,
            includingPropertiesForKeys: nil
        ).filter { $0.hasDirectoryPath }
        myPlanets = myPlanetDirectories.compactMap { try? MyPlanetModel.load(from: $0) }

        let followingPlanetDirectories = try FileManager.default.contentsOfDirectory(
            at: FollowingPlanetModel.followingPlanetsPath,
            includingPropertiesForKeys: nil
        ).filter { $0.hasDirectoryPath }
        followingPlanets = followingPlanetDirectories.compactMap { try? FollowingPlanetModel.load(from: $0) }
    }

    func save() throws {
        try myPlanets.forEach { try $0.save() }
        try followingPlanets.forEach { try $0.save() }
    }

    func publishMyPlanets() {
        myPlanets.forEach { myPlanet in
            Task {
                try await myPlanet.publish()
            }
        }
    }

    func updateFollowingPlanets() {
        followingPlanets.forEach { followingPlanet in
            Task {
                try await followingPlanet.update()
                try followingPlanet.save()
            }
        }
    }

    func alert(title: String, message: String? = nil) {
        isAlert = true
        alertTitle = title
        alertMessage = message ?? ""
    }
}
