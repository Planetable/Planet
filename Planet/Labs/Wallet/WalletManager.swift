//
//  WalletManager.swift
//  Planet
//
//  Created by Xin Liu on 11/4/22.
//

import Foundation
import Starscream
import WalletConnectNetworking
import WalletConnectPairing
import WalletConnectRelay
import WalletConnectSwift

enum EthereumChainID: Int, Codable, CaseIterable {
    case mainnet = 1
    case goerli = 5
    case sepolia = 11155111

    var id: Int { return self.rawValue }

    static let names: [Int: String] = [
        1: "Mainnet",
        5: "Goerli",
        11155111: "Sepolia",
    ]

    static let etherscanURL: [Int: String] = [
        1: "https://etherscan.io",
        5: "https://goerli.etherscan.io",
        11155111: "https://sepolia.otterscan.io",
    ]
}

enum TipAmount: Int, Codable, CaseIterable {
    case two = 2
    case five = 5
    case ten = 10
    case twenty = 20
    case hundred = 100

    var id: Int { return self.rawValue }

    var amount: Int { return self.rawValue }

    static let names: [Int: String] = [
        2: "0.02 Ξ",
        5: "0.05 Ξ",
        10: "0.1 Ξ",
        20: "0.2 Ξ",
        100: "1 Ξ",
    ]
}

extension WebSocket: WebSocketConnecting { }

struct SocketFactory: WebSocketFactory {
    func create(with url: URL) -> WebSocketConnecting {
        return WebSocket(url: url)
    }
}

class WalletManager: NSObject {
    static let shared = WalletManager()

    var walletConnect: WalletConnect!

    // MARK: - Common
    func currentNetwork() -> EthereumChainID? {
        let chainId = UserDefaults.standard.integer(forKey: String.settingsEthereumChainId)
        let chain = EthereumChainID.init(rawValue: chainId)
        return chain
    }

    func currentNetworkName() -> String {
        let chainId = self.currentNetwork() ?? .mainnet
        return EthereumChainID.names[chainId.id] ?? "Mainnet"
    }

    func connectedWalletChainId() -> Int? {
        return self.walletConnect.session.walletInfo?.chainId
    }

    func canSwitchNetwork() -> Bool {
        return self.walletConnect.session.walletInfo?.peerMeta.name.contains("MetaMask") ?? false
    }

    func etherscanURLString(tx: String, chain: EthereumChainID? = nil) -> String {
        let chain = chain ?? WalletManager.shared.currentNetwork()
        switch (chain) {
        case .mainnet:
            return "https://etherscan.io/tx/" + tx
        case .goerli:
            return "https://goerli.etherscan.io/tx/" + tx
        case .sepolia:
            return "https://sepolia.otterscan.io/tx/" + tx
        default:
            return "https://etherscan.io/tx/" + tx
        }
    }

    func etherscanURLString(address: String, chain: EthereumChainID? = nil) -> String {
        let chain = chain ?? WalletManager.shared.currentNetwork()
        switch (chain) {
        case .mainnet:
            return "https://etherscan.io/address/" + address
        case .goerli:
            return "https://goerli.etherscan.io/address/" + address
        case .sepolia:
            return "https://sepolia.otterscan.io/address/" + address
        default:
            return "https://etherscan.io/address/" + address
        }
    }

    func getWalletAppImageName() -> String? {
        if let walletInfo = self.walletConnect.session.walletInfo {
            if walletInfo.peerMeta.name.contains("MetaMask") {
                return "WalletAppIconMetaMask"
            }
            if walletInfo.peerMeta.name.contains("Rainbow") {
                return "WalletAppIconRainbow"
            }
        }
        return nil
    }

    func getWalletAppName() -> String {
        return self.walletConnect.session.walletInfo?.peerMeta.name ?? "Unknown Wallet"
    }

    // MARK: - V1
    func setupV1() {
        walletConnect = WalletConnect(delegate: self)
        walletConnect.reconnectIfNeeded()
        if let session = walletConnect.session {
            debugPrint("Found existing session: \(session)")
            Task { @MainActor in
                PlanetStore.shared.walletAddress = session.walletInfo?.accounts[0] ?? ""
                debugPrint("Wallet Address: \(PlanetStore.shared.walletAddress)")
            }
        }
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
            icons: ["https://github.com/Planetable.png"])

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
        Task { @MainActor in
            debugPrint("Failed to connect: \(self)")
        }
    }

    func didConnect() {
        Task { @MainActor in
            PlanetStore.shared.isShowingWalletConnectV1QRCode = false
            PlanetStore.shared.walletAddress = self.walletConnect.session.walletInfo?.accounts[0] ?? ""
            debugPrint("Wallet Address: \(PlanetStore.shared.walletAddress)")
            debugPrint("Session: \(self.walletConnect.session)")
        }
    }

    func didDisconnect() {
        Task { @MainActor in
            PlanetStore.shared.walletAddress = ""
        }
    }
}

extension PlanetStore {
    func hasWalletAddress() -> Bool {
        if walletAddress.count > 0 {
            return true
        } else {
            return false
        }
    }
}

// MARK: Extension for Int

extension Int {
    func showAsEthers() -> String {
        var ethers: Float = Float(self) / 100
        return String(format: "%.2f Ξ", ethers)
    }
}
