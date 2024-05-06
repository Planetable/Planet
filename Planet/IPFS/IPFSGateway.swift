//
//  IPFSGateway.swift
//  Planet
//

import Foundation


enum IPFSGateway: String, Codable, CaseIterable {
    case limo
    case sucks
    case croptop
    case cloudflare
    case dweblink

    static let names: [String: String] = [
        "limo": "eth.limo",
        "sucks": "eth.sucks",
        "croptop": "Croptop",
        "cloudflare": "Cloudflare",
        "dweblink": "DWeb.link",
    ]

    var name: String {
        IPFSGateway.names[rawValue] ?? rawValue
    }

    static let websites: [String: String] = [
        "limo": "https://eth.limo",
        "sucks": "https://eth.sucks",
        "croptop": "https://crop.top",
        "cloudflare": "https://cf-ipfs.com",
        "dweblink": "https://dweb.link",
    ]

    static let defaultGateway: IPFSGateway = {
        if PlanetStore.app == .lite {
            return .sucks
        }
        return .limo
    }()

    static func selectedGateway() -> IPFSGateway {
        let gateway = UserDefaults.standard.string(forKey: String.settingsPreferredIPFSPublicGateway)
        return IPFSGateway(rawValue: gateway ?? IPFSGateway.defaultGateway.rawValue) ?? IPFSGateway.defaultGateway
    }

    static let publicGateways: [String] = [
        "https://ipfs.io",
        "https://dweb.link",
        "https://cloudflare-ipfs.com",
        "https://gateway.pinata.cloud",
        "https://ipfs.fleek.co",
        "https://cf-ipfs.com",
    ]
}
