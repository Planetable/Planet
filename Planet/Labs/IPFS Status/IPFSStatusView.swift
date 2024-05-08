//
//  IPFSStatusView.swift
//  Planet
//

import SwiftUI


struct IPFSStatusView: View {
    @EnvironmentObject private var ipfsState: IPFSState

    @State private var isDaemonOnline: Bool = IPFSState.shared.online

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Text("IPFS Daemon Status")
                    .font(.headline)
                Text(ipfsState.online ? "Online" : "Offline")
                    .foregroundStyle(ipfsState.online ? Color.green : Color.gray)
                    .font(.subheadline)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    .background(Color.secondary.opacity(0.1))
                    .clipped()
                    .cornerRadius(4)
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
            Spacer()
        }
        .padding()
        .frame(minWidth: 320, minHeight: 56)
    }
}

#Preview {
    IPFSStatusView()
        .frame(width: 320, height: 56)
}
