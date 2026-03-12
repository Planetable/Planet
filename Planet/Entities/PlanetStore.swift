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

    static func == (lhs: PlanetDetailViewType, rhs: PlanetDetailViewType) -> Bool {
        switch (lhs, rhs) {
        case (.today, .today), (.unread, .unread), (.starred, .starred):
            return true
        case (.myPlanet(let lhsPlanet), .myPlanet(let rhsPlanet)):
            return lhsPlanet.id == rhsPlanet.id
        case (.followingPlanet(let lhsPlanet), .followingPlanet(let rhsPlanet)):
            return lhsPlanet.id == rhsPlanet.id
        default:
            return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .today:
            hasher.combine(0)
        case .unread:
            hasher.combine(1)
        case .starred:
            hasher.combine(2)
        case .myPlanet(let planet):
            hasher.combine(3)
            hasher.combine(planet.id)
        case .followingPlanet(let planet):
            hasher.combine(4)
            hasher.combine(planet.id)
        }
    }
}

final class MyJSONDirectoryMonitor {
    private var stream: FSEventStreamRef?
    private let callback: FSEventStreamCallback = { (_, contextInfo, numEvents, eventPaths, _, _) in
        guard let contextInfo else { return }
        let monitor = Unmanaged<MyJSONDirectoryMonitor>.fromOpaque(contextInfo).takeUnretainedValue()
        let pathsArray = unsafeBitCast(eventPaths, to: NSArray.self)
        var changedPaths: [String] = []
        for idx in 0..<Int(numEvents) {
            if let path = pathsArray[idx] as? String {
                changedPaths.append(path)
            }
        }
        monitor.changed(changedPaths)
    }
    private let directory: String
    private let changed: ([String]) -> Void

    init(directory: String, changed: @escaping ([String]) -> Void) {
        self.directory = directory
        self.changed = changed
    }

    deinit {
        stop()
    }

    func start() {
        stop()
        let pathsToWatch: CFArray = [directory] as CFArray
        var context = FSEventStreamContext(
            version: 0,
            info: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagIgnoreSelf)
        )
        guard let stream else { return }
        FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        FSEventStreamStart(stream)
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }
}

@MainActor class PlanetStore: ObservableObject {
    static let shared = PlanetStore()
    static let version = 1
    nonisolated(unsafe) static var isSharedReady = false

