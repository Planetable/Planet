import Foundation
import UniformTypeIdentifiers
import SwiftUI

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

    var path: URL {
        draft.attachmentsPath.appendingPathComponent(name, isDirectory: false)
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
        return lhs.name == rhs.name
            && lhs.draft == rhs.draft
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
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
    }

    init(name: String, type: AttachmentType) {
        self.name = name
        self.type = type
    }

    func loadImage() {
        if type == .image,
           let image = NSImage(contentsOf: path) {
            self.image = image
        } else {
            image = nil
        }
    }
}
