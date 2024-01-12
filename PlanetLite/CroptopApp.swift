//
//  CroptopApp.swift
//  Croptop
//

import SwiftUI


@main
struct CroptopApp: App {
    @NSApplicationDelegateAdaptor(PlanetLiteAppDelegate.self) var appDelegate
    @Environment(\.openURL) private var openURL
    @ObservedObject private var updater: PlanetUpdater
    @ObservedObject private var keyboardHelper: KeyboardShortcutHelper

    init() {
        _updater = ObservedObject(wrappedValue: PlanetUpdater.shared)
        _keyboardHelper = ObservedObject(wrappedValue: KeyboardShortcutHelper.shared)
    }

    var body: some Scene {
        appWindow()
            .windowToolbarStyle(.automatic)
            .windowStyle(.titleBar)
            .commands {
                CommandGroup(replacing: .newItem) {
                }
                keyboardHelper.writerCommands()
                fileCommands()
                infoCommands()
                helperCommands()
                SidebarCommands()
            }

        Settings {
            AppSettingsView()
        }
    }

    private func appWindow() -> some Scene {
        if #available(macOS 13.0, *) {
            return appMainWindow()
        } else {
            return appMainWindowGroup()
        }
    }

    @SceneBuilder
    private func appMainWindowGroup() -> some Scene {
        let event: Set<String> = Set(arrayLiteral: "croptop://Croptop")
        WindowGroup("Croptop") {
            AppMainView()
                .frame(minWidth: PlanetUI.WINDOW_SIDEBAR_WIDTH_MIN + PlanetUI.WINDOW_CONTENT_WIDTH_MIN, minHeight: PlanetUI.WINDOW_CONTENT_HEIGHT_MIN)
                .handlesExternalEvents(preferring: event, allowing: event)
        }
        .handlesExternalEvents(matching: event)
    }

    @available(macOS 13.0, *)
    @SceneBuilder
    private func appMainWindow() -> some Scene {
        Window("Croptop", id: "croptopMainWindow") {
            AppMainView()
                .frame(minWidth: PlanetUI.WINDOW_SIDEBAR_WIDTH_MIN + PlanetUI.WINDOW_CONTENT_WIDTH_MIN, minHeight: PlanetUI.WINDOW_CONTENT_HEIGHT_MIN)
        }
    }

    @CommandsBuilder
    func fileCommands() -> some Commands {
        CommandGroup(after: .importExport) {
            Button {
                KeyboardShortcutHelper.shared.importPlanetAction()
            } label: {
                Text("Import Site")
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])

            Button {
                if let planet = keyboardHelper.activeMyPlanet {
                    Task {
                        do {
                            try await planet.rebuild()
                        } catch {
                            debugPrint("failed to rebuild planet: \(planet), error: \(error)")
                        }
                    }
                }
            } label: {
                Text("Rebuild Site")
            }
            .disabled(keyboardHelper.activeMyPlanet == nil)
            .keyboardShortcut("r", modifiers: [.command])
        }
    }

    @CommandsBuilder
    func infoCommands() -> some Commands {
        CommandGroup(after: .appInfo) {
            Button {
                self.updater.checkForUpdates()
            } label: {
                Text("Check for Updates")
            }
            .disabled(!updater.canCheckForUpdates)
        }
    }

    @CommandsBuilder
    func helperCommands() -> some Commands {
        CommandGroup(replacing: .help) {
            Button {
                if let url = URL(string: "https://croptop.eth.limo") {
                    openURL(url)
                }
            } label: {
                Text("Learn more about Croptop")
            }

            Button {
                if let url = URL(string: "https://discord.com/invite/ZSFkRjFkrA") {
                    openURL(url)
                }
            } label: {
                Text("Discord")
            }
        }
    }
}
