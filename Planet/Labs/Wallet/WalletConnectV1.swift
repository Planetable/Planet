//
//  WalletConnectV1.swift
//  Planet
//
//  Created by Xin Liu on 11/8/22.
//

import Foundation
import SwiftUI
import WalletConnectSwift

protocol WalletConnectDelegate {
    func failedToConnect()
    func didConnect()
    func didDisconnect()
}

class WalletConnect {
    var client: Client!
    var session: Session!
    var delegate: WalletConnectDelegate

    let sessionKey = "WalletConnectV1SessionKey"

    init(delegate: WalletConnectDelegate) {
        self.delegate = delegate
    }

    func connect() throws -> String {
        // gnosis wc bridge: https://safe-walletconnect.safe.global/
        guard let bridgeURL = URL(string: "https://safe-walletconnect.safe.global/"),
              let iconURL = URL(string: "https://github.com/Planetable.png"),
              let appURL = URL(string: "https://planetable.xyz")
        else {
            throw PlanetError.InternalError
        }
        let wcUrl = WCURL(
            topic: UUID().uuidString,
            bridgeURL: bridgeURL,
            key: try randomKey()
        )
        let clientMeta = Session.ClientMeta(
            name: "Planet",
            description: "Build and host decentralized websites",
            icons: [iconURL],
            url: appURL
        )
        let dAppInfo = Session.DAppInfo(peerId: UUID().uuidString, peerMeta: clientMeta)
        client = Client(delegate: self, dAppInfo: dAppInfo)

        print("WalletConnect URL: \(wcUrl.absoluteString)")

        try client.connect(to: wcUrl)
        return wcUrl.absoluteString
    }

    func reconnectIfNeeded() {
        if let oldSessionObject = UserDefaults.standard.object(forKey: sessionKey) as? Data,
            let session = try? JSONDecoder().decode(Session.self, from: oldSessionObject)
        {
            client = Client(delegate: self, dAppInfo: session.dAppInfo)
            if let _ = try? client.reconnect(to: session) {
                self.session = session
            }
        }
    }

    // https://developer.apple.com/documentation/security/1399291-secrandomcopybytes
    private func randomKey() throws -> String {
        var bytes = [Int8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status == errSecSuccess {
            return Data(bytes: bytes, count: 32).toHexString()
        }
        else {
            // we don't care in the example app
            enum TestError: Error {
                case unknown
            }
            throw TestError.unknown
        }
    }

    private func handleResponse(_ response: Response, expecting: String) {
        DispatchQueue.main.async {
            if let error = response.error {
                debugPrint("Transaction Error: \(error.localizedDescription)")
                return
            }
            do {
                let result = try response.result(as: String.self)
                debugPrint("Transaction Result: \(expecting) - \(result)")
                if result.hasPrefix("0x") {
                    // Open etherscan.io after 1 second
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        if let etherscanURL: URL = URL(
                            string: WalletManager.shared.etherscanURLString(tx: result)
                        ) {
                            NSWorkspace.shared.open(etherscanURL)
                        }
                    }
                }
            }
            catch {
                debugPrint("Transaction Error: Unexpected response type error: \(error)")
            }
        }
    }

    private var walletAccount: String? {
        session?.walletInfo?.accounts.first
    }

    private func nonceRequest() -> Request? {
        guard let session, let account = walletAccount else {
            debugPrint("WalletConnect V1 missing session account")
            return nil
        }
        return try? .eth_getTransactionCount(url: session.url, account: account)
    }

    private func nonce(from response: Response) -> String? {
        return try? response.result(as: String.self)
    }

    // MARK: - Send Transaction

    func sendTransaction(receiver: String, amount: Int, memo: String, ens: String? = nil) {
        guard let client, let request = nonceRequest() else {
            delegate.failedToConnect()
            return
        }
        try? client.send(request) { [weak self] response in
            guard let self = self, let nonce = self.nonce(from: response) else { return }
            guard let account = self.walletAccount else {
                self.delegate.failedToConnect()
                return
            }
            let transaction = self.tipTransaction(
                from: account,
                to: receiver,
                amount: amount,
                memo: memo,
                nonce: nonce
            )
            try? self.client.eth_sendTransaction(url: response.url, transaction: transaction) {
                [weak self] response in
                self?.handleResponse(response, expecting: "Hash")
                do {
                    let result = try response.result(as: String.self)
                    if result.hasPrefix("0x") {
                        // Result is a txid string
                        debugPrint("Transaction: saving \(result)")
                        let currentChainId = WalletManager.shared.currentNetwork()?.rawValue ?? 1
                        let record = EthereumTransaction(
                            id: result,
                            chainID: currentChainId,
                            from: self?.walletAccount ?? "error",
                            to: receiver,
                            toENS: ens,
                            amount: amount,
                            memo: memo
                        )
                        try? record.save()
                    }
                }
                catch {
                    debugPrint("Transaction Error: Unexpected response type error: \(error)")
                }

            }
        }
    }

