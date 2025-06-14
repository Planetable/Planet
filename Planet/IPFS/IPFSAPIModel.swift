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

struct IPFSRepoState: Codable {
    let repoSize: Int64
    let storageMax: Int64
    let numObjects: Int64
    let repoPath: String
    let version: String

    enum CodingKeys: String, CodingKey {
        case repoSize = "RepoSize"
        case storageMax = "StorageMax"
        case numObjects = "NumObjects"
        case repoPath = "RepoPath"
        case version = "Version"
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

struct IPFSBandwidth: Codable {
    let totalIn: Int
    let totalOut: Int
    let rateIn: Double
    let rateOut: Double

    enum CodingKeys: String, CodingKey {
        case totalIn = "TotalIn"
        case totalOut = "TotalOut"
        case rateIn = "RateIn"
        case rateOut = "RateOut"
    }
}

struct IPFSPinned: Codable {
    let keys: [String: IPFSPinInfo]

    enum CodingKeys: String, CodingKey {
        case keys = "Keys"
    }
}

struct IPFSPinInfo: Codable {
    let type: String

    enum CodingKeys: String, CodingKey {
        case type = "Type"
    }
}

struct PlanetID: Codable {
    let id: UUID
}
