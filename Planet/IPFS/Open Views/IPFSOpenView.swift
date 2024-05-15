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

    var body: some View {
        VStack {
            TextField("Open CID, IPNS, or ENS with the local IPFS gateway", text: $destination)
                .disableAutocorrection(true)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button {
                    open()
                } label: {
                    Text("Open")
                }
            }
        }
        .padding(10)
        .frame(minWidth: 300, idealWidth: 480, maxWidth: 600, minHeight: 64, idealHeight: 84, maxHeight: 120)
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
        else {
            if let url = URL(string: "\(localGateway)/ipfs/\(destination)") {
                NSWorkspace.shared.open(url)
            }
        }
        IPFSOpenWindowManager.shared.close()
    }
}

#Preview{
    IPFSOpenView()
}
