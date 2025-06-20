//
//  KeyboardShortcutHelper.swift
//  Planet
//
//  Created by Kai on 4/4/23.
//

import Foundation
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
                PlanetStore.shared.isShowingNewOnboarding = true
            } label: {
                Text("What's New in Planet")
            }

            Button {
                Task {
                    try? await FollowingPlanetModel.followFeaturedSources()
                }
            } label: {
                Text("Follow Featured Planets")
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

            Divider()

            if PlanetStore.shared.hasWalletAddress() {
                Button {
                    PlanetStore.shared.isShowingWalletDisconnectConfirmation = true
                } label: {
                    Text("Disconnect Wallet")
                }
            }
            else {
                /* TODO: Remove this button for V1
                Button {
                    WalletManager.shared.connectV1()
                } label: {
                    Text("Connect Wallet")
                }
                */

                if PlanetStore.shared.walletConnectV2Ready {
                    Button {
                        Task { @MainActor in
                            do {
                                try await WalletManager.shared.connectV2()
                            } catch {
                                debugPrint("failed to connect wallet v2: \(error)")
                            }
                        }
                    } label: {
                        Text("Connect Wallet")
                    }
                }
            }

            if PlanetStore.app == .planet {
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
                .disabled(
                    activeWriterWindow == nil || activeWriterWindow?.draft.attachments.count == 0
                )
            }
        }
    }

    @CommandsBuilder
    func toolsCommands() -> some Commands {
        CommandMenu("Tools") {
            Group {
//                Button {
//                    PlanetStore.shared.isShowingIPFSOpen = true
//                } label: {
//                    Text("Open IPFS Resource")
//                }

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

                apiConsoleMenus()

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
                            }
                            catch {
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
                        }
                        catch {
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
                        }
                        catch {
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
                    self.importArticleAction()
                } label: {
                    Text("Import Article")
                }
                .keyboardShortcut("i", modifiers: [.command, .option, .shift])

                Button {
                    self.importPlanetAction()
                } label: {
                    Text("Import Planet")
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])

                Divider()

                Button {
                    Task { @MainActor in
                        PlanetImportManager.shared.importMarkdownFiles()
                    }
                } label: {
                    Text("Import Markdown Files")
                }

                Divider()
            }

            Group {
                Button {
                    Task {
                        do {
                            try await IPFSDaemon.shared.gc()
                        }
                        catch {
                            debugPrint("GC: failed to run gc: \(error)")
                        }
                    }
                } label: {
                    Text("Run IPFS Garbage Collection")
                }
            }
        }
    }

    // MARK: -

    private func importArticleAction() {
        let panel = NSOpenPanel()
        panel.message = "Choose Planet Articles to Import"
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
                try await MyArticleModel.importArticles(fromURLs: panel.urls)
            }
            catch {
                PlanetStore.shared.isShowingAlert = true
                PlanetStore.shared.alertTitle = "Failed to Import Articles"
                switch error {
                case PlanetError.ImportPlanetArticlePublishingError:
                    PlanetStore.shared.alertMessage =
                        "Planet is publishing progress, please try again later."
                default:
                    PlanetStore.shared.alertMessage = error.localizedDescription
                }
            }
        }
    }

    func importPlanetAction() {
        let isCroptopSiteData: Bool = PlanetStore.app == .lite
        let panel = NSOpenPanel()
        if isCroptopSiteData {
            panel.message = "Choose Croptop Site to Import"
        }
        else {
            panel.message = "Choose Planet Data to Import"
        }
        panel.prompt = "Import"
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.package]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.canCreateDirectories = false
        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return }
        Task { @MainActor in
            do {
                let planet = try MyPlanetModel.importBackup(
                    from: url,
                    isCroptopSiteData: isCroptopSiteData
                )
                PlanetStore.shared.myPlanets.insert(planet, at: 0)
                PlanetStore.shared.selectedView = .myPlanet(planet)
            }
            catch {
                let title = isCroptopSiteData ? "Failed to Import Site" : "Failed to Import Planet"
                PlanetStore.shared.alert(title: title, message: error.localizedDescription)
            }
        }
    }

    @ViewBuilder
    private func publishedFoldersMenus() -> some View {
        Menu("Published Folders") {
            ForEach(serviceStore.publishedFolders, id: \.id) { folder in
                Menu(folder.url.path.removingPercentEncoding ?? folder.url.path) {
                    if self.serviceStore.publishingFolders.contains(folder.id) {
                        Text("Publishing ...")
                    }
                    else {
                        if !FileManager.default.fileExists(atPath: folder.url.path) {
                            Text("Folder is missing ...")
                        }
                        else {
                            if let published = folder.published,
                                let publishedLink = folder.publishedLink
                            {
                                Text("Last Published: " + published.relativeDateDescription())
                                Divider()
                                Button {
                                    if let url = URL(
                                        string:
                                            "https://eth.sucks/ipns/\(publishedLink)"
                                    ) {
                                        self.openURL(url)
                                    }
                                } label: {
                                    Text("Open in Public Gateway")
                                }
                                Button {
                                    if let url = URL(
                                        string:
                                            "\(IPFSState.shared.getGateway())/ipns/\(publishedLink)"
                                    ) {
                                        self.openURL(url)
                                    }
                                } label: {
                                    Text("Open in Local Gateway")
                                }
                            }
                            Button {
                                self.serviceStore.revealFolderInFinder(folder)
                            } label: {
                                Text("Reveal in Finder")
                            }
                            Button {
                                Task { @MainActor in
                                    await self.serviceStore.prepareToPublishFolder(
                                        folder,
                                        skipCIDCheck: true
                                    )
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
                            self.serviceStore.fixFolderAccessPermissions(folder)
                        } label: {
                            Text("Refresh Folder Access")
                        }
                        .help("Re-authorize folder access permissions, especially if you moved the folder to a different location.")

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
        }
        .onReceive(serviceStore.timer) { _ in
            self.serviceStore.timestamp = Int(Date().timeIntervalSince1970)
            self.serviceStore.updatePendingPublishings()
        }
    }

    @ViewBuilder
    private func apiConsoleMenus() -> some View {
        PlanetAPIConsoleWindowManager.shared.consoleCommandMenu()
    }
}
