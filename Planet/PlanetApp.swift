//
//  PlanetApp.swift
//  Planet
//
//  Created by Kai on 2/15/22.
//

import SwiftUI
import UserNotifications


@main
struct PlanetApp: App {
    @NSApplicationDelegateAdaptor(PlanetAppDelegate.self) var appDelegate
    @StateObject var planetStore: PlanetStore
    @StateObject var templateStore: TemplateStore
    @StateObject var updater: PlanetUpdater
    @StateObject var serviceStore: PlanetPublishedServiceStore
    @Environment(\.openURL) private var openURL

    init() {
        _planetStore = StateObject(wrappedValue: PlanetStore.shared)
        _templateStore = StateObject(wrappedValue: TemplateStore.shared)
        _updater = StateObject(wrappedValue: PlanetUpdater.shared)
        _serviceStore = StateObject(wrappedValue: PlanetPublishedServiceStore.shared)
    }

    var body: some Scene {
        mainWindow()
            .windowToolbarStyle(.automatic)
            .windowStyle(.titleBar)
            .commands {
                CommandGroup(replacing: .newItem) {
                }
                CommandMenu("Tools") {
                    Group {
                        Button {
                            PlanetAppDelegate.shared.openTemplateWindow()
                        } label: {
                            Text("Template Browser")
                        }
                        .keyboardShortcut("l", modifiers: [.command, .shift])
                        
                        Button {
                            PlanetAppDelegate.shared.openKeyManagerWindow()
                        } label: {
                            Text("Key Manager")
                        }
                        .keyboardShortcut("k", modifiers: [.command, .shift])

                        Button {
                            PlanetAppDelegate.shared.openDownloadsWindow()
                        } label: {
                            Text("Downloads")
                        }
                        .keyboardShortcut("d", modifiers: [.command, .shift])

                        publishedFoldersMenu()

                        Divider()
                    }

                    Group {
                        Button {
                            planetStore.publishMyPlanets()
                        } label: {
                            Text("Publish My Planets")
                        }
                        .keyboardShortcut("p", modifiers: [.command, .shift])

                        Button {
                            planetStore.updateFollowingPlanets()
                        } label: {
                            Text("Update Following Planets")
                        }
                        .keyboardShortcut("r", modifiers: [.command, .shift])
                        
                        Divider()
                    }
                    
                    Group {
                        Button {
                            Task(priority: .userInitiated) {
                                await MainActor.run {
                                    do {
                                        try PlanetStore.shared.load()
                                        try TemplateStore.shared.load()
                                        PlanetStore.shared.selectedView = nil
                                        PlanetStore.shared.selectedArticle = nil
                                        PlanetStore.shared.selectedArticleList = nil
                                        PlanetStore.shared.refreshSelectedArticles()
                                    } catch {
                                        debugPrint("failed to reload: \(error)")
                                    }
                                }
                            }
                        } label: {
                            Text("Reload Planets")
                        }
                        .disabled(URLUtils.repoPath() == URLUtils.defaultRepoPath)

                        Divider()
                    }

                    Group {
                        Button {
                            planetStore.isImportingPlanet = true
                        } label: {
                            Text("Import Planet")
                        }
                        .keyboardShortcut("i", modifiers: [.command, .shift])
                    }
                }
                CommandGroup(after: .appInfo) {
                    Button {
                        updater.checkForUpdates()
                    } label: {
                        Text("Check for Updates")
                    }
                    .disabled(!updater.canCheckForUpdates)

                    if planetStore.hasWalletAddress() {
                        Button {
                            planetStore.isShowingWalletDisconnectConfirmation = true
                        } label: {
                            Text("Disconnect Wallet")
                        }
                    } else {
                        Button {
                            WalletManager.shared.connectV1()
                        } label: {
                            Text("Connect Wallet")
                        }
                    }

                    if planetStore.walletConnectV2Ready {
                        Button {
                            WalletManager.shared.connectV2()
                        } label: {
                            Text("Connect Wallet V2")
                        }
                    }
                }
                SidebarCommands()
                CommandGroup(replacing: .help) {
                    Button {
                        planetStore.isShowingOnboarding = true
                    } label: {
                        Text("What's New in Planet")
                    }
                }
            }

        Settings {
            PlanetSettingsView()
        }
    }

