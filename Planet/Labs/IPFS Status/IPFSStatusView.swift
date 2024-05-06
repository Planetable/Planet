//
//  IPFSStatusView.swift
//  Planet
//

import SwiftUI


struct IPFSStatusView: View {
    @StateObject private var ipfsState: IPFSState

    @State private var isDaemonOnline: Bool = false

    init() {
        _ipfsState = StateObject(wrappedValue: IPFSState.shared)
    }

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
                }
            }
            Spacer()
        }
        .padding()
        .frame(minWidth: 320, minHeight: 60)
        .task {
            isDaemonOnline = ipfsState.online
        }
    }
}

#Preview {
    IPFSStatusView()
        .frame(width: 320, height: 160)
}
