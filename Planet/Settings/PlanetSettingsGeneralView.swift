//
//  PlanetSettingsGeneralView.swift
//  Planet
//
//  Created by Kai on 9/11/22.
//

import SwiftUI

struct PlanetSettingsGeneralView: View {
    let CAPTION_WIDTH: CGFloat = 120

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
                    } catch {
                        debugPrint("failed to reload: \(error)")
                    }
                }
            }
            /*
            // Update library path monitoring
            if URLUtils.repoPath().path == libraryLocation {
                PlanetPublishedServiceStore.shared.stopRepoPathMonitoring()
            } else {
                PlanetPublishedServiceStore.shared.startRepoPathMonitoring(targetURL: URLUtils.repoPath())
            }
             */
        }
    }

    @AppStorage(String.settingsPublicGatewayIndex) private var publicGatewayIndex: Int =
        UserDefaults.standard.integer(forKey: String.settingsPublicGatewayIndex)

    @AppStorage(String.settingsEthereumChainId) private var ethereumChainId: Int = UserDefaults
        .standard.integer(forKey: String.settingsEthereumChainId)

    var body: some View {
        Form {
            Section {
                VStack(spacing: 20) {
                    HStack(spacing: 12) {
                        Text("Library Location")
                            .frame(width: CAPTION_WIDTH, alignment: .trailing)
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
                            .frame(width: CAPTION_WIDTH, alignment: .trailing)
                        Button {
                            do {
                                try updateLibraryLocation()
                            } catch {
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

                    HStack(spacing: 4) {
                        Text("Public Gateway")
                            .frame(width: CAPTION_WIDTH, alignment: .trailing)
                        Picker(selection: $publicGatewayIndex, label: Text("")) {
                            ForEach(0..<IPFSDaemon.publicGateways.count, id: \.self) { index in
                                Text(IPFSDaemon.publicGateways[index])
                                    .tag(index)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: publicGatewayIndex) { newValue in
                            // Refresh Published Folders Dashboard Toolbar
                            NotificationCenter.default.post(name: .dashboardRefreshToolbar, object: nil)
                        }
                    }

                    VStack {
                        HStack(spacing: 4) {
                            Text("Ethereum Network")
                                .frame(width: CAPTION_WIDTH, alignment: .trailing)
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
                        HStack {
                            Text("")
                                .frame(width: CAPTION_WIDTH)
                            Text(
                                "When you tip a creator, transactions will be sent to the selected Ethereum network."
                            )
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        }

                    }

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
        let bookmarkKey = url.path.md5()
        let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
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
