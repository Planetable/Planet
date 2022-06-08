import Foundation

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
