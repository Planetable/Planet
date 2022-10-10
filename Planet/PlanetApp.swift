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
        WindowGroup {
            PlanetMainView()
                .environmentObject(planetStore)
                .frame(minWidth: 720, minHeight: 600)
        }
        .windowToolbarStyle(.automatic)
        .windowStyle(.titleBar)
        .handlesExternalEvents(matching: Set(arrayLiteral: ""))
        .commands {
            CommandGroup(replacing: .newItem) {
            }
            CommandMenu("Tools") {
                Button {
                    openURL(URL(string: "planet://Template")!)
                } label: {
                    Text("Template Browser")
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])

                Button {
                    PlanetAppDelegate.shared.openDownloadsWindow()
                } label: {
                    Text("Downloads")
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])

                publishedFoldersMenu()

                Divider()

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

                Button {
                    planetStore.isImportingPlanet = true
                } label: {
                    Text("Import Planet")
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
            }
            CommandGroup(after: .appInfo) {
                Button {
                    updater.checkForUpdates()
                } label: {
                    Text("Check for Updates")
                }
                .disabled(!updater.canCheckForUpdates)
            }
            SidebarCommands()
            CommandGroup(replacing: .help) {
                Button {
                    openURL(URL(string: "planet://Onboarding")!)
                } label: {
                    Text("What's New in Planet")
                }
            }
        }

        WindowGroup("Planet Templates") {
            TemplateBrowserView()
                .environmentObject(templateStore)
                .frame(minWidth: 720, minHeight: 480)
        }
        .handlesExternalEvents(matching: Set(arrayLiteral: "planet://Template"))

        WindowGroup("Onboarding") {
            OnboardingView()
                .frame(width: 720, height: 528)
                .onAppear {
                    Task { @MainActor in
                        NSApplication.shared.windows.forEach { window in
                            if window.title == "Onboarding" {
                                window.styleMask.subtract(.resizable)
                                window.styleMask.subtract(.fullScreen)
                            }
                        }
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .handlesExternalEvents(matching: Set(arrayLiteral: "planet://Onboarding"))

        Settings {
            PlanetSettingsView()
        }
    }

}

class PlanetAppDelegate: NSObject, NSApplicationDelegate {
    static let shared = PlanetAppDelegate()

    var downloadsWindowController: PlanetDownloadsWindowController?

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
            for window in windows {
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
        // fixes to applicationShouldHandleReopen not called in macOS 12.
        //if #available(macOS 13, *) {
        //} else {
        //    NSApplication.shared.delegate = self
        //}

        // use hide instead of close for main windows to keep reopen position.
        for w in NSApp.windows {
            if w.canHide && w.canBecomeMain && w.styleMask.contains(.closable) {
                w.delegate = self
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
    }

    func applicationWillTerminate(_ notification: Notification) {
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Task {
            IPFSDaemon.shared.shutdownDaemon()
            await NSApplication.shared.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}

// MARK: -
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
                                    planetStore.isShowingAlert = true
                                    planetStore.alertTitle = "Failed to Access to Folder"
                                    planetStore.alertMessage = error.localizedDescription
                                }
                            } label: {
                                Text("Reveal in Finder")
                            }

                            Button {
                                Task { @MainActor in
                                    serviceStore.addPublishingFolder(folder)
                                    let keyName = folder.id.uuidString
                                    do {
                                        if try await !IPFSDaemon.shared.checkKeyExists(name: keyName) {
                                            let _ = try await IPFSDaemon.shared.generateKey(name: keyName)
                                        }
                                        let url = try serviceStore.restoreFolderAccess(forFolder: folder)
                                        guard url.startAccessingSecurityScopedResource() else {
                                            throw PlanetError.PublishedServiceFolderPermissionError
                                        }
                                        let cid = try await IPFSDaemon.shared.addDirectory(url: url)
                                        url.stopAccessingSecurityScopedResource()
                                        var versions = try serviceStore.loadPublishedVersions(byFolderKeyName: keyName)
                                        if let lastVersion = versions.last, lastVersion.cid == cid {
                                            throw PlanetError.PublishedServiceFolderUnchangedError
                                        }
                                        versions.append(PlanetPublishedFolderVersion(id: folder.id, cid: cid, created: Date()))
                                        try serviceStore.savePublishedVersions(versions)
                                        let result = try await IPFSDaemon.shared.api(
                                            path: "name/publish",
                                            args: [
                                                "arg": cid,
                                                "allow-offline": "1",
                                                "key": keyName,
                                                "quieter": "1",
                                                "lifetime": "7200h",
                                            ],
                                            timeout: 600
                                        )
                                        let decoder = JSONDecoder()
                                        let publishedStatus = try decoder.decode(IPFSPublished.self, from: result)
                                        let updatedFolder = PlanetPublishedFolder(id: folder.id, url: folder.url, created: folder.created, published: Date(), publishedLink: publishedStatus.name)
                                        let updatedFolders = serviceStore.publishedFolders.map() { f in
                                            if f.id == folder.id {
                                                return updatedFolder
                                            } else {
                                                return f
                                            }
                                        }
                                        serviceStore.removePublishingFolder(folder)
                                        serviceStore.updatePublishedFolders(updatedFolders)
                                        debugPrint("Folder published -> \(folder.url)")
                                        let content = UNMutableNotificationContent()
                                        content.title = "Folder Published"
                                        content.subtitle = folder.url.absoluteString
                                        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                                        let request = UNNotificationRequest(
                                            identifier: keyName,
                                            content: content,
                                            trigger: trigger
                                        )
                                        try? await UNUserNotificationCenter.current().add(request)
                                    } catch {
                                        debugPrint("Failed to publish folder: \(folder), error: \(error)")
                                        serviceStore.removePublishingFolder(folder)
                                        planetStore.isShowingAlert = true
                                        planetStore.alertTitle = "Failed to Publish Folder"
                                        planetStore.alertMessage = error.localizedDescription
                                    }
                                }
                            } label: {
                                Text("Publish")
                            }
                        }

                        Divider()

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
                let panel = NSOpenPanel()
                panel.message = "Choose Folder to Publish"
                panel.prompt = "Choose"
                panel.allowsMultipleSelection = false
                panel.allowedContentTypes = [.folder]
                panel.canChooseDirectories = true
                panel.canChooseFiles = false
                let response = panel.runModal()
                guard response == .OK, let url = panel.url else { return }
                var folders = serviceStore.publishedFolders
                var exists = false
                for f in folders {
                    if f.url.absoluteString.md5() == url.absoluteString.md5() {
                        exists = true
                        break
                    }
                }
                if exists { return }
                let folder = PlanetPublishedFolder(id: UUID(), url: url, created: Date())
                do {
                    try serviceStore.saveBookmarkData(forFolder: folder)
                    folders.insert(folder, at: 0)
                    let updatedFolders = folders
                    Task { @MainActor in
                        serviceStore.updatePublishedFolders(updatedFolders)
                    }
                } catch {
                    debugPrint("failed to add folder: \(error)")
                    planetStore.isShowingAlert = true
                    planetStore.alertTitle = "Failed to Add Folder"
                    planetStore.alertMessage = error.localizedDescription
                }
            } label: {
                Text("Add Folder")
            }
        }
        .onReceive(serviceStore.timer) { _ in
            serviceStore.timestamp = Int(Date().timeIntervalSince1970)
        }
    }
}

// MARK: -
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

// MARK: -
extension PlanetAppDelegate {
    func openDownloadsWindow() {
        if downloadsWindowController == nil {
            downloadsWindowController = PlanetDownloadsWindowController()
        }
        downloadsWindowController?.showWindow(nil)
    }
}

// MARK: -
// Hide main window instead of closing to keep window position.
// https://stackoverflow.com/questions/71506416/restoring-macos-window-size-after-close-using-swiftui-windowsgroup
extension PlanetAppDelegate: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        NSApp.hide(nil)
        return false
    }
}
