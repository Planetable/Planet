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

    var walletConnect: WalletConnect!

    // MARK: - V1
    func setupV1() {
        walletConnect = WalletConnect(delegate: self)
        walletConnect.reconnectIfNeeded()
    }

    func connectV1() {
        let connectionURL = walletConnect.connect()
        print("WalletConnect V1 URL: \(connectionURL)")
        Task { @MainActor in
            PlanetStore.shared.walletConnectV1ConnectionURL = connectionURL
            PlanetStore.shared.isShowingWalletConnectV1QRCode = true
        }
    }

    // MARK: - V2

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

// MARK: - WalletConnectDelegate

extension WalletManager: WalletConnectDelegate {
    func failedToConnect() {

    }

    func didConnect() {

    }

    func didDisconnect() {

    }
}
