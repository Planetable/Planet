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
    
    @AppStorage(.settingsLibraryLocation) private var libraryLocation: String = UserDefaults.standard.string(forKey: .settingsLibraryLocation) ?? URLUtils.repoPath.path

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
                        Button {
                            let url = URL(fileURLWithPath: libraryLocation)
                            NSWorkspace.shared.open(url)
                        } label: {
                            Image(systemName: "magnifyingglass.circle")
                                .resizable()
                                .frame(width: 12, height: 12)
                        }
                        .buttonStyle(.plain)
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
                        .disabled(URLUtils.repoPath.path == libraryLocation)
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
    }
    
    private func resetLibraryLocation() {
        UserDefaults.standard.removeObject(forKey: .settingsLibraryLocation)
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
        guard response == .OK, let url = panel.url else {
            let alert = NSAlert()
            alert.messageText = "Failed to Choose Library Location"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
            throw PlanetError.InternalError
        }
        let planetURL = url.appendingPathComponent("Planet")
        if FileManager.default.fileExists(atPath: planetURL.path) {
            let alert = NSAlert()
            alert.messageText = "Failed to Choose Library Location"
            alert.informativeText = "\(planetURL.path) already exists."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
            throw PlanetError.InternalError
        }
        let bookmarkKey = url.path.md5()
        let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
        try FileManager.default.copyItem(at: URLUtils.repoPath, to: planetURL)
        UserDefaults.standard.set(url.path, forKey: .settingsLibraryLocation)
    }
}

struct PlanetSettingsGeneralView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetSettingsGeneralView()
    }
}