    func tipTransaction(to receiver: String, amount: Int, memo: String, nonce: String)
        -> Client.Transaction
    {
        tipTransaction(from: walletAccount ?? "", to: receiver, amount: amount, memo: memo, nonce: nonce)
    }

    func tipTransaction(from sender: String, to receiver: String, amount: Int, memo: String, nonce: String)
        -> Client.Transaction
    {
        let tipAmount = amount * 10_000_000_000_000_000  // Tip Amount: X * 0.01 ETH
        let value = String(tipAmount, radix: 16)
        let memoEncoded: String = "0x" + memo.data(using: .utf8)!.toHexString()
        let currentChainId = WalletManager.shared.currentNetwork()?.rawValue ?? 1
        return Client.Transaction(
            from: sender,
            to: receiver,
            data: memoEncoded,
            gas: nil,
            gasPrice: nil,
            value: "0x\(value)",
            nonce: nonce,
            type: nil,
            accessList: nil,
            chainId: String(format: "0x%x", currentChainId),
            maxPriorityFeePerGas: nil,
            maxFeePerGas: nil
        )
    }

    // Mark: - Test Transaction

    func sendTestTransaction(receiver: String, amount: Int, memo: String, ens: String? = nil) {
        guard let client, let request = nonceRequest() else {
            delegate.failedToConnect()
            return
        }
        try? client.send(request) { [weak self] response in
            guard let self = self, let nonce = self.nonce(from: response) else { return }
            guard let account = self.walletAccount else {
                self.delegate.failedToConnect()
                return
            }
            let transaction = self.testTransaction(
                from: account,
                to: receiver,
                amount: amount,
                memo: memo,
                nonce: nonce
            )
            try? self.client.eth_sendTransaction(url: response.url, transaction: transaction) {
                [weak self] response in
                self?.handleResponse(response, expecting: "Hash")
            }
        }
    }

    func testTransaction(to receiver: String, amount: Int, memo: String, nonce: String)
        -> Client.Transaction
    {
        testTransaction(from: walletAccount ?? "", to: receiver, amount: amount, memo: memo, nonce: nonce)
    }

    func testTransaction(from sender: String, to receiver: String, amount: Int, memo: String, nonce: String)
        -> Client.Transaction
    {
        let amount = amount * 10 * 1_000_000_000_000_000  // Amount: X * 0.01 ETH
        let value = String(amount, radix: 16)
        let memoEncoded = "0x" + memo.data(using: .utf8)!.toHexString()
        let currentChainId = WalletManager.shared.currentNetwork()?.rawValue ?? 1
        return Client.Transaction(
            from: sender,
            to: receiver,
            data: memoEncoded,
            gas: nil,
            gasPrice: nil,
            value: "0x\(value)",
            nonce: nonce,
            type: nil,
            accessList: nil,
            chainId: String(format: "0x%x", currentChainId),
            maxPriorityFeePerGas: nil,
            maxFeePerGas: nil
        )
    }
}

extension WalletConnect: ClientDelegate {
    func client(_ client: Client, didFailToConnect url: WCURL) {
        delegate.failedToConnect()
    }

    func client(_ client: Client, didConnect url: WCURL) {
        // do nothing
    }

    func client(_ client: Client, didConnect session: Session) {
        self.session = session
        do {
            let sessionData = try JSONEncoder().encode(session)
            UserDefaults.standard.set(sessionData, forKey: sessionKey)
        }
        catch {
            debugPrint("WalletConnect V1 failed to persist session: \(error)")
        }
        delegate.didConnect()
    }

    func client(_ client: Client, didDisconnect session: Session) {
        UserDefaults.standard.removeObject(forKey: sessionKey)
        delegate.didDisconnect()
    }

    func client(_ client: Client, didUpdate session: Session) {
        // do nothing
    }
}

extension Request {
    static func eth_getTransactionCount(url: WCURL, account: String) throws -> Request {
        try Request(
            url: url,
            method: "eth_getTransactionCount",
            params: [account, "latest"]
        )
    }

    static func eth_gasPrice(url: WCURL) -> Request {
        return Request(url: url, method: "eth_gasPrice")
    }
}
