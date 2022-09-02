//
//  URLUtils.swift
//  Planet
//
//  Created by Shu Lyu on 2022-05-07.
//

import Foundation

struct URLUtils {
    static let applicationSupportPath = try! FileManager.default.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
    )


    static let documentsPath = try! FileManager.default.url(
        for: .documentDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
    )

    static let legacyPlanetsPath = applicationSupportPath.appendingPathComponent("planets", isDirectory: true)

    static let legacyTemplatesPath = applicationSupportPath.appendingPathComponent("templates", isDirectory: true)

    static let legacyDraftPath = applicationSupportPath.appendingPathComponent("drafts", isDirectory: true)

    static let repoPath: URL = {
        let url = documentsPath.appendingPathComponent("Planet", isDirectory: true)
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    static let templatesPath: URL = {
        let url = repoPath.appendingPathComponent("Templates", isDirectory: true)
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    static let downloadHistoryPath: URL = {
        let url = repoPath.appendingPathComponent("Downloads", isDirectory: true)
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()
}

extension URL {
    var isHTTP: Bool {
        if let scheme = scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            return true
        }
        return false
    }

    var pathQueryFragment: String {
        var s = path
        if let query = query {
            s += "?\(query)"
        }
        if let fragment = fragment {
            s += "#\(fragment)"
        }
        return s
    }

    var isPlanetLink: Bool {
        let components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        if components?.scheme == "planet" {
            return true
        }
        return false
    }

    /*
     - file link is not an internal link:
        file://

     - public article link:
        https://[*]/ipns/[ipns]/[uuid]/

     - public article link (2):
        https://[*].eth.limo/[uuid]/

     - TODO: support more public article links.

     - local article link:
        http://[*]:18181/ipfs/[cid]/[uuid]/
     */
    var isPlanetInternalLink: Bool {
        if let _ = self.scheme, let host = self.host {
            let uuidString = self.lastPathComponent
            let idString = self.deletingLastPathComponent().lastPathComponent
            let tag = self.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent
            let cidStringCount: Int = 59
            let ipnsStringCount: Int = 62
            if let _ = UUID(uuidString: uuidString), idString.count >= min(cidStringCount, ipnsStringCount) {
                if let port = self.port, tag == "ipfs" && port == IPFSDaemon.shared.gatewayPort && idString.count == cidStringCount {
                    // localhost article link
                    return true
                }
                else if tag == "ipns" && idString.count == ipnsStringCount {
                    // (possible) public gateway article link
                    return true
                }
            }
            else if host.hasSuffix(".eth.limo") {
                if let _ = UUID(uuidString: uuidString) {
                    // (possible) public gateway article link (2)
                    return true
                }
            }
        }
        return false
    }
}
