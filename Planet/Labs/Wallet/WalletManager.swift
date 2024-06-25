//
//  WalletManager.swift
//  Planet
//
//  Created by Xin Liu on 11/4/22.
//

import Foundation
import Starscream
import WalletConnectSign
import WalletConnectNetworking
import WalletConnectPairing
import WalletConnectRelay
import WalletConnectSwift
import Web3
import Combine
import CoreImage.CIFilterBuiltins
import CryptoSwift
import HDWalletKit
import Auth


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

    static let coinNames: [Int: String] = [
        1: "ETH",
        5: "GoerliETH",
        11155111: "SEP",
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


class WalletManager: NSObject, ObservableObject {
    static let shared = WalletManager()

    enum SigningState {
        case none
        case signed(Cacao)
        case error(Error)
    }

    static let lastWalletAddressKey: String = "PlanetLastActiveWalletAddressKey"

    var walletConnect: WalletConnect!

    @Published private(set) var uriString: String?
    @Published private(set) var state: SigningState = .none

    private var disposeBag = Set<AnyCancellable>()

    @Published var session: WalletConnectSign.Session? = nil

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
        if let session = self.session {
            if session.peer.name.contains("MetaMask") {
                return "WalletAppIconMetaMask"
            }
            if session.peer.name.contains("Rainbow") {
                return "WalletAppIconRainbow"
            }
        }
        return nil
    }

    func getWalletAppName() -> String {
        if let session = self.session {
            return session.peer.name
        }
        return "WalletConnect 2.0"
        // return self.walletConnect.session.walletInfo?.peerMeta.name ?? "Unknown Wallet"
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

    func setupV2() throws {
        debugPrint("Setting up WalletConnect 2.0")
        if let projectId = Bundle.main.object(forInfoDictionaryKey: "WALLETCONNECTV2_PROJECT_ID") as? String {
            debugPrint("WalletConnect project id: \(projectId)")
            let metadata = AppMetadata(
                name: "Planet",
                description: "Build decentralized websites on ENS",
                url: "https://planetable.xyz",
                icons: ["https://github.com/Planetable.png"],
                redirect: AppMetadata.Redirect(native: "planet://", universal: nil))
            Pair.configure(metadata: metadata)
            Networking.configure(projectId: projectId, socketFactory: DefaultSocketFactory())

            // Set up Sign
            Sign.instance.sessionsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] (sessions: [WalletConnectSign.Session]) in
                debugPrint("WalletConnect 2.0 Sessions: \(sessions)")
                if let session = sessions.first {
                    self.session = session
                    debugPrint("WalletConnect 2.0 session found: \(session)")
                    if let account = session.accounts.first {
                        Task { @MainActor in
                            PlanetStore.shared.walletAddress = account.address
                            UserDefaults.standard.set(account.address, forKey: Self.lastWalletAddressKey)
                            PlanetStore.shared.isShowingWalletConnectV2QRCode = false
                        }
                    }
                }
            }.store(in: &disposeBag)

            Sign.instance.sessionRejectionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] rejection in
                debugPrint("WalletConnect 2.0 Session Rejection: \(rejection)")
                Task { @MainActor in
                    PlanetStore.shared.isShowingWalletConnectV2QRCode = false
                }
            }.store(in: &disposeBag)

            Sign.instance.sessionResponsePublisher
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] response in
                let record = Sign.instance.getSessionRequestRecord(id: response.id)!
                switch response.result {
                case  .response(let response):
                    debugPrint("WalletConnect 2.0 Sign Response: \(response)")
                    // responseView.nameLabel.text = "Received Response\n\(record.request.//method)"
                    // responseView.descriptionLabel.text = try! response.get(String.self).description
                case .error(let error):
                    debugPrint("WalletConnect 2.0 Sign Error: \(error)")
                    // responseView.nameLabel.text = "Received Error\n\(record.request.method)"
                    // responseView.descriptionLabel.text = error.message
                }
                Task { @MainActor in
                    PlanetStore.shared.isShowingWalletConnectV2QRCode = false
                }
            }.store(in: &disposeBag)

            // Set up Auth
            Auth.configure(crypto: DefaultCryptoProvider())
            Auth.instance.authResponsePublisher.sink { [weak self] (_, result) in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let cacao):
                        self?.state = .signed(cacao)
                        debugPrint("WalletConnect 2.0 signed in: \(cacao)")
                        let iss = cacao.p.iss
                        debugPrint("iss: \(iss)")
                        if iss.contains("eip155:1:"), let address = iss.split(separator: ":").last {
                            let walletAddress: String = String(address)
                            PlanetStore.shared.walletAddress = walletAddress
                            UserDefaults.standard.set(walletAddress, forKey: Self.lastWalletAddressKey)
                            // Save paring topic into keychain, with wallet address as key.
                            if let paring = Pair.instance.getPairings().first {
                                do {
                                    try KeychainHelper.shared.saveValue(paring.topic, forKey: walletAddress)
                                    debugPrint("WalletConnect 2.0 topic saved: \(paring.topic), key (wallet address): \(walletAddress)")
                                } catch {
                                    debugPrint("WalletConnect 2.0 topic not saved: \(error)")
                                }
                            }
                        }
                    case .failure(let error):
                        debugPrint("WalletConnect 2.0 not signed, error: \(error)")
                        self?.state = .error(error)
                        PlanetStore.shared.walletAddress = ""
                    }
                    PlanetStore.shared.isShowingWalletConnectV2QRCode = false
                }
            }.store(in: &disposeBag)

            // Restore previous session
            Task { @MainActor in
                debugPrint("WalletConnect 2.0 ready")
                PlanetStore.shared.walletConnectV2Ready = true

                // TODO: code for handling Sign
                // TODO: Since Sign can work with MetaMask, we'll remove Auth after Sign is fully working.

                if let session = Sign.instance.getSessions().first {
                    self.session = session
                    debugPrint("WalletConnect 2.0 session found: \(session)")
                    if let account = session.accounts.first {
                        let address = account.address
                        PlanetStore.shared.walletAddress = address
                        debugPrint("WalletConnect 2.0 account: \(account)")
                        //debugPrint("WalletConnect 2.0 session wallet address: \(address)")
                    }
                } else {
                    debugPrint("WalletConnect 2.0 no session found")
                }

                /* Start: code for handling Auth */
                guard let address: String = UserDefaults.standard.string(forKey: Self.lastWalletAddressKey), address != "" else {
                    debugPrint("WalletConnect 2.0 no previous active wallet found, ignore reconnect.")
                    return
                }
                do {
                    let topic = try KeychainHelper.shared.loadValue(forKey: address)
                    if topic.count > 0 {
                        debugPrint("WalletConnect 2.0 previous active wallet address found: \(address), with topic: \(topic)")
                        // Ping
                        do {
                            try await Pair.instance.ping(topic: topic)
                            PlanetStore.shared.walletAddress = address
                            debugPrint("WalletConnect 2.0 pinged previous active wallet address OK: \(address)")
                        } catch {
                            debugPrint("WalletConnect 2.0 failed to ping previous active wallet address: \(error)")
                        }
                    } else {
                        debugPrint("WalletConnect 2.0 previous active wallet address found: \(address), but topic not found.")
                    }
                } catch {
                    debugPrint("WalletConnect 2.0 failed to restore previous active wallet address and topic: \(error)")
                }
                /* End: code for handling Auth */
            }
        } else {
            debugPrint("WalletConnect 2.0 not ready, missing project id error.")
            throw PlanetError.WalletConnectV2ProjectIDMissingError
        }
    }

    @MainActor
    func connectV2() async throws {
        /*
        Task {
            debugPrint("Attempting to create WalletConnect 2.0 session")
            let uri = try await Pair.instance.create()
            debugPrint("WalletConnect 2.0 URI: \(uri)")
            debugPrint("WalletConnect 2.0 URI Absolute String: \(uri.absoluteString)")
            Task { @MainActor in
                PlanetStore.shared.walletConnectV2ConnectionURL = uri.absoluteString
                PlanetStore.shared.isShowingWalletConnectV2QRCode = true
            }
        }
         */
        state = .none
        uriString = nil
        let uri = try await Pair.instance.create()
        debugPrint("WalletConnect 2.0 URI: \(uri)")
        debugPrint("WalletConnect 2.0 URI Absolute String: \(uri.absoluteString)")
        uriString = uri.absoluteString
        // Auth, new, but MetaMask doesn't support Auth yet.
        // try await Auth.instance.request(.stub(), topic: uri.topic)

        // Sign, simple old connect method that MetaMask supports too.

        let pairingTopic = uri.topic
        let requiredNamespaces: [String: ProposalNamespace] = [
            "eip155": ProposalNamespace(
                chains: [
                    Blockchain("eip155:1")!
                ],
                methods: [
                    "eth_sendTransaction",
                    "personal_sign",
                    "eth_signTypedData"
                ], events: []
            )
        ]
        let optionalNamespaces: [String: ProposalNamespace] = [
            "eip155:42161": ProposalNamespace(
                methods: [
                    "eth_sendTransaction",
                    "eth_signTransaction",
                    "get_balance",
                    "personal_sign"
                ],
                events: ["accountsChanged", "chainChanged"]
            )
        ]

        try await Sign.instance.connect(requiredNamespaces: requiredNamespaces, optionalNamespaces: optionalNamespaces, topic: pairingTopic)

        PlanetStore.shared.walletConnectV2ConnectionURL = uri.absoluteString
        PlanetStore.shared.isShowingWalletConnectV2QRCode = true
    }

    func disconnectV2() async {
        guard let address: String = UserDefaults.standard.string(forKey: Self.lastWalletAddressKey), address != "" else {
            debugPrint("WalletConnect 2.0 no previous active wallet found, ignore reconnect.")
            Task { @MainActor in
                PlanetStore.shared.walletAddress = ""
            }
            return
        }
        do {
            let topic = try KeychainHelper.shared.loadValue(forKey: address)
            try await Pair.instance.disconnect(topic: topic)
            debugPrint("WalletConnect 2.0 disconnected previous active wallet address: \(address)")
        } catch {
            debugPrint("WalletConnect 2.0 failed to disconnect: \(error)")
        }
        Task { @MainActor in
            self.session = nil
            PlanetStore.shared.walletAddress = ""
        }
        UserDefaults.standard.removeObject(forKey: Self.lastWalletAddressKey)
        do {
            try KeychainHelper.shared.delete(forKey: Self.lastWalletAddressKey)
        } catch {
            debugPrint("WalletConnect 2.0 failed to delete previous active wallet address: \(error)")
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

    func stringValue() -> String {
        return String(self)
    }
}

extension RequestParams {
    static func stub(
        domain: String = "service.invalid",
        chainId: String = "eip155:1",
        nonce: String = "32891756",
        aud: String = "https://service.invalid/login",
        nbf: String? = nil,
        exp: String? = nil,
        statement: String? = "I accept the ServiceOrg Terms of Service: https://service.invalid/tos",
        requestId: String? = nil,
        resources: [String]? = ["ipfs://bafybeiemxf5abjwjbikoz4mc3a3dla6ual3jsgpdr4cjr3oz3evfyavhwq/", "https://example.com/my-web2-claim.json"]
    ) -> RequestParams {
        return RequestParams(
            domain: domain,
            chainId: chainId,
            nonce: nonce,
            aud: aud,
            nbf: nbf,
            exp: exp,
            statement: statement,
            requestId: requestId,
            resources: resources
        )
    }
}

extension WebSocket: WebSocketConnecting { }

struct DefaultSocketFactory: WebSocketFactory {
    func create(with url: URL) -> WebSocketConnecting {
        let socket = WebSocket(url: url)
        let queue = DispatchQueue(label: "com.walletconnect.sdk.sockets", attributes: .concurrent)
        socket.callbackQueue = queue
        return socket
    }
}

struct DefaultCryptoProvider: CryptoProvider {
    public func recoverPubKey(signature: EthereumSignature, message: Data) throws -> Data {
        let publicKey = try EthereumPublicKey(
            message: message.bytes,
            v: EthereumQuantity(quantity: BigUInt(signature.v)),
            r: EthereumQuantity(signature.r),
            s: EthereumQuantity(signature.s)
        )
        return Data(publicKey.rawPublicKey)
    }

    public func keccak256(_ data: Data) -> Data {
        let digest = SHA3(variant: .keccak256)
        let hash = digest.calculate(for: [UInt8](data))
        return Data(hash)
    }
}
