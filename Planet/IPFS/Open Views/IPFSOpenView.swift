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
            detectedType = "Solana Name"
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
