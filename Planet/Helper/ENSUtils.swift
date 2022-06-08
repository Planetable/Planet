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
        let requestURL = URL(string: "\(await IPFSDaemon.shared.gateway)/\(prefix)/\(suffix)")!
        let request = URLRequest(url: requestURL)
        let (data, response) = try await URLSession.shared.data(for: request)
        if !(response as! HTTPURLResponse).ok {
            return nil
        }
        return data
    }
}

struct ENSUtils {
    // static let infuraClient = InfuraEthereumAPI(url: URL(string: "https://mainnet.infura.io/v3/<projectid>")!)
    // static let shared = ENSKit(jsonrpcClient: infuraClient)
    static let shared = ENSKit(ipfsClient: GoIPFSGateway())

    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ENSUtils")

    static func getCID(ens: String) async throws -> String? {
        let result: URL?
        do {
            result = try await shared.resolve(name: ens)
        } catch {
            throw PlanetError.EthereumError
        }
        logger.info("Get contenthash from \(ens): \(String(describing: result))")
        guard let contenthash = result else {
            return nil
        }
        if contenthash.scheme?.lowercased() == "ipns" {
            let ipns = contenthash.absoluteString.removePrefix(until: 7)
            let cidWithPrefix = try await IPFSDaemon.shared.resolveIPNS(ipns: ipns)
            if cidWithPrefix.hasPrefix("/ipfs/") {
                return cidWithPrefix.removePrefix(until: 6)
            }
        } else if contenthash.scheme?.lowercased() == "ipfs" {
            return contenthash.absoluteString.removePrefix(until: 7)
        }
        // unsupported contenthash scheme
        return nil
    }
}
