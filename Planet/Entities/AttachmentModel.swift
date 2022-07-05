import Foundation
import UniformTypeIdentifiers
import SwiftUI

enum AttachmentStatus: String, Codable {
    case new
    case overwrite
    case existing
    case deleted
}

enum AttachmentType: String, Codable {
    case image
    case video
    case audio
    case file

    static func from(_ path: URL) -> Self {
        if let id = try? path.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier,
           let type = UTType(id) {
            if type.conforms(to: .movie) || type.conforms(to: .video) {
                return .video
            }
            if type.conforms(to: .audio) {
                return .audio
            }
            if type.conforms(to: .image) {
                return .image
            }
        }
        return .file
    }
}

class Attachment: Codable, Equatable, Hashable, ObservableObject {
    let name: String
    @Published var type: AttachmentType
    @Published var status: AttachmentStatus

    @Published var image: NSImage? = nil

    // populated when initializing
    unowned var draft: DraftModel! = nil

    var markdown: String? {
        switch type {
        case .image:
            return "![\(name)](\(name))"
        case .file:
            return "<a href=\"\(name)\">\(name)</a>"
        default:
            return nil
        }
    }

    var path: URL? {
        if status == .deleted {
            return nil
        }
        return draft.attachmentsPath.appendingPathComponent(name, isDirectory: false)
    }
    var oldPath: URL? {
        if case .article(let wrapper) = draft.target {
            let article = wrapper.value
            let oldPath = article.publicBasePath.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: oldPath.path) {
                return oldPath
            }
        }
        return nil
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(draft)
    }

    static func ==(lhs: Attachment, rhs: Attachment) -> Bool {
        if lhs === rhs {
            return true
        }
        if Swift.type(of: lhs) != Swift.type(of: rhs) {
            return false
        }
        if lhs.name != rhs.name {
            return false
        }
        if lhs.draft != rhs.draft {
            return false
        }
        return true
    }

    enum CodingKeys: String, CodingKey {
        case name
        case type
        case status
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(AttachmentType.self, forKey: .type)
        status = try container.decode(AttachmentStatus.self, forKey: .status)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(status, forKey: .status)
    }

    init(name: String, type: AttachmentType, status: AttachmentStatus) {
        self.name = name
        self.type = type
        self.status = status
    }

    func loadImage() {
        if type == .image,
           let path = path,
           let image = NSImage(contentsOf: path) {
            self.image = image
        } else {
            image = nil
        }
    }
}