    let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "PlanetStore")
    private var myDataMonitor: MyJSONDirectoryMonitor?
    private var myDataReloadTask: Task<Void, Never>?
    private var myDataReloadInProgress = false
    private var selectedViewRefreshTask: Task<Void, Never>?
    private var pendingArticleRestoreID: UUID?
    private var pendingSidebarScroll = false
    var searchSnapshotRebuildTask: Task<Void, Never>?
    var cachedSearchSnapshots: [SearchArticleSnapshot] = []

    @Published var myPlanets: [MyPlanetModel] = [] {
        didSet {
            rebuildSearchSnapshots()
            updateTotalStarredCount()
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
            rebuildSearchSnapshots()
            updateTotalUnreadCount()
            updateTotalTodayCount()
            updateTotalStarredCount()
            Task { @MainActor in
                ArticleWebViewModel.shared.updateFollowingPlanets(followingPlanets)
            }
        }
    }

    @Published var myArchivedPlanets: [MyPlanetModel] = []

    @Published var followingArchivedPlanets: [FollowingPlanetModel] = []

    @Published var selectedView: PlanetDetailViewType? {
        didSet {
            let canonicalView = canonicalSelectedView(selectedView)
            if selectedView != canonicalView {
                selectedView = canonicalView
                return
            }
            if selectedView != oldValue {
                let selectedViewSnapshot = selectedView
                selectedViewRefreshTask?.cancel()
                selectedViewRefreshTask = Task { @MainActor in
                    // Defer publishes to the next main-actor turn to avoid SwiftUI re-entrancy warnings.
                    await Task.yield()
                    guard !Task.isCancelled, self.selectedView == selectedViewSnapshot else {
                        return
                    }
                    self.refreshSelectedArticles()

                    switch self.selectedView {
                    case .myPlanet(let planet):
                        let canonicalPlanet = self.myPlanets.first(where: { $0.id == planet.id }) ?? planet
                        KeyboardShortcutHelper.shared.activeMyPlanet = canonicalPlanet
                        // Update Planet Lite Window Titles
                        // let liteSubtitle = "ipns://\(planet.ipns.shortIPNS())"
                        // navigationSubtitle = liteSubtitle
                    default:
                        KeyboardShortcutHelper.shared.activeMyPlanet = nil
                        // Reset Planet Lite Window Titles
                        self.navigationSubtitle = ""
                    }
                }
                UserDefaults.standard.set(selectedView?.stringValue, forKey: "lastSelectedView")
            }
        }
    }

    private func canonicalSelectedView(_ view: PlanetDetailViewType?) -> PlanetDetailViewType? {
        switch view {
        case .myPlanet(let planet):
            if let canonicalPlanet = myPlanets.first(where: { $0.id == planet.id }) {
                return .myPlanet(canonicalPlanet)
            }
            return nil
        case .followingPlanet(let planet):
            if let canonicalPlanet = followingPlanets.first(where: { $0.id == planet.id }) {
                return .followingPlanet(canonicalPlanet)
            }
            return nil
        case .today:
            return .today
        case .unread:
            return .unread
        case .starred:
            return .starred
        case .none:
            return nil
        }
    }
    @Published var selectedArticleList: [ArticleModel]? = nil
    @Published var selectedArticle: ArticleModel? {
        didSet {
            if selectedArticle != oldValue {
                if let followingArticle = selectedArticle as? FollowingArticleModel {
                    Task { @MainActor in
                        followingArticle.read = Date()
                        try? followingArticle.save()
                    }
                    Task.detached { @MainActor in
                        PlanetStore.shared.updateTotalUnreadCount()
                        PlanetStore.shared.updateTotalTodayCount()
                    }
                }
                UserDefaults.standard.set(selectedArticle?.id.uuidString, forKey: "lastSelectedArticle")
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

    @Published var isShowingDeleteMyArticleConfirmation = false
    @Published var deletingMyArticle: MyArticleModel?

    @Published var isEditingPlanetCustomCode = false
    @Published var isEditingPlanetDonationSettings = false
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

    @Published var isShowingIPFSOpen: Bool = false

    @Published var isShowingOnboarding = false
    @Published var isShowingNewOnboarding = false

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

        // Read from user defaults for "showOnboardingScreen"
        if let showOnboardingScreen = UserDefaults.standard.value(forKey: "showOnboardingScreen") as? Bool {
            isShowingNewOnboarding = showOnboardingScreen
        } else {
            isShowingNewOnboarding = true
        }

        do {
            try load()
        } catch {
            fatalError("Error when accessing planet repo: \(error)")
        }
        rebuildSearchSnapshots()

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
        if let lastSelectedArticleIDString = UserDefaults.standard.string(forKey: "lastSelectedArticle"),
           let lastSelectedArticleID = UUID(uuidString: lastSelectedArticleIDString) {
            pendingArticleRestoreID = lastSelectedArticleID
        }
        if selectedView != nil {
            pendingSidebarScroll = true
        }

        Self.isSharedReady = true

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
        if myDataMonitor == nil {
            refreshMyDataMonitor()
        }
    }

    private enum SelectedViewSnapshot {
        case none
        case today
        case unread
        case starred
        case myPlanet(UUID)
        case followingPlanet(UUID)
    }

    private struct MyArticleSelectionTarget {
        let planetID: UUID
        let articleID: UUID
    }

    private func refreshMyDataMonitor() {
        myDataMonitor?.stop()
        myDataMonitor = MyJSONDirectoryMonitor(directory: MyPlanetModel.myPlanetsPath().path) { [weak self] paths in
            Task { @MainActor in
                self?.handleExternalMyJSONPathChanges(paths)
            }
        }
        myDataMonitor?.start()
    }

    private func handleExternalMyJSONPathChanges(_ changedPaths: [String]) {
        let jsonPaths = changedPaths.filter { $0.hasSuffix(".json") }
        guard !jsonPaths.isEmpty else { return }
        let selectedMyArticle = jsonPaths.compactMap(parseMyArticleSelectionTarget(fromPath:)).first
        myDataReloadTask?.cancel()
        myDataReloadTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 250_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            logger.info("Detected my data json changes, reloading store")
            reloadAfterExternalMyDataChange(selectMyArticle: selectedMyArticle)
        }
    }

    private func reloadAfterExternalMyDataChange(selectMyArticle target: MyArticleSelectionTarget?) {
        guard !myDataReloadInProgress else { return }
        myDataReloadInProgress = true
        defer { myDataReloadInProgress = false }

        let selectedViewSnapshot = snapshotSelectedView()
        let selectedArticleID = selectedArticle?.id

        // Only navigate to the changed article when the user is already viewing that planet,
        // to avoid disrupting reading of an unrelated planet.
        let isViewingTargetPlanet: Bool
        if case .myPlanet(let id) = selectedViewSnapshot, let target, target.planetID == id {
            isViewingTargetPlanet = true
        } else {
            isViewingTargetPlanet = false
        }

        do {
            try load()
            if let target,
                let article = myPlanets.first(where: { $0.id == target.planetID })?.articles.first(where: { $0.id == target.articleID })
            {
                Task.detached {
                    try? article.savePublic()
                    await MainActor.run {
                        NotificationCenter.default.post(name: .loadArticle, object: nil)
                    }
                }
            }
            selectedArticleList = nil
            ArticleListViewModel.shared.articles = []
            restoreSelection(from: selectedViewSnapshot)
            refreshSelectedArticles()
            if isViewingTargetPlanet, let target,
                let planet = myPlanets.first(where: { $0.id == target.planetID })
            {
                // Force detail-view refresh for the changed article.
                selectedArticle = nil
                selectedArticle = planet.articles.first(where: { $0.id == target.articleID })
            } else {
                // Force detail-view refresh for the previously-selected article.
                selectedArticle = nil
                if let selectedArticleID {
                    selectedArticle = selectedArticleList?.first(where: { $0.id == selectedArticleID })
                }
            }
        } catch {
            logger.error("Failed to reload after external my data change: \(error.localizedDescription)")
        }
    }

    private func snapshotSelectedView() -> SelectedViewSnapshot {
        switch selectedView {
        case .today:
            return .today
        case .unread:
            return .unread
        case .starred:
            return .starred
        case .myPlanet(let planet):
            return .myPlanet(planet.id)
        case .followingPlanet(let planet):
            return .followingPlanet(planet.id)
        case .none:
            return .none
        }
    }

    private func restoreSelection(from snapshot: SelectedViewSnapshot) {
        switch snapshot {
        case .today:
            selectedView = .today
        case .unread:
            selectedView = .unread
        case .starred:
            selectedView = .starred
        case .myPlanet(let id):
            if let planet = myPlanets.first(where: { $0.id == id }) {
                selectedView = .myPlanet(planet)
            } else {
                selectedView = nil
            }
        case .followingPlanet(let id):
            if let planet = followingPlanets.first(where: { $0.id == id }) {
                selectedView = .followingPlanet(planet)
            } else {
                selectedView = nil
            }
        case .none:
            selectedView = nil
        }
    }

    private func parseMyArticleSelectionTarget(fromPath path: String) -> MyArticleSelectionTarget? {
        let url = URL(fileURLWithPath: path)
        let components = url.pathComponents
        guard let myIndex = components.lastIndex(of: "My"),
            components.count > myIndex + 3
        else {
            return nil
        }
        let planetIDString = components[myIndex + 1]
        let articlesComponent = components[myIndex + 2]
        let articleFilename = components[myIndex + 3]
        guard articlesComponent == "Articles",
            articleFilename.lowercased().hasSuffix(".json"),
            let planetID = UUID(uuidString: planetIDString),
            let articleID = UUID(uuidString: String(articleFilename.dropLast(5)))
        else {
            return nil
        }
        return MyArticleSelectionTarget(planetID: planetID, articleID: articleID)
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

    func refreshMyPlanetsIPNSKeepAlive() {
        Task {
            await withTaskGroup(of: Void.self) { taskGroup in
                for (i, myPlanet) in myPlanets.enumerated() {
                    taskGroup.addTask {
                        try? await myPlanet.publishIPNSKeepAlive()
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
        totalUnreadCount = followingPlanets.reduce(0) { $0 + $1.unreadCount }
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
                        do {
                            try await followingPlanet.update()
                        } catch {
                            debugPrint("Error updating planet \(followingPlanet.name): \(error)")
                        }
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

    func removeArticleFromList(article: ArticleModel) {
        Task { @MainActor in
            if let index = selectedArticleList?.firstIndex(where: { $0.id == article.id }) {
                selectedArticleList?.remove(at: index)
                ArticleListViewModel.shared.articles.removeAll(where: { $0.id == article.id })
            }
            updateNavigationSubtitle()
        }
    }

    func updateNavigationSubtitle() {
        switch selectedView {
        case .today:
            if let articles = selectedArticleList {
                navigationSubtitle = "\(articles.count) fetched today"
            }
        case .unread:
            if let articles = selectedArticleList {
                if totalUnreadCount > articles.count {
                    navigationSubtitle = "\(articles.count) of \(totalUnreadCount) unread"
                } else {
                    navigationSubtitle = "\(articles.count) unread"
                }
            }
        case .starred:
            if let articles = selectedArticleList {
                navigationSubtitle = "\(articles.count) starred"
            }
        case .myPlanet(let planet):
            let canonicalPlanet = myPlanets.first(where: { $0.id == planet.id }) ?? planet
            navigationSubtitle = canonicalPlanet.navigationSubtitle()
        case .followingPlanet(let planet):
            let canonicalPlanet = followingPlanets.first(where: { $0.id == planet.id }) ?? planet
            navigationSubtitle = canonicalPlanet.navigationSubtitle()
        case .none:
            navigationSubtitle = ""
        }
    }

    private func scrollSidebarToSelectedView() {
        let sidebarID: String?
        switch selectedView {
        case .today:
            sidebarID = "sidebar-today"
        case .unread:
            sidebarID = "sidebar-unread"
        case .starred:
            sidebarID = "sidebar-starred"
        case .myPlanet(let planet):
            sidebarID = "sidebar-my-\(planet.id.uuidString)"
        case .followingPlanet(let planet):
            sidebarID = "sidebar-following-\(planet.id.uuidString)"
        case .none:
            sidebarID = nil
        }
        if let sidebarID {
            NotificationCenter.default.post(name: .scrollToSidebarItem, object: sidebarID)
        }
    }

    func refreshSelectedArticles() {
        let previousSelectedArticleID = selectedArticle?.id
        // Clear selection before changing the article list so SwiftUI's List
        // never has a selection pointing to an item not in its data source.
        selectedArticle = nil

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
                if totalUnreadCount > articles.count {
                    navigationSubtitle = "\(articles.count) of \(totalUnreadCount) unread"
                } else {
                    navigationSubtitle = "\(articles.count) unread"
                }
            }
        case .starred:
            selectedArticleList = getStarredArticles()
            navigationTitle = "Starred"
            if let articles = selectedArticleList {
                navigationSubtitle = "\(articles.count) starred"
            }
        case .myPlanet(let planet):
            let canonicalPlanet = myPlanets.first(where: { $0.id == planet.id }) ?? planet
            selectedArticleList = canonicalPlanet.articles
            navigationTitle = canonicalPlanet.name
            navigationSubtitle = canonicalPlanet.navigationSubtitle()
        case .followingPlanet(let planet):
            let canonicalPlanet = followingPlanets.first(where: { $0.id == planet.id }) ?? planet
            selectedArticleList = canonicalPlanet.articles
            navigationTitle = canonicalPlanet.name
            navigationSubtitle = canonicalPlanet.navigationSubtitle()
        case .none:
            selectedArticleList = nil
            navigationTitle = PlanetStore.app == .lite ? "Croptop" : "Planet"
            navigationSubtitle = ""
        }

        // Restore selection if the previously selected article exists in the new list.
        let restoreID = previousSelectedArticleID ?? pendingArticleRestoreID
        let isPendingRestore = previousSelectedArticleID == nil && pendingArticleRestoreID != nil
        pendingArticleRestoreID = nil
        if let restoreID,
            let matchingArticle = selectedArticleList?.first(where: { $0.id == restoreID })
        {
            selectedArticle = matchingArticle
            // Scroll the article list to reveal the restored selection.
            // Use a delay so SwiftUI has time to populate the List.
            let article = matchingArticle
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard self.selectedArticle?.id == article.id else { return }
                NotificationCenter.default.post(name: .scrollToArticle, object: article)
            }
        } else if isPendingRestore, let restoreID {
            // Article not in current aggregate view (e.g. read article no longer in Unread).
            // Fall back to navigating to the article's planet.
            if let planet = followingPlanets.first(where: { $0.articles.contains(where: { $0.id == restoreID }) }) {
                pendingArticleRestoreID = restoreID
                pendingSidebarScroll = true
                selectedView = .followingPlanet(planet)
            } else if let planet = myPlanets.first(where: { $0.articles.contains(where: { $0.id == restoreID }) }) {
                pendingArticleRestoreID = restoreID
                pendingSidebarScroll = true
                selectedView = .myPlanet(planet)
            }
        }

        if pendingSidebarScroll {
            pendingSidebarScroll = false
            scrollSidebarToSelectedView()
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

    private static let unreadDisplayLimit = 500

    func getUnreadArticles() -> [ArticleModel] {
        var articles: [ArticleModel] = []
        articles.reserveCapacity(min(totalUnreadCount, Self.unreadDisplayLimit))
        for followingPlanet in followingPlanets where !followingPlanet.unreadArticles.isEmpty {
            articles.append(contentsOf: followingPlanet.unreadArticles)
        }
        articles.sort { $0.created > $1.created }
        if articles.count > Self.unreadDisplayLimit {
            articles.removeLast(articles.count - Self.unreadDisplayLimit)
        }
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

    private func preferredSelectionViewAfterSaving(
        _ article: MyArticleModel,
        preserving preferredView: PlanetDetailViewType?
    ) -> PlanetDetailViewType {
        let articlePlanet = article.planet!

        switch preferredView {
        case .today:
            if article.created.timeIntervalSinceNow > -86400 {
                return .today
            }
        case .starred:
            if article.starred != nil {
                return .starred
            }
        case .myPlanet(let planet):
            let canonicalPlanet = myPlanets.first(where: { $0.id == planet.id }) ?? planet
            return .myPlanet(canonicalPlanet)
        default:
            break
        }

        let canonicalPlanet = myPlanets.first(where: { $0.id == articlePlanet.id }) ?? articlePlanet
        return .myPlanet(canonicalPlanet)
    }

    @MainActor
    func restoreSavedMyArticleSelection(
        _ article: MyArticleModel,
        preserving preferredView: PlanetDetailViewType?
    ) async {
        let articlePlanet = article.planet!
        let targetPlanet = myPlanets.first(where: { $0.id == articlePlanet.id }) ?? articlePlanet
        let selectionDelay: UInt64 = targetPlanet.templateName == "Croptop" ? 200_000_000 : 0

        func selectArticleFromCurrentList() -> ArticleModel? {
            selectedArticleList?.first(where: { $0.id == article.id })
                ?? targetPlanet.articles.first(where: { $0.id == article.id })
        }

        func applySelection(_ selected: ArticleModel) async {
            if selectionDelay > 0 {
                // Croptop needs a delay here when it loads from the local gateway.
                try? await Task.sleep(nanoseconds: selectionDelay)
            }
            if let current = selectedArticle, current === selected {
                NotificationCenter.default.post(name: .loadArticle, object: nil)
            } else {
                selectedArticle = selected
            }
            NotificationCenter.default.post(name: .scrollToArticle, object: selected)
            try? await Task.sleep(nanoseconds: 120_000_000)
            NotificationCenter.default.post(name: .scrollToArticle, object: selected)
        }

        let preferredTargetView = preferredSelectionViewAfterSaving(article, preserving: preferredView)
        let initialView = selectedView
        selectedView = preferredTargetView
        if selectedView == initialView {
            refreshSelectedArticles()
        }

        let retryDelays: [UInt64] = (preferredTargetView == initialView)
            ? [0, 80_000_000, 180_000_000, 320_000_000]
            : [80_000_000, 180_000_000, 320_000_000]
        for delay in retryDelays {
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }
            guard selectedView?.stringValue == preferredTargetView.stringValue else {
                continue
            }
            if let selected = selectArticleFromCurrentList() {
                await applySelection(selected)
                return
            }
        }

        let fallbackView = PlanetDetailViewType.myPlanet(targetPlanet)
        let currentView = selectedView
        selectedView = fallbackView
        if selectedView == currentView {
            refreshSelectedArticles()
        }

        let fallbackRetryDelays: [UInt64] = (fallbackView == currentView)
            ? [0, 80_000_000, 180_000_000, 320_000_000]
            : [80_000_000, 180_000_000, 320_000_000]
        for delay in fallbackRetryDelays {
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }
            guard case .myPlanet(let selectedPlanet) = selectedView,
                selectedPlanet.id == targetPlanet.id
            else {
                continue
            }
            if let selected = selectArticleFromCurrentList() {
                await applySelection(selected)
                return
            }
        }

        await applySelection(targetPlanet.articles.first(where: { $0.id == article.id }) ?? article)
    }

    private func restoreMovedMyArticleSelection(targetArticleID: UUID, targetPlanetID: UUID) async {
        // Retry because selectedView refreshes the article list asynchronously.
        let retryDelays: [UInt64] = [80_000_000, 180_000_000, 320_000_000]

        for delay in retryDelays {
            try? await Task.sleep(nanoseconds: delay)

            guard case .myPlanet(let selectedPlanet) = selectedView,
                selectedPlanet.id == targetPlanetID
            else {
                continue
            }

            if let article = selectedArticleList?.first(where: { $0.id == targetArticleID })
                ?? selectedPlanet.articles.first(where: { $0.id == targetArticleID })
            {
                selectedArticle = article
                NotificationCenter.default.post(name: .scrollToArticle, object: article)
                return
            }
        }

        guard let targetPlanet = myPlanets.first(where: { $0.id == targetPlanetID }),
            let article = targetPlanet.articles.first(where: { $0.id == targetArticleID })
        else {
            return
        }

        selectedArticle = article
        NotificationCenter.default.post(name: .scrollToArticle, object: article)
    }

    func moveMyArticle(_ article: MyArticleModel, toPlanet: MyPlanetModel) async throws {
        guard let fromPlanet = article.planet else {
            throw PlanetError.InternalError
        }
        guard !WriterStore.shared.isEditing(article: article) else {
            throw PlanetError.MoveEditingPlanetArticleError
        }
        guard fromPlanet.isPublishing == false, toPlanet.isPublishing == false else {
            throw PlanetError.MovePublishingPlanetArticleError
        }
        debugPrint("moving article: \(article), from planet: \(fromPlanet), to planet: \(toPlanet)")
        fromPlanet.articles = fromPlanet.articles.filter({ a in
            return a.id != article.id
        })
        let articleIDString: String = article.id.uuidString
        let fromPlanetIDString: String = fromPlanet.id.uuidString
        let toPlanetIDString: String = toPlanet.id.uuidString
        let fromArticlePath = article.path
        let targetArticlePath = fromArticlePath.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(toPlanetIDString).appendingPathComponent("Articles").appendingPathComponent("\(articleIDString).json")
        debugPrint("moving article from: \(fromArticlePath), to: \(targetArticlePath) ...")
        try FileManager.default.copyItem(at: fromArticlePath, to: targetArticlePath)

        let fromArticlePublicPath = article.publicBasePath
        let targetArticlePublicPath = fromArticlePublicPath.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(toPlanet.id.uuidString).appendingPathComponent(article.id.uuidString)
        debugPrint("moving public article from: \(fromArticlePublicPath), to: \(targetArticlePublicPath) ...")
        try FileManager.default.copyItem(at: fromArticlePublicPath, to: targetArticlePublicPath)

        let fromDraftPath = fromPlanet.articleDraftsPath.appendingPathComponent(
            articleIDString,
            isDirectory: true
        )
        let targetDraftPath = toPlanet.articleDraftsPath.appendingPathComponent(
            articleIDString,
            isDirectory: true
        )
        let hasArticleDraft = FileManager.default.fileExists(atPath: fromDraftPath.path)
        if hasArticleDraft {
            debugPrint("moving article draft from: \(fromDraftPath), to: \(targetDraftPath) ...")
            try FileManager.default.copyItem(at: fromDraftPath, to: targetDraftPath)
        }

        debugPrint("delete previous article")
        article.delete()
        if hasArticleDraft {
            debugPrint("delete previous article draft")
            try FileManager.default.removeItem(at: fromDraftPath)
        }

        let movedArticle = article
        movedArticle.planet = toPlanet
        movedArticle.draft = nil

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
        selectedView = .myPlanet(refreshedToPlanet)

        let movedArticleID = movedArticle.id
        Task(priority: .userInitiated) { @MainActor [weak self] in
            await self?.restoreMovedMyArticleSelection(
                targetArticleID: movedArticleID,
                targetPlanetID: refreshedToPlanet.id
            )
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
