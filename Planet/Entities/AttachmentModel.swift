import Foundation
import UniformTypeIdentifiers

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
            if type.conforms(to: .video) {
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

class Attachment: Codable, Equatable, Hashable {
    let name: String
    var type: AttachmentType
    var status: AttachmentStatus

    // populated when initializing
    unowned var draft: DraftModel! = nil

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

    init(name: String, type: AttachmentType, status: AttachmentStatus) {
        self.name = name
        self.type = type
        self.status = status
    }
}
