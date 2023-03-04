//
//  EthereumTransaction.swift
//  Planet
//
//  Created by Xin Liu on 11/27/22.
//

import Foundation
import SwiftUI

/// After user sent any transaction, keep a record.
///
/// Records are kept in:
///
/// `~/Library/Containers/xyz.planetable.Planet/Data/Documents/Planet/Wallets/`
///
/// Each from address is a sub folder in wallets:
///
/// `~/Library/Containers/xyz.planetable.Planet/Data/Documents/Planet/Wallets/0xd8da6bf26964af9d7eed9e03e53415d37aa96045`

class EthereumTransaction: Codable, Identifiable {
    /// Ethereum Transaction ID.
    let id: String
    /// EVM chain ID. For example Mainnet is 1, Goerli is 5.
    let chainID: Int
    /// Sender address
    let from: String
    /// Recipient address
    let to: String
    /// If the recipient has an ENS name, it will be stored here.
    let toENS: String?
    let amount: Int
    let memo: String
    let created: Date

    static let walletsInfoPath: URL = {
        // ~/Library/Containers/xyz.planetable.Planet/Data/Documents/Planet/Wallets/
        let url = URLUtils.repoPath().appendingPathComponent("Wallets", isDirectory: true)
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    enum CodingKeys: String, CodingKey {
        case id
        case chainID
        case from
        case to
        case toENS
        case amount
        case memo
        case created
    }

    init(
        id: String,
        chainID: Int,
        from: String,
        to: String,
        toENS: String? = nil,
        amount: Int,
        memo: String
    ) {
        self.id = id
        self.chainID = chainID
        self.from = from
        self.to = to
        self.toENS = toENS
        self.amount = amount
        self.memo = memo
        self.created = Date()
    }

    static func from(path: URL) -> EthereumTransaction? {
        do {
            let data = try Data(contentsOf: path)
            let transaction = try JSONDecoder.shared.decode(EthereumTransaction.self, from: data)
            return transaction
        }
        catch {
            debugPrint("Unable to load transaction from \(path)")
            return nil
        }
    }

    func save() throws {
        let walletPath = EthereumTransaction.walletsInfoPath.appendingPathComponent(
            from,
            isDirectory: true
        )
        if !FileManager.default.fileExists(atPath: walletPath.path) {
            try! FileManager.default.createDirectory(
                at: walletPath,
                withIntermediateDirectories: true
            )
        }
        let txPath = walletPath.appendingPathComponent(id + ".json", isDirectory: false)
        try JSONEncoder.shared.encode(self).write(to: txPath)
    }

    @ViewBuilder
    func recipientView() -> some View {
        if let ens = toENS {
            Text(ens)
                .font(.body)
        }
        else {
            Text(to)
                .font(.footnote)
        }
    }

    func etherscanURL() -> URL? {
        let scanner = EthereumChainID.etherscanURL[chainID] ?? "https://etherscan.io"
        return URL(string: "\(scanner)/tx/\(id)")
    }

    func ethersString() -> String {
        let e: String = {
            switch chainID {
            case 1:
                return "Ξ"
            case 5:
                return "GΞ"
            case 11_155_111:
                return "SΞ"
            default:
                return "Ξ"
            }
        }()
        var ethers: Float = Float(amount) / 100
        return String(format: "%.2f \(e)", ethers)
    }
}
