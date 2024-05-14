//
//  PlanetStore+ServerInfo.swift
//  Planet
//
//  Created by Xin Liu on 11/3/23.
//

import Foundation


struct ServerInfo: Codable {
    var hostName: String // Host name
    var version: String // Planet version
    var ipfsPeerID: String
    var ipfsVersion: String // IPFS (Kubo) version
    var ipfsPeerCount: Int
}
