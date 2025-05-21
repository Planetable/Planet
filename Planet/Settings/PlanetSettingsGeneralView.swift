//
//  PlanetSettingsGeneralView.swift
//  Planet
//
//  Created by Kai on 9/11/22.
//

import SwiftUI

struct PlanetSettingsGeneralView: View {
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

    var body: some View {
        Form {
            Section {
                VStack(spacing: 20) {
                    if PlanetStore.app == .planet {
                        HStack(spacing: 12) {
                            Text("Library Location")
                                .frame(width: PlanetUI.SETTINGS_CAPTION_WIDTH, alignment: .trailing)
                            Text(libraryLocation)
                                .lineLimit(3)
                                .onTapGesture {
                                    let url = URL(fileURLWithPath: libraryLocation)
                                    NSWorkspace.shared.open(url)
                                }
                            Spacer(minLength: 1)
                        }
                        HStack(spacing: 12) {
                            Spacer()
                                .frame(width: PlanetUI.SETTINGS_CAPTION_WIDTH, alignment: .trailing)
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
                            Spacer()
                        }
                        .padding(.top, -10)
                    }

                    HStack(spacing: 4) {
                        Text("IPFS Public Gateway")
                            .frame(width: PlanetUI.SETTINGS_CAPTION_WIDTH, alignment: .trailing)
                        Picker(selection: $preferredIPFSPublicGateway, label: Text("")) {
                            ForEach(IPFSGateway.allCases, id: \.self) { gateway in
                                Text(IPFSGateway.names[gateway.rawValue] ?? gateway.rawValue)
                                    .tag(gateway.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: preferredIPFSPublicGateway) { newValue in
                            // Refresh Published Folders Dashboard Toolbar
                            NotificationCenter.default.post(
                                name: .dashboardRefreshToolbar,
                                object: nil
                            )
                        }
                    }

                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Spacer()
                                .frame(width: PlanetUI.SETTINGS_CAPTION_WIDTH + 10, alignment: .trailing)
                            Toggle("Warn before quit", isOn: $warnBeforeQuitIfPublishing)
                            Spacer()
                        }

                        Text(
                            "Warn before quitting Planet when there are publishing tasks in progress."
                        )
                        .frame(minHeight: 40)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.leading, PlanetUI.SETTINGS_CAPTION_WIDTH - 10)
                    }

                    #if DEBUG
                        if PlanetStore.app == .planet {
                            VStack(spacing: 4) {
                                HStack(spacing: 4) {
                                    Text("Ethereum Network")
                                        .frame(
                                            width: PlanetUI.SETTINGS_CAPTION_WIDTH,
                                            alignment: .trailing
                                        )
                                    Picker(selection: $ethereumChainId, label: Text("")) {
                                        ForEach(EthereumChainID.allCases, id: \.id) { value in
                                            Text(
                                                "\(EthereumChainID.names[value.rawValue] ?? "Unknown Chain ID \(value.rawValue)")"
                                            )
                                            .tag(value)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                }
                                Text(
                                    "When you tip a creator, transactions will be sent to the selected Ethereum network."
                                )
                                .frame(minHeight: 40)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .padding(.leading, PlanetUI.SETTINGS_CAPTION_WIDTH + 10)
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
        // prompt to user when existing planet library location found:
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
