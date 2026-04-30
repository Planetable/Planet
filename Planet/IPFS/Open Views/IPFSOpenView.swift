//
//  IPFSOpenView.swift
//  Planet
//
//  Created by Livid on 5/15/24.
//

import SwiftUI

/// Simple view for opening CID, IPNS, or ENS with the local IPFS gateway
struct IPFSOpenView: View {
    @Environment(\.dismiss) private var dismiss
    @State var destination: String = ""
    @State var detectedType: String = " "
    private let PADDING: CGFloat = 10

    var body: some View {
        VStack(spacing: 10) {
            TextField("Open CID, IPNS, or ENS with the local IPFS gateway", text: $destination)
                .disableAutocorrection(true)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    open()
                }
                .onChange(of: destination) { newValue in
                    detect()
                }

            HStack {
                Text($detectedType.wrappedValue)
                    .foregroundColor(.secondary)
                    .font(.caption)
                Spacer()
                Button {
                    open()
                } label: {
                    Text("Open")
                }
            }
        }
        .padding(.top, PADDING)
        .padding(.bottom, PADDING)
        .padding(.leading, PADDING)
        .padding(.trailing, PADDING)
        .frame(minWidth: 450, idealWidth: 600, maxWidth: 680)
    }

    private func detect() {
        if destination.hasPrefix("k51qaz") && destination.count == 62 {
            detectedType = "IPNS"
        }
        else if destination.hasPrefix("bafy") && destination.count == 59 {
            detectedType = "CIDv1"
        }
        else if destination.hasPrefix("Qm") && destination.count == 46 {
            detectedType = "CIDv0"
        }
        else if destination.hasSuffix(".eth") {
            detectedType = "ENS"
        }
        else if destination.hasSuffix(".sol") {
            detectedType = L10n("Solana Name")
        }
        else {
            detectedType = " "
        }
    }

    private func open() {
        let localGateway = IPFSState.shared.getGateway()
        if destination.hasPrefix("k51qaz") && destination.count == 62 {
            // IPNS
            if let url = URL(string: "\(localGateway)/ipns/\(destination)") {
                NSWorkspace.shared.open(url)
            }
        }
        else if destination.hasPrefix("bafy") && destination.count == 59 {
            // CIDv1
            if let url = URL(string: "\(localGateway)/ipfs/\(destination)") {
                NSWorkspace.shared.open(url)
            }
        }
        else if destination.hasPrefix("Qm") && destination.count == 46 {
            // CIDv0
            if let url = URL(string: "\(localGateway)/ipfs/\(destination)") {
                NSWorkspace.shared.open(url)
            }
        }
        else if destination.hasSuffix(".eth") {
            // ENS
            if let url = URL(string: "\(localGateway)/ipns/\(destination)") {
                NSWorkspace.shared.open(url)
            }
        }
        else if destination.hasSuffix(".sol") {
            // ENS
            if let url = URL(string: "\(localGateway)/ipns/\(destination)") {
                NSWorkspace.shared.open(url)
            }
        }
        else {
            if let url = URL(string: "\(localGateway)/ipns/\(destination)") {
                NSWorkspace.shared.open(url)
            }
        }
        // TODO: What if user simply pastes an http:// or https:// link?
        IPFSOpenWindowManager.shared.close()
    }
}

#Preview {
    IPFSOpenView()
}

