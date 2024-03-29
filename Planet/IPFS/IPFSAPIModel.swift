import Foundation

struct IPFSVersion: Codable {
    let version: String
    let repo: String
    let system: String

    enum CodingKeys: String, CodingKey {
        case version = "Version"
        case repo = "Repo"
        case system = "System"
    }
}

struct IPFSID: Codable {
    let id: String
    let publicKey: String
    let addresses: [String]

    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case publicKey = "PublicKey"
        case addresses = "Addresses"
    }
}
struct IPFSPeers: Codable {
    let peers: [IPFSPeer]?

    enum CodingKeys: String, CodingKey {
        case peers = "Peers"
    }
}

struct IPFSPeer: Codable {
    let addr: String?

    enum CodingKeys: String, CodingKey {
        case addr = "Addr"
    }
}

struct IPFSPublished: Codable {
    let name: String
    let value: String

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case value = "Value"
    }
}

struct IPFSResolved: Codable {
    let path: String

    enum CodingKeys: String, CodingKey {
        case path = "Path"
    }
}
