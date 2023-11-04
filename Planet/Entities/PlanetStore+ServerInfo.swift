//
//  PlanetStore+ServerInfo.swift
//  Planet
//
//  Created by Xin Liu on 11/3/23.
//

import Foundation

/// Collect server info
extension PlanetStore {
    func updateServerInfo() async {
        var hostName: String = ""
        if let host = Host.current().localizedName {
            hostName = host
        }
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        var ipfsPeerID = ""
        do {
            let data = try await IPFSDaemon.shared.api(path: "id")
            let decoder = JSONDecoder()
            let idInfo = try decoder.decode(IPFSID.self, from: data)
            ipfsPeerID = idInfo.id
        } catch {
            ipfsPeerID = ""
        }
        var ipfsVersion = ""
        do {
            let data = try await IPFSDaemon.shared.api(path: "version")
            let decoder = JSONDecoder()
            let versionInfo = try decoder.decode(IPFSVersion.self, from: data)
            ipfsVersion = versionInfo.version
        } catch {
            ipfsVersion = ""
        }
        var peers = 0
        do {
            let data = try await IPFSDaemon.shared.api(path: "swarm/peers")
            let decoder = JSONDecoder()
            let swarmPeers = try decoder.decode(IPFSPeers.self, from: data)
            peers = swarmPeers.peers?.count ?? 0
        } catch {
            peers = 0
        }
        let info = ServerInfo(hostName: hostName, version: version, ipfsPeerID: ipfsPeerID, ipfsVersion: ipfsVersion, ipfsPeerCount: peers)
        self.serverInfo = info
        debugPrint("Updated ServerInfo: \(info)")
    }
}

struct ServerInfo: Codable {
    var hostName: String // Host name
    var version: String // Planet version
    var ipfsPeerID: String
    var ipfsVersion: String // IPFS (Kubo) version
    var ipfsPeerCount: Int
}