struct IPFSIdentitySheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var ipfsState = IPFSState.shared

    @State private var idInfo: IPFSID?
    @State private var errorMessage: String?
    @State private var isLoading = true
    @State private var copiedValue: String?

    var body: some View {
        VStack(spacing: PlanetUI.CONTROL_ROW_SPACING) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("IPFS ID")
                        .font(.title3.weight(.semibold))
                }
                Spacer()
            }

            GroupBox {
                content
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 8) {
                if copiedValue != nil {
                    Text("Copied to clipboard.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    Task {
                        await loadIdentity()
                    }
                } label: {
                    Text("Refresh")
                }
                .disabled(isLoading)

                Button {
                    dismiss()
                } label: {
                    Text("OK")
                        .frame(minWidth: PlanetUI.BUTTON_MIN_WIDTH_SHORT)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(PlanetUI.SHEET_PADDING)
        .frame(width: 760, height: 520, alignment: .top)
        .task {
            await loadIdentity()
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            VStack(spacing: 12) {
                Spacer()
                ProgressView()
                Text("Loading IPFS ID...")
                    .foregroundColor(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        else if let errorMessage {
            VStack(spacing: 12) {
                Spacer()
                Text("Unable to load IPFS ID.")
                    .font(.headline)
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    Task {
                        await loadIdentity()
                    }
                } label: {
                    Text("Try Again")
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        else if let idInfo {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    IPFSIdentityValueRow(
                        title: "Peer ID",
                        value: idInfo.id,
                        copiedValue: copiedValue
                    ) {
                        copy(idInfo.id)
                    }

                    IPFSIdentityValueRow(
                        title: "Agent",
                        value: idInfo.agentVersion ?? "Unavailable",
                        copiedValue: copiedValue,
                        canCopy: idInfo.agentVersion != nil
                    ) {
                        if let agentVersion = idInfo.agentVersion {
                            copy(agentVersion)
                        }
                    }

                    IPFSIdentityValueRow(
                        title: "Public Key",
                        value: idInfo.publicKey,
                        copiedValue: copiedValue
                    ) {
                        copy(idInfo.publicKey)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Addresses")
                            .font(.headline)
                        Text("Click any row to copy that address.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if idInfo.addresses.isEmpty {
                            Text("No addresses reported.")
                                .foregroundColor(.secondary)
                        }
                        else {
                            ForEach(Array(idInfo.addresses.enumerated()), id: \.offset) { _, address in
                                Button {
                                    copy(address)
                                } label: {
                                    HStack(spacing: 10) {
                                        Text(address.lineBreakAnywhere())
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(.primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .multilineTextAlignment(.leading)
                                            .fixedSize(horizontal: false, vertical: true)

                                        if copiedValue == address {
                                            Text("Copied")
                                                .font(.caption)
                                                .foregroundColor(.accentColor)
                                        }
                                        else {
                                            Image(systemName: "doc.on.doc")
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                                .help("Copy address")
                            }
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Protocols")
                            .font(.headline)

                        if let protocols = idInfo.protocols, !protocols.isEmpty {
                            ForEach(Array(protocols.enumerated()), id: \.offset) { _, protocolName in
                                Text(protocolName)
                                    .font(.system(size: 11, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(8)
                            }
                        }
                        else {
                            Text("No protocols reported.")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func loadIdentity() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
            idInfo = nil
        }

        do {
            let identity = try await IPFSDaemon.shared.getID()
            await MainActor.run {
                idInfo = identity
                isLoading = false
            }
        }
        catch {
            await MainActor.run {
                let details = ipfsState.online
                    ? error.localizedDescription
                    : "The local IPFS daemon is offline."
                errorMessage = "\(details) Make sure the local IPFS daemon is running, then try again."
                isLoading = false
            }
        }
    }

    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        copiedValue = value
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if copiedValue == value {
                copiedValue = nil
            }
        }
    }
}

private extension String {
    func lineBreakAnywhere() -> String {
        self.map(String.init).joined(separator: "\u{200B}")
    }
}

private struct IPFSIdentityValueRow: View {
    let title: String
    let value: String
    let copiedValue: String?
    let canCopy: Bool
    let copyAction: () -> Void

    init(
        title: String,
        value: String,
        copiedValue: String?,
        canCopy: Bool = true,
        copyAction: @escaping () -> Void
    ) {
        self.title = title
        self.value = value
        self.copiedValue = copiedValue
        self.canCopy = canCopy
        self.copyAction = copyAction
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.headline)
                .frame(width: 88, alignment: .leading)

            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)

            Button {
                copyAction()
            } label: {
                if copiedValue == value {
                    Text("Copied")
                }
                else {
                    Image(systemName: "doc.on.doc")
                }
            }
            .buttonStyle(.plain)
            .disabled(!canCopy)
            .help("Copy \(title)")
        }
    }
}
