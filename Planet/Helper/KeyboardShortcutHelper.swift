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
    @ObservedObject private var ipfsState: IPFSState

    @Published var activeWriterWindow: WriterWindow?
    @Published var activeMyPlanet: MyPlanetModel?

    init() {
        _updater = ObservedObject(wrappedValue: PlanetUpdater.shared)
        _serviceStore = ObservedObject(wrappedValue: PlanetPublishedServiceStore.shared)
        _ipfsState = ObservedObject(wrappedValue: IPFSState.shared)
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

            Divider()

            Button {
                if let url = URL(string: "https://github.com/sponsors/Planetable") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Text("Sponsor @Planetable on GitHub")
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
                Button {
                    PlanetStore.shared.isShowingIPFSID = true
                } label: {
                    Text("Show IPFS ID")
                }
                .disabled(!ipfsState.online)

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

                Button {
                    self.installCLIAction()
                } label: {
                    Text("Install CLI")
                }

                Button {
                    AppLogWindowManager.shared.open()
                } label: {
                    Text("Log")
                }

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
                                PlanetStore.shared.alertTitle = L10n("Failed to Quick Rebuild Planet")
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
                                PlanetStore.shared.alertTitle = L10n("Failed to Rebuild Planet")
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

    private func installCLIAction() {
        if installedCLILinksToBundledCLI {
            do {
                try runCLIInstall()
                presentCLIAlreadyInstalledAlert()
            }
            catch {
                presentCLIInstallError(error)
            }
            return
        }

        let alert = NSAlert()
        alert.messageText = L10n("Install CLI")
        alert.informativeText = L10n("Install the pn CLI to ~/.local/bin so it becomes available in Terminal?")
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n("Install"))
        alert.addButton(withTitle: L10n("Cancel"))

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            try runCLIInstall()
            presentCLIInstalledAlert(
                messageText: L10n("CLI Installed"),
                informativeText: L10n("A symbolic link for pn has been installed at ~/.local/bin/pn and can be used in Terminal.")
            )
        }
        catch {
            presentCLIInstallError(error)
        }
    }

    private var installedCLILinksToBundledCLI: Bool {
        guard let destination = try? FileManager.default.destinationOfSymbolicLink(atPath: cliInstallURL.path) else {
            return false
        }
        let destinationURL = destination.hasPrefix("/")
            ? URL(fileURLWithPath: destination)
            : cliInstallURL.deletingLastPathComponent().appendingPathComponent(destination)
        return destinationURL.standardizedFileURL.resolvingSymlinksInPath().path
            == bundledCLIURL.resolvingSymlinksInPath().path
    }

    private var cliInstallDirectory: URL {
        cliRealHomeDirectory.appendingPathComponent(".local/bin", isDirectory: true)
    }

    // In the sandbox, homeDirectoryForCurrentUser points to the app container;
    // the CLI must be installed relative to the user's real home directory.
    private var cliRealHomeDirectory: URL {
        if let home = getpwuid(getuid())?.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: home), isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    private var cliInstallURL: URL {
        cliInstallDirectory.appendingPathComponent("pn", isDirectory: false)
    }

    // pn is embedded in Contents/Helpers, which url(forAuxiliaryExecutable:)
    // does not search.
    private var bundledCLIURL: URL {
        Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers/pn", isDirectory: false)
    }

    private func runCLIInstall() throws {
        let cliURL = bundledCLIURL
        guard FileManager.default.isExecutableFile(atPath: cliURL.path) else {
            throw CLIInstallError.helperNotFound
        }

        let process = Process()
        let outputPipe = Pipe()
        process.executableURL = cliURL
        process.arguments = ["install", "--to", cliInstallDirectory.path]
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard process.terminationStatus == 0 else {
            throw CLIInstallError.installFailed(output ?? L10n("pn install failed."))
        }
    }

    private func presentCLIAlreadyInstalledAlert() {
        presentCLIInstalledAlert(
            messageText: L10n("CLI Already Installed"),
            informativeText: L10n("A symbolic link for pn is already installed at ~/.local/bin/pn and can be used in Terminal.")
        )
    }

    private func presentCLIInstallError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = L10n("Failed to Install CLI")
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n("OK"))
        alert.runModal()
    }

    private func presentCLIInstalledAlert(messageText: String, informativeText: String) {
        let alert = NSAlert()
        alert.messageText = messageText
        alert.informativeText = informativeText
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n("OK"))
        alert.addButton(withTitle: L10n("Open Terminal"))

        if alert.runModal() == .alertSecondButtonReturn {
            openTerminal()
        }
    }

    private func openTerminal() {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else {
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration, completionHandler: nil)
    }

    // MARK: -

    private func importArticleAction() {
        let panel = NSOpenPanel()
        panel.message = L10n("Choose Planet Articles to Import")
        panel.prompt = L10n("Import")
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
                PlanetStore.shared.alertTitle = L10n("Failed to Import Articles")
                switch error {
                case PlanetError.ImportPlanetArticlePublishingError:
                    PlanetStore.shared.alertMessage =
                        L10n("Planet is publishing progress, please try again later.")
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
            panel.message = L10n("Choose Croptop Site to Import")
        }
        else {
            panel.message = L10n("Choose Planet Data to Import")
        }
        panel.prompt = L10n("Import")
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
                                Text(L10n("Last Published: ") + published.relativeDateDescription())
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

private enum CLIInstallError: LocalizedError {
    case helperNotFound
    case installFailed(String)

    var errorDescription: String? {
        switch self {
        case .helperNotFound:
            return L10n("The bundled pn helper could not be found.")
        case .installFailed(let output):
            return output.isEmpty ? L10n("pn install failed.") : output
        }
    }
}