    private func mainWindow() -> some Scene {
        if #available(macOS 13.0, *) {
            return planetMainWindow()
        } else {
            return planetMainWindowGroup()
        }
    }

    @SceneBuilder
    private func planetMainWindowGroup() -> some Scene {
        let mainEvent: Set<String> = Set(arrayLiteral: "planet://Planet")
        WindowGroup("Planet") {
            PlanetMainView()
                .environmentObject(planetStore)
                .frame(minWidth: 720, minHeight: 600)
                .handlesExternalEvents(preferring: mainEvent, allowing: mainEvent)
        }
        .handlesExternalEvents(matching: mainEvent)
    }

    @available(macOS 13.0, *)
    @SceneBuilder
    private func planetMainWindow() -> some Scene {
        Window("Planet", id: "planetMainWindow") {
            PlanetMainView()
                .environmentObject(planetStore)
                .frame(minWidth: 720, minHeight: 600)
        }
    }
}

class PlanetAppDelegate: NSObject, NSApplicationDelegate {
    static let shared = PlanetAppDelegate()

    var templateWindowController: TBWindowController?
    var downloadsWindowController: PlanetDownloadsWindowController?
    var publishedFoldersDashboardWindowController: PFDashboardWindowController?
    var keyManagerWindowController: PlanetKeyManagerWindowController?

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        return true
    }

    // use AppDelegate lifecycle since View.onOpenURL does not work
    // Reference: https://developer.apple.com/forums/thread/673822
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        if url.absoluteString.hasPrefix("planet://") {
            let link = url.absoluteString.replacingOccurrences(of: "planet://", with: "")
            Task { @MainActor in
                let planet = try await FollowingPlanetModel.follow(link: link)
                PlanetStore.shared.followingPlanets.insert(planet, at: 0)
                PlanetStore.shared.selectedView = .followingPlanet(planet)
            }
        } else if url.lastPathComponent.hasSuffix(".planet") {
            Task { @MainActor in
                let planet = try MyPlanetModel.importBackup(from: url)
                PlanetStore.shared.myPlanets.insert(planet, at: 0)
                PlanetStore.shared.selectedView = .myPlanet(planet)
            }
        }
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        UserDefaults.standard.set(false, forKey: "NSFullScreenMenuItemEverywhere")
    }

    func applicationWillBecomeActive(_ notification: Notification) {
        debugPrint("applicationWillBecomeActive")
        // TODO: If Writer is open, then the main window should not always get focus
        if let windows = (notification.object as? NSApplication)?.windows {
            var i = 0
            for window in windows where window.className == "SwiftUI.AppKitWindow" {
                debugPrint("Planet window: \(window)")
                debugPrint("window.isMainWindow: \(window.isMainWindow)")
                debugPrint("window.isMiniaturized: \(window.isMiniaturized)")
                if window.isMiniaturized {
                    if i == 0 {
                        window.makeKeyAndOrderFront(self)
                    } else {
                        window.deminiaturize(self)
                    }
                }
                i = i + 1
            }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // use hide instead of close for main windows to keep reopen position.
        if #available(macOS 13.0, *) {
        } else {
            for w in NSApp.windows {
                debugPrint("Window Info: \(w) frameAutosaveName: \(w.frameAutosaveName)")
                if w.canHide && w.canBecomeMain && w.styleMask.contains(.closable) {
                    w.delegate = self
                }
            }
        }

        setupNotification()

        let saver = Saver.shared
        if saver.isMigrationNeeded() {
            Task { @MainActor in
                PlanetStore.shared.isMigrating = true
            }
            var migrationErrors: Int = 0
            migrationErrors = migrationErrors + saver.savePlanets()
            migrationErrors = migrationErrors + saver.migratePublic()
            migrationErrors = migrationErrors + saver.migrateTemplates()
            if migrationErrors == 0 {
                saver.setMigrationDoneFlag(flag: true)
                Task { @MainActor in
                    try PlanetStore.shared.load()
                    try TemplateStore.shared.load()
                }
            }
            Task { @MainActor in
                try await Task.sleep(nanoseconds: 1_000_000_000)
                PlanetStore.shared.isMigrating = false
            }
        }

        PlanetUpdater.shared.checkForUpdatesInBackground()

        // Connect Wallet V1

        WalletManager.shared.setupV1()

        // Connect Wallet V2
        if let wc2Enabled: Bool = Bundle.main.object(forInfoDictionaryKey: "WALLETCONNECTV2_ENABLED") as? Bool, wc2Enabled == true {
            do {
                try WalletManager.shared.setupV2()
            } catch {
                debugPrint("WalletConnectV2: Failed to prepare the connection: \(error)")
            }
        }
        
        // Planet API
        do {
            try PlanetAPI.shared.launch()
        } catch {
            debugPrint("Failed to launch planet api: \(error)")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Task.detached(priority: .utility) {
            PlanetAPI.shared.shutdown()
            IPFSDaemon.shared.shutdownDaemon()
            await NSApplication.shared.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}

// MARK: - Published Folders Menu UI

extension PlanetApp {
    @ViewBuilder
    private func publishedFoldersMenu() -> some View {
        Menu("Published Folders") {
            ForEach(serviceStore.publishedFolders, id: \.id) { folder in
                Menu(folder.url.path.removingPercentEncoding ?? folder.url.path) {
                    if serviceStore.publishingFolders.contains(folder.id) {
                        Text("Publishing ...")
                    } else {
                        if !FileManager.default.fileExists(atPath: folder.url.path) {
                            Text("Folder is missing ...")
                        } else {
                            if let published = folder.published, let publishedLink = folder.publishedLink {
                                Text("Last Published: " + published.relativeDateDescription())
                                Divider()
                                Button {
                                    if let url = URL(string: "\(IPFSDaemon.preferredGateway())/ipns/\(publishedLink)") {
                                        openURL(url)
                                    }
                                } label: {
                                    Text("Open in Public Gateway")
                                }
                                Button {
                                    if let url = URL(string: "\(IPFSDaemon.shared.gateway)/ipns/\(publishedLink)") {
                                        openURL(url)
                                    }
                                } label: {
                                    Text("Open in Localhost")
                                }
                            }
                            Button {
                                do {
                                    let url = try serviceStore.restoreFolderAccess(forFolder: folder)
                                    guard url.startAccessingSecurityScopedResource() else {
                                        throw PlanetError.PublishedServiceFolderPermissionError
                                    }
                                    NSWorkspace.shared.open(url)
                                    url.stopAccessingSecurityScopedResource()
                                } catch {
                                    debugPrint("failed to request access to folder: \(folder), error: \(error)")
                                    let alert = NSAlert()
                                    alert.messageText = "Failed to Access to Folder"
                                    alert.informativeText = error.localizedDescription
                                    alert.alertStyle = .informational
                                    alert.addButton(withTitle: "OK")
                                    alert.runModal()
                                }
                            } label: {
                                Text("Reveal in Finder")
                            }
                            Button {
                                Task { @MainActor in
                                    do {
                                        try await self.serviceStore.publishFolder(folder, skipCIDCheck: true)
                                        let content = UNMutableNotificationContent()
                                        content.title = "Folder Published"
                                        content.subtitle = folder.url.absoluteString
                                        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                                        let request = UNNotificationRequest(
                                            identifier: folder.id.uuidString,
                                            content: content,
                                            trigger: trigger
                                        )
                                        try? await UNUserNotificationCenter.current().add(request)
                                    } catch PlanetError.PublishedServiceFolderUnchangedError {
                                        let alert = NSAlert()
                                        alert.messageText = "Failed to Publish Folder"
                                        alert.informativeText = "Folder content hasn't changed since last publish."
                                        alert.alertStyle = .informational
                                        alert.addButton(withTitle: "OK")
                                        alert.runModal()
                                    } catch {
                                        debugPrint("Failed to publish folder: \(folder), error: \(error)")
                                        let alert = NSAlert()
                                        alert.messageText = "Failed to Publish Folder"
                                        alert.informativeText = error.localizedDescription
                                        alert.alertStyle = .informational
                                        alert.addButton(withTitle: "OK")
                                        alert.runModal()
                                    }
                                }
                            } label: {
                                Text("Publish")
                            }
                        }
                        Divider()
                        if let _ = folder.published, let _ = folder.publishedLink {
                            Button {
                                serviceStore.exportFolderKey(folder)
                            } label: {
                                Text("Backup Folder Key")
                            }
                            Divider()
                        }
                        Button {
                            serviceStore.addToRemovingPublishedFolderQueue(folder)
                            let updatedFolders = serviceStore.publishedFolders.filter { f in
                                return f.id != folder.id
                            }
                            Task { @MainActor in
                                serviceStore.updatePublishedFolders(updatedFolders)
                            }
                        } label: {
                            Text("Remove")
                        }
                    }
                }
            }
            if serviceStore.publishedFolders.count > 0 {
                Divider()
            }
            Button {
                serviceStore.addFolder()
            } label: {
                Text("Add Folder")
            }
            Divider()
            Button {
                PlanetAppDelegate.shared.openPublishedFoldersDashboardWindow()
            } label: {
                Text("Dashboard")
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])
            Menu("Options") {
                Toggle("Automatically Publish", isOn: $serviceStore.autoPublish)
                    .onChange(of: serviceStore.autoPublish) { newValue in
                        Task { @MainActor in
                            self.serviceStore.autoPublish = newValue
                        }
                    }
                    .help("Turn on to publish changes automatically.")
            }
        }
        .onReceive(serviceStore.timer) { _ in
            serviceStore.timestamp = Int(Date().timeIntervalSince1970)
            serviceStore.updatePendingPublishings()
        }
    }
}

// MARK: - User Notifications

extension PlanetAppDelegate: UNUserNotificationCenterDelegate {
    func setupNotification() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
            if settings.alertSetting == .disabled {
                center.requestAuthorization(options: [.alert, .badge]) { _, _ in
                }
            } else {
                center.delegate = self
                let readArticleCategory = UNNotificationCategory(identifier: "PlanetReadArticleNotification", actions: [], intentIdentifiers: [], options: [])
                let showPlanetCategory = UNNotificationCategory(identifier: "PlanetShowPlanetNotification", actions: [], intentIdentifiers: [], options: [])
                center.setNotificationCategories([readArticleCategory, showPlanetCategory])
            }
        }
    }

    func processNotification(_ response: UNNotificationResponse) {
        if response.actionIdentifier != UNNotificationDefaultActionIdentifier {
            return
        }
        switch response.notification.request.content.categoryIdentifier {
            case "PlanetReadArticleNotification":
                Task { @MainActor in
                    let articleId = response.notification.request.identifier
                    for following in PlanetStore.shared.followingPlanets {
                        if let article = following.articles.first(where: { $0.id.uuidString == articleId }) {
                            PlanetStore.shared.selectedView = .followingPlanet(following)
                            PlanetStore.shared.refreshSelectedArticles()
                            Task { @MainActor in
                                PlanetStore.shared.selectedArticle = article
                            }
                            NSWorkspace.shared.open(URL(string: "planet://")!)
                            return
                        }
                    }
                }
            case "PlanetShowPlanetNotification":
                Task { @MainActor in
                    let planetId = response.notification.request.identifier
                    if let following = PlanetStore.shared.followingPlanets.first(where: { $0.id.uuidString == planetId }) {
                        PlanetStore.shared.selectedView = .followingPlanet(following)
                        NSWorkspace.shared.open(URL(string: "planet://")!)
                    }
                }
            default:
                break
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_: UNUserNotificationCenter, willPresent _: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .badge])
    }

    func userNotificationCenter(_: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        processNotification(response)
        completionHandler()
    }
}

// MARK: - Window Controllers

extension PlanetAppDelegate {
    func openDownloadsWindow() {
        if downloadsWindowController == nil {
            downloadsWindowController = PlanetDownloadsWindowController()
        }
        downloadsWindowController?.showWindow(nil)
    }

    func openTemplateWindow() {
        if templateWindowController == nil {
            templateWindowController = TBWindowController()
        }
        templateWindowController?.showWindow(nil)
    }
    
    func openPublishedFoldersDashboardWindow() {
        if publishedFoldersDashboardWindowController == nil {
            publishedFoldersDashboardWindowController = PFDashboardWindowController()
        }
        publishedFoldersDashboardWindowController?.showWindow(nil)
    }
    
    func openKeyManagerWindow() {
        if keyManagerWindowController == nil {
            keyManagerWindowController = PlanetKeyManagerWindowController()
        }
        keyManagerWindowController?.showWindow(nil)
    }
}

// MARK: -
// Hide main window instead of closing to keep window position.
// https://stackoverflow.com/questions/71506416/restoring-macos-window-size-after-close-using-swiftui-windowsgroup
extension PlanetAppDelegate: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if #available(macOS 13.0, *) {
            return true
        } else {
            NSApp.hide(nil)
            return false
        }
    }
}
