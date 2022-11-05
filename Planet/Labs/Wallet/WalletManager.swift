//
//  WalletManager.swift
//  Planet
//
//  Created by Xin Liu on 11/4/22.
//

import Foundation
import Starscream
import WalletConnectNetworking
import WalletConnectRelay
import WalletConnectPairing

extension WebSocket: WebSocketConnecting { }

struct SocketFactory: WebSocketFactory {
    func create(with url: URL) -> WebSocketConnecting {
        return WebSocket(url: url)
    }
}

class WalletManager: NSObject {
    static let shared = WalletManager()

    func setupV2() {
        let metadata = AppMetadata(
            name: "Planet",
            description: "Build decentralized websites on IPFS + ENS",
            url: "wallet.planetable.xyz",
            icons: ["https://www.planetable.xyz/assets/planetable-logo-light.png"])

        // TODO: Read PROJECT_ID from local.xcconfig
        Networking.configure(projectId: "", socketFactory: SocketFactory())
        Pair.configure(metadata: metadata)
    }

    func connectV2() {
        Task {
            let uri = try await Pair.instance.create()
            debugPrint("WalletConnect 2.0 URI: \(uri)")
        }
    }
}
