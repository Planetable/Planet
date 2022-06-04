//
//  PlanetApp.swift
//  Planet
//
//  Created by Kai on 2/15/22.
//

import SwiftUI
import Sparkle


@main
struct PlanetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var planetStore: PlanetStore
    @StateObject var templateStore: TemplateBrowserStore
    @Environment(\.openURL) private var openURL

    init() {
        self._planetStore = StateObject(wrappedValue: PlanetStore.shared)
        self._templateStore = StateObject(wrappedValue: TemplateBrowserStore.shared)
    }

    var body: some Scene {
        WindowGroup {
            PlanetMainView()
                .environmentObject(planetStore)
                .environment(\.managedObjectContext, PlanetDataController.shared.viewContext)
                .handlesExternalEvents(preferring: Set(arrayLiteral: "Planet"), allowing: Set(arrayLiteral: "Planet"))
        }
        .handlesExternalEvents(matching: Set(arrayLiteral: "Planet"))
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
                    PlanetManager.shared.publishLocalPlanets()
                } label: {
                    Text("Publish My Planets")
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])

                Button {
                    PlanetManager.shared.updateFollowingPlanets()
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

                Button {
                    guard planetStore.currentPlanet != nil else { return }
                    planetStore.isExportingPlanet = true
                } label: {
                    Text("Export Planet")
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }
            CommandGroup(after: .appInfo) {
                Button {
                    SUUpdater.shared().checkForUpdates(NSButton())
                } label: {
                    Text("Check for Updates")
                }
            }
            SidebarCommands()
            // disable text edit commands since they currently don't work with writer
            // TextEditingCommands()
            TextFormattingCommands()
        }

        WindowGroup("Planet Templates") {
            TemplateBrowserView()
                .environmentObject(templateStore)
                .frame(minWidth: 720, minHeight: 480)
                .handlesExternalEvents(preferring: Set(arrayLiteral: "Template"), allowing: Set(arrayLiteral: "Template"))
        }
        .handlesExternalEvents(matching: Set(arrayLiteral: "Template"))
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
            let url = url.absoluteString.replacingOccurrences(of: "planet://", with: "")
            guard !PlanetDataController.shared.planetExists(planetURL: url) else { return }
            Task {
                try await PlanetManager.shared.followPlanet(url: url)
            }
        } else if url.lastPathComponent.hasSuffix(".planet") {
            do {
                let planet = try Planet.importMyPlanet(importURL: url)
                Task { @MainActor in
                    PlanetStore.shared.currentPlanet = planet
                }
                return
            } catch PlanetError.PlanetExistsError {
                Task { @MainActor in
                    PlanetManager.shared.alert(
                        title: "Failed to Import Planet",
                        message: "The planet already exists."
                    )
                }
            } catch {
                Task { @MainActor in
                    PlanetManager.shared.alert(title: "Failed to Import Planet", message: "Please try again.")
                }
            }
        }
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        UserDefaults.standard.set(false, forKey: "NSFullScreenMenuItemEverywhere")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        PlanetDataController.shared.cleanupDatabase()
        let _ = PlanetManager.shared
        TemplateBrowserStore.shared.loadTemplates()
        SUUpdater.shared().checkForUpdatesInBackground()
    }

    func applicationWillTerminate(_ notification: Notification) {
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        PlanetDataController.shared.cleanupDatabase()
        PlanetDataController.shared.save()
        Task.init {
            await IPFSDaemon.shared.shutdownDaemon()
            await NSApplication.shared.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
