//
//  IPFSStatusView.swift
//  Planet
//

import SwiftUI


struct IPFSStatusView: View {
    @EnvironmentObject private var ipfsState: IPFSState

    @State private var isDaemonOnline: Bool = IPFSState.shared.online
    @State private var repoSize: Int64?

    var body: some View {
        VStack(spacing: 0) {
            statusView()
                .padding(.horizontal, 12)
                .padding(.top, 12)

            IPFSTrafficView()
                .frame(height: 96)
                .padding(.horizontal, 12)
                .padding(.top, 12)

            Divider()
                .padding(.top, 12)

            VStack(spacing: 0) {
                HStack {
                    Circle()
                        .frame(width: 11, height: 11, alignment: .center)
                        .foregroundColor(ipfsState.online ? Color.green : Color.red)
                    Text(ipfsState.online ? "Online" : "Offline")
                        .font(.body)
                    Spacer()
                    if ipfsState.isOperating {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .controlSize(.small)
                    } else {
                        Toggle("", isOn: $isDaemonOnline)
                            .toggleStyle(SwitchToggleStyle())
                            .tint(.green)
                            .onChange(of: isDaemonOnline) { newValue in
                                Task.detached(priority: .userInitiated) {
                                    if newValue {
                                        try? await IPFSDaemon.shared.launch()
                                    } else {
                                        try? await IPFSDaemon.shared.shutdown()
                                    }
                                    await IPFSState.shared.updateStatus()
                                    await MainActor.run {
                                        self.isDaemonOnline = newValue
                                    }
                                    UserDefaults.standard.setValue(newValue, forKey: IPFSState.lastUserLaunchState)
                                }
                            }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(height: 44)
        }
        .padding(0)
        .frame(width: 280)
        .task {
            Task.detached(priority: .background) {
                await self.calculateRepoSize()
            }
        }
    }
    
    @ViewBuilder
    private func statusView() -> some View {
        VStack(spacing: 4) {
            HStack {
                Text("Local Gateway")
                Spacer(minLength: 1)
                Link(self.ipfsState.getGateway(), destination: URL(string: self.ipfsState.getGateway())!)
                    .focusable(false)
                    .disabled(!self.ipfsState.online)
            }
            HStack {
                Text("Repo Size")
                Spacer(minLength: 1)
                if let repoSize {
                    let formatter = {
                        let byteCountFormatter = ByteCountFormatter()
                        byteCountFormatter.allowedUnits = .useAll
                        byteCountFormatter.countStyle = .file
                        return byteCountFormatter
                    }()
                    Text(formatter.string(fromByteCount: repoSize))
                }
            }
            HStack {
                Text("Peers")
                Spacer(minLength: 1)
                if self.ipfsState.online, let peers = self.ipfsState.serverInfo?.ipfsPeerCount {
                    Text(String(peers))
                }
            }
            HStack {
                Text("IPFS Version")
                Spacer(minLength: 1)
                Text(self.ipfsState.serverInfo?.ipfsVersion ?? "")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    private func calculateRepoSize() async {
        let repoPath = IPFSCommand.IPFSRepositoryPath
        guard FileManager.default.fileExists(atPath: repoPath.path) else { return }
        var totalSize: Int64 = 0
        let resourceKeys: Set<URLResourceKey> = [.fileSizeKey]
        let enumerator = FileManager.default.enumerator(at: repoPath, includingPropertiesForKeys: Array(resourceKeys))!
        for case let fileURL as URL in enumerator {
            let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys)
            if let fileSize = resourceValues?.fileSize {
                totalSize += Int64(fileSize)
            }
        }
        let updatedTotalSize = totalSize
        await MainActor.run {
            self.repoSize = updatedTotalSize
        }
    }
}
