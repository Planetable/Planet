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

    static func from(path: URL) -> Self {
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

struct Attachment: Codable, Equatable {
    let name: String
    var type: AttachmentType
    var status: AttachmentStatus
}

class DraftModel: Identifiable, Equatable, Hashable, ObservableObject {
    let id: UUID
    @Published var title: String
    @Published var content: String
    @Published var attachments: [Attachment]

    init(id: UUID, title: String, content: String, attachments: [Attachment]) {
        self.id = id
        self.title = title
        self.content = content
        self.attachments = attachments
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func ==(lhs: DraftModel, rhs: DraftModel) -> Bool {
        if lhs === rhs {
            return true
        }
        if type(of: lhs) != type(of: rhs) {
            return false
        }
        if lhs.id != rhs.id {
            return false
        }
        return true
    }
}
