//
//  PlanetApp.swift
//  Planet
//
//  Created by Kai on 2/15/22.
//

import SwiftUI


@main
struct PlanetApp: App {
    @NSApplicationDelegateAdaptor(PlanetAppDelegate.self) var appDelegate
    @StateObject var planetStore: PlanetStore
    @StateObject var iconManager: IconManager
    @ObservedObject var keyboardHelper: KeyboardShortcutHelper

    init() {
        _planetStore = StateObject(wrappedValue: PlanetStore.shared)
        _iconManager = StateObject(wrappedValue: IconManager.shared)
        _keyboardHelper = ObservedObject(wrappedValue: KeyboardShortcutHelper.shared)
    }

    var body: some Scene {
        mainWindow()
            .windowToolbarStyle(.automatic)
            .windowStyle(.titleBar)
            .commands {
                CommandGroup(replacing: .newItem) {
                    Button {
                        IPFSOpenWindowManager.shared.activate()
                    } label: {
                        Text("Open IPFS Resource")
                    }
                }
                keyboardHelper.writerCommands()
                keyboardHelper.toolsCommands()
                keyboardHelper.infoCommands()
                keyboardHelper.helpCommands()
                SidebarCommands()
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
                .environmentObject(iconManager)
                .frame(minWidth: 840, minHeight: 600)
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
                .environmentObject(iconManager)
                .frame(minWidth: 840, minHeight: 600)
        }
    }
}
