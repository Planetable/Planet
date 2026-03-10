//
//  PlanetSettingsGeneralView.swift
//  Planet
//
//  Created by Kai on 9/11/22.
//

import SwiftUI

struct PlanetSettingsGeneralView: View {
    private enum Layout {
        static let menuWidth: CGFloat = 220
        static let segmentedWidth: CGFloat = 280
    }

    @EnvironmentObject private var viewModel: PlanetSettingsViewModel

    @State private var libraryLocation: String = URLUtils.repoPath().path {
        didSet {
            Task(priority: .userInitiated) {
                await MainActor.run {
                    do {
                        try PlanetStore.shared.load()
                        try TemplateStore.shared.load()
                        PlanetStore.shared.selectedArticle = nil
                        PlanetStore.shared.selectedView = nil
                        PlanetStore.shared.selectedArticleList = nil
                        PlanetStore.shared.refreshSelectedArticles()
                    }
                    catch {
                        debugPrint("failed to reload: \(error)")
                    }
                }
            }
        }
    }

    @AppStorage(String.settingsPreferredIPFSPublicGateway) private var preferredIPFSPublicGateway:
        String =
            UserDefaults.standard.string(forKey: String.settingsPreferredIPFSPublicGateway)
            ?? IPFSGateway.defaultGateway.rawValue

    @AppStorage(String.settingsEthereumChainId) private var ethereumChainId: Int = UserDefaults
        .standard.integer(forKey: String.settingsEthereumChainId)

    @AppStorage(String.settingsWarnBeforeQuitIfPublishing) private var warnBeforeQuitIfPublishing = false

    @AppStorage(String.settingsPreventSleep) private var preventSleep = true

    var body: some View {
        Form {
            Section {
                PlanetSettingsContainer {
                    if PlanetStore.app == .planet {
                        VStack(alignment: .leading, spacing: PlanetSettingsSharedLayout.descriptionSpacing) {
                            PlanetSettingsRow("Library Location", alignment: .top) {
                                Text(libraryLocation)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .help(libraryLocation)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        let url = URL(fileURLWithPath: libraryLocation)
                                        NSWorkspace.shared.open(url)
                                    }
                            }
                            PlanetSettingsControlRow {
                                HStack(spacing: PlanetSettingsSharedLayout.buttonSpacing) {
                                    Button {
                                        do {
                                            try updateLibraryLocation()
                                        }
                                        catch {
                                            resetLibraryLocation()
                                            let alert = NSAlert()
                                            alert.messageText = "Failed to Change Library Location"
                                            alert.informativeText = error.localizedDescription
                                            alert.alertStyle = .informational
                                            alert.addButton(withTitle: "OK")
                                            alert.runModal()
                                        }
                                    } label: {
                                        Text("Change...")
                                    }
                                    Button {
                                        resetLibraryLocation()
                                    } label: {
                                        Text("Reset")
                                    }
                                    .disabled(URLUtils.repoPath() == URLUtils.defaultRepoPath)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    PlanetSettingsRow("IPFS Public Gateway") {
                        Picker("", selection: $preferredIPFSPublicGateway) {
                            ForEach(IPFSGateway.allCases, id: \.self) { gateway in
                                Text(IPFSGateway.names[gateway.rawValue] ?? gateway.rawValue)
                                    .tag(gateway.rawValue)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: Layout.menuWidth, alignment: .leading)
                        .onChange(of: preferredIPFSPublicGateway) { _ in
                            NotificationCenter.default.post(
                                name: .dashboardRefreshToolbar,
                                object: nil
                            )
                        }
                    }

                    VStack(alignment: .leading, spacing: PlanetSettingsSharedLayout.descriptionSpacing) {
                        PlanetSettingsControlRow {
                            Toggle("Warn before quit", isOn: $warnBeforeQuitIfPublishing)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        PlanetSettingsDescriptionRow(
                            "Warn before quitting Planet when there are publishing tasks in progress."
                        )
                    }

                    PlanetSettingsControlRow {
                        Toggle("Prevent computer sleep when the app is running", isOn: $preventSleep)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .onChange(of: preventSleep) { newValue in
                                if newValue {
                                    SleepPreventer.shared.enable()
                                } else {
                                    SleepPreventer.shared.disable()
                                }
                            }
                    }

                    #if DEBUG
                        if PlanetStore.app == .planet {
                            VStack(alignment: .leading, spacing: PlanetSettingsSharedLayout.descriptionSpacing) {
                                PlanetSettingsRow("Ethereum Network") {
                                    Picker("", selection: $ethereumChainId) {
                                        ForEach(EthereumChainID.allCases, id: \.id) { value in
                                            Text(
                                                "\(EthereumChainID.names[value.rawValue] ?? "Unknown Chain ID \(value.rawValue)")"
                                            )
                                            .tag(value)
                                        }
                                    }
                                    .labelsHidden()
                                    .pickerStyle(.segmented)
                                    .frame(width: Layout.segmentedWidth, alignment: .leading)
                                }
                                PlanetSettingsDescriptionRow(
                                    "When you tip a creator, transactions will be sent to the selected Ethereum network."
                                )
                            }
                        }
                    #endif
                }
            }

            Spacer()
        }
        .padding()
        .task {
            if libraryLocation == "" || !FileManager.default.fileExists(atPath: libraryLocation) {
                resetLibraryLocation()
            }
        }
    }

    private func resetLibraryLocation() {
        UserDefaults.standard.removeObject(forKey: .settingsLibraryLocation)
        libraryLocation = URLUtils.repoPath().path
    }

    private func updateLibraryLocation() throws {
        let panel = NSOpenPanel()
        panel.message = "Choose Library Location"
        panel.prompt = "Choose"
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.folder]
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return }
        let planetURL = url.appendingPathComponent("Planet")
        var useAsExistingLibraryLocation: Bool = false
        if FileManager.default.fileExists(atPath: planetURL.path) {
            useAsExistingLibraryLocation = true
        }
        if useAsExistingLibraryLocation {
            let alert = NSAlert()
            alert.messageText = "Existing Planet Library Found"
            alert.alertStyle = .warning
            alert.informativeText =
                "Would you like to use new library location at: \(url.path), current database including following planets will be replaced with contents at this location."
            alert.addButton(withTitle: "Cancel")
            alert.addButton(withTitle: "Continue & Update")
            let result = alert.runModal()
            if result == .alertFirstButtonReturn {
                return
            }
        }
        let bookmarkKey = url.path.md5()
        let bookmarkData = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
        if !useAsExistingLibraryLocation {
            try FileManager.default.copyItem(at: URLUtils.repoPath(), to: planetURL)
        }
        UserDefaults.standard.set(url.path, forKey: .settingsLibraryLocation)
        libraryLocation = URLUtils.repoPath().path
    }
}

struct PlanetSettingsGeneralView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetSettingsGeneralView()
    }
}
