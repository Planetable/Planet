//
//  PlanetApp.swift
//  Planet
//
//  Created by Kai on 2/15/22.
//

import SwiftUI
import Sparkle
import UserNotifications

@main
struct PlanetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var planetStore = PlanetStore.shared
    @StateObject var templateStore = TemplateStore.shared
    @Environment(\.openURL) private var openURL

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
                    SUUpdater.shared().checkForUpdates(NSButton())
                } label: {
                    Text("Check for Updates")
                }
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
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        true
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

    func applicationDidFinishLaunching(_ notification: Notification) {
        // let saver = Saver.shared
        // saver.savePlanets()
        // saver.migratePublic()

        setupNotification()

        SUUpdater.shared().checkForUpdatesInBackground()

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


extension AppDelegate: UNUserNotificationCenterDelegate {
    func setupNotification() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
            if settings.alertSetting == .disabled {
                center.requestAuthorization(options: [.alert, .badge]) { _, _ in
                }
            } else {
                center.delegate = self
                let dismissAction = UNNotificationAction(identifier: "PlanetNotificationDismissIdentifier", title: "Dismiss", options: [.destructive])
                let readAction = UNNotificationAction(identifier: "PlanetNotificationReadArticleIdentifier", title: "Read Article", options: [.destructive])
                let showAction = UNNotificationAction(identifier: "PlanetNotificationShowPlanetIdentifier", title: "Show Planet", options: [.destructive])
                let readArticleCategory = UNNotificationCategory(identifier: "PlanetNotificationReadActionIdentifier", actions: [dismissAction, readAction], intentIdentifiers: [], hiddenPreviewsBodyPlaceholder: "", options: .customDismissAction)
                let showPlanetCategory = UNNotificationCategory(identifier: "PlanetNotificationShowActionIdentifier", actions: [dismissAction, showAction], intentIdentifiers: [], hiddenPreviewsBodyPlaceholder: "", options: .customDismissAction)
                center.setNotificationCategories([readArticleCategory, showPlanetCategory])
            }
        }
    }

    func processNotification(_ response: UNNotificationResponse) {
        switch response.actionIdentifier {
            case "PlanetNotificationReadArticleIdentifier":
                Task.detached(priority: .background) {
                    await MainActor.run {
                        var skip = false
                        for following in PlanetStore.shared.followingPlanets {
                            guard let articles = following.articles else { continue }
                            if skip { break }
                            for article in articles {
                                if article.link.replacingOccurrences(of: "/", with: "") == response.notification.request.identifier || article.id.uuidString == response.notification.request.identifier {
                                    PlanetStore.shared.selectedView = .followingPlanet(following)
                                    NSWorkspace.shared.open(URL(string: "planet://")!)
                                    skip = true
                                    break
                                }
                            }
                        }
                    }
                }
            case "PlanetNotificationShowPlanetIdentifier":
                Task.detached(priority: .background) {
                    await MainActor.run {
                        for following in PlanetStore.shared.followingPlanets {
                            if following.id.uuidString == response.notification.request.identifier {
                                PlanetStore.shared.selectedView = .followingPlanet(following)
                                NSWorkspace.shared.open(URL(string: "planet://")!)
                                break
                            }
                        }
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
