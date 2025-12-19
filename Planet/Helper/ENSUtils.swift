import Foundation
import os

struct ENSUtils {
    static func isIPNS(_ str: String) -> Bool {
        if !str.hasPrefix("k") {
            return false
        }
        if str.hasPrefix("k51") && str.count == 62 {
            return true
        }
        if str.hasPrefix("k2") && str.count == 56 {
            return true
        }
        return false
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
