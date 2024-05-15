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
                    Button {
                        IPFSOpenWindowManager.shared.activate()
                    } label: {
                        Text("Open IPFS Resource")
                    }
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
        let event: Set<String> = Set(arrayLiteral: "planet://Croptop")
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
                let panel = NSOpenPanel()
                panel.message = "Choose Posts to Import"
                panel.prompt = "Import"
                panel.allowsMultipleSelection = true
                panel.allowedContentTypes = [.package]
                panel.canChooseDirectories = false
                panel.canChooseFiles = true
                panel.canCreateDirectories = false
                let response = panel.runModal()
                guard response == .OK, panel.urls.count > 0 else { return }
                Task { @MainActor in
                    do {
                        try await MyArticleModel.importArticles(fromURLs: panel.urls, isCroptopData: true)
                    } catch {
                        PlanetStore.shared.isShowingAlert = true
                        PlanetStore.shared.alertTitle = "Failed to Import Posts"
                        switch error {
                        case PlanetError.ImportPlanetArticlePublishingError:
                            PlanetStore.shared.alertMessage = "Croptop is publishing progress, please try again later."
                        default:
                            PlanetStore.shared.alertMessage = error.localizedDescription
                        }
                    }
                }
            } label: {
                Text("Import Posts")
            }
            
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
