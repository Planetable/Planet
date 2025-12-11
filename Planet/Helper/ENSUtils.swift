import Foundation
import ENSKit
import os

struct GoIPFSGateway: IPFSClient {
    public func getIPFSURL(url: URL) async throws -> Data? {
        let str = url.absoluteString
        let suffix: String
        let prefix: String
        if let range = str.range(of: "ipfs://ipfs/", options: [.caseInsensitive, .anchored]) {
            prefix = "ipfs"
            suffix = String(str[range.upperBound..<str.endIndex])
        } else {
            if url.scheme?.lowercased() == "ipns" {
                prefix = "ipns"
            } else {
                prefix = "ipfs"
            }
            suffix = String(str.suffix(from: str.index(str.startIndex, offsetBy: 7)))
        }
        let gateway = IPFSState.shared.getGateway()
        let requestURL = URL(string: "\(gateway)/\(prefix)/\(suffix)")!
        let request = URLRequest(url: requestURL)
        let (data, response) = try await URLSession.shared.data(for: request)
        if !(response as! HTTPURLResponse).ok {
            return nil
        }
        return data
    }
}

struct ENSUtils {
    // Use Infura:
    // static let infuraClient = InfuraEthereumAPI(url: URL(string: "https://mainnet.infura.io/v3/<projectid>")!)
    // static let shared = ENSKit(jsonrpcClient: infuraClient)

    // ENSKit uses Cloudflare Ethereum Gateway by default, which does not search history
    // Use other Ethereum API that supports searchContenthashHistory and lastContenthashChange
    // static let shared = ENSKit(jsonrpcClient: EthereumAPI.Flashbots, ipfsClient: GoIPFSGateway())
    // static let shared = ENSKit(ipfsClient: GoIPFSGateway())

    static func isIPNS(_ str: String) -> Bool {
        if !str.hasPrefix("k") {
            return false
        }
        let base36encoded = String(str.dropFirst(1))
        guard let content = Base36.decode(base36encoded) else {
            return false
        }
        // 0x01: cidv1, 0x72: libp2p-key, 0x00: identity
        if !content.starts(with: [0x01, 0x72, 0x00]) {
            return false
        }
        guard let (length, _) = VarUInt.decode(content, offset: 3),
              length + 3 == content.count
        else {
            return false
        }
        return true
    }

    static func getCID(from contenthash: URL) async throws -> String? {
        if contenthash.scheme?.lowercased() == "ipns" {
            let ipns = String(contenthash.absoluteString.dropFirst("ipns://".count))
            return try await IPFSDaemon.shared.resolveIPNSorDNSLink(name: ipns)
        } else if contenthash.scheme?.lowercased() == "ipfs" {
            return String(contenthash.absoluteString.dropFirst("ipfs://".count))
        }
        // unsupported contenthash scheme
        return nil
    }
}
