//
//  KeyboardShortcutHelper.swift
//  Planet
//
//  Created by Kai on 4/4/23.
//

import Foundation
import UserNotifications
import SwiftUI
import UniformTypeIdentifiers


class KeyboardShortcutHelper: ObservableObject {
    static let shared = KeyboardShortcutHelper()

    @Environment(\.openURL) private var openURL

    @ObservedObject private var updater: PlanetUpdater
    @ObservedObject private var serviceStore: PlanetPublishedServiceStore

    @Published var activeWriterWindow: WriterWindow?
    @Published var activeMyPlanet: MyPlanetModel?

    init() {
        _updater = ObservedObject(wrappedValue: PlanetUpdater.shared)
        _serviceStore = ObservedObject(wrappedValue: PlanetPublishedServiceStore.shared)
    }

    @CommandsBuilder
    func helpCommands() -> some Commands {
        CommandGroup(replacing: .help) {
            Button {
                PlanetStore.shared.isShowingOnboarding = true
            } label: {
                Text("What's New in Planet")
            }
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

            if PlanetStore.shared.hasWalletAddress() {
                Button {
                    PlanetStore.shared.isShowingWalletDisconnectConfirmation = true
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

            if PlanetStore.shared.walletConnectV2Ready {
                Button {
                    WalletManager.shared.connectV2()
                } label: {
                    Text("Connect Wallet V2")
                }
            }

            if PlanetStore.shared.app == .planet {
                Button {
                    PlanetStore.shared.isShowingIconGallery = true
                } label: {
                    Text("Change App Icon")
                }
            }
        }
    }

    @CommandsBuilder
    func writerCommands() -> some Commands {
        CommandMenu("Writer") {
            Group {
                Button {
                    self.activeWriterWindow?.send(nil)
                } label: {
                    Text("Send")
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
                .disabled(activeWriterWindow == nil)

                Divider()
            }

            Group {
                Button {
                    self.activeWriterWindow?.insertEmoji(nil)
                } label: {
                    Text("Insert Emoji")
                }
                .disabled(activeWriterWindow == nil)

                Button {
                    self.activeWriterWindow?.attachPhoto(nil)
                } label: {
                    Text("Attach Photo")
                }
                .disabled(activeWriterWindow == nil)

                Button {
                    self.activeWriterWindow?.attachVideo(nil)
                } label: {
                    Text("Attach Video")
                }
                .disabled(activeWriterWindow == nil)

                Button {
                    self.activeWriterWindow?.attachAudio(nil)
                } label: {
                    Text("Attach Audio")
                }
                .disabled(activeWriterWindow == nil)
            }

            Group {
                Divider()

                Button {
                    self.activeWriterWindow?.draft.attachments.removeAll()
                } label: {
                    Text("Remove Attachments")
                }
                .disabled(activeWriterWindow == nil || activeWriterWindow?.draft.attachments.count == 0)
            }
        }
    }

    @CommandsBuilder
    func toolsCommands() -> some Commands {
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

                publishedFoldersMenus()

                Divider()
            }

            Group {
                Button {
                    PlanetStore.shared.publishMyPlanets()
                } label: {
                    Text("Publish My Planets")
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])

                Button {
                    PlanetStore.shared.updateFollowingPlanets()
                } label: {
                    Text("Update Following Planets")
                }
                .keyboardShortcut("u", modifiers: [.command, .shift])

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

                Button {
                    Task(priority: .background) {
                        do {
                            try await self.activeMyPlanet?.quickRebuild()
                        } catch {
                            Task { @MainActor in
                                PlanetStore.shared.isShowingAlert = true
                                PlanetStore.shared.alertTitle = "Failed to Quick Rebuild Planet"
                                PlanetStore.shared.alertMessage = error.localizedDescription
                            }
                        }
                    }
                } label: {
                    Text("Quick Rebuild Planet")
                }
                .disabled(activeMyPlanet == nil)
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Button {
                    Task(priority: .background) {
                        do {
                            try await self.activeMyPlanet?.rebuild()
                        } catch {
                            Task { @MainActor in
                                PlanetStore.shared.isShowingAlert = true
                                PlanetStore.shared.alertTitle = "Failed to Rebuild Planet"
                                PlanetStore.shared.alertMessage = error.localizedDescription
                            }
                        }
                    }
                } label: {
                    Text("Rebuild Planet")
                }
                .disabled(activeMyPlanet == nil)
                .keyboardShortcut("r", modifiers: [.command])

                Divider()
            }

            Group {
                Button {
                    self.importPlanetAction()
                } label: {
                    Text("Import Planet")
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
            }
        }
    }

    func importPlanetAction() {
        let panel = NSOpenPanel()
        panel.message = "Choose Planet Data"
        panel.prompt = "Import"
        panel.allowsMultipleSelection = false
        let planetDataIdentifier = {
            if let name = Bundle.main.object(forInfoDictionaryKey: "ORGANIZATION_IDENTIFIER_PREFIX") as? String {
                return name + ".planet.data"
            } else {
                return "xyz.planetable.planet.data"
            }
        }()
        panel.allowedContentTypes = [UTType(planetDataIdentifier)!]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.canCreateDirectories = false
        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return }
        Task { @MainActor in
            do {
                let planet = try MyPlanetModel.importBackup(from: url)
                PlanetStore.shared.myPlanets.insert(planet, at: 0)
                PlanetStore.shared.selectedView = .myPlanet(planet)
            } catch {
                PlanetStore.shared.alert(title: "Failed to import planet")
            }
        }
    }

    // MARK: -

    @ViewBuilder
    private func publishedFoldersMenus() -> some View {
        Menu("Published Folders") {
            ForEach(serviceStore.publishedFolders, id: \.id) { folder in
                Menu(folder.url.path.removingPercentEncoding ?? folder.url.path) {
                    if self.serviceStore.publishingFolders.contains(folder.id) {
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
                                        self.openURL(url)
                                    }
                                } label: {
                                    Text("Open in Public Gateway")
                                }
                                Button {
                                    if let url = URL(string: "\(IPFSDaemon.shared.gateway)/ipns/\(publishedLink)") {
                                        self.openURL(url)
                                    }
                                } label: {
                                    Text("Open in Local Gateway")
                                }
                            }
                            Button {
                                do {
                                    let url = try self.serviceStore.restoreFolderAccess(forFolder: folder)
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
                                self.serviceStore.exportFolderKey(folder)
                            } label: {
                                Text("Backup Folder Key")
                            }
                            Divider()
                        }
                        Button {
                            self.serviceStore.addToRemovingPublishedFolderQueue(folder)
                            let updatedFolders = self.serviceStore.publishedFolders.filter { f in
                                return f.id != folder.id
                            }
                            Task { @MainActor in
                                self.serviceStore.updatePublishedFolders(updatedFolders)
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
                self.serviceStore.addFolder()
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
            self.serviceStore.timestamp = Int(Date().timeIntervalSince1970)
            self.serviceStore.updatePendingPublishings()
        }
    }
}
