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
    
    static func fromContentType(_ contentType: String) -> Self {
        let imageContentTypes: [String] = ["image/jpeg", "image/png", "image/tiff", "image/gif"]
        let videoContentTypes: [String] = ["video/mp4", "video/mpeg", "video/ogg", "video/webm", "video/x-msvideo", "application/octet-stream"]
        let audioContentTypes: [String] = ["audio/aac", "audio/mpeg", "audio/ogg", "audio/wav", "audio/webm"]
        if imageContentTypes.contains(contentType) {
            return .image
        } else if audioContentTypes.contains(contentType) {
            return .audio
        } else if videoContentTypes.contains(contentType) {
            return .video
        }
        return .file
    }
}

class Attachment: Codable, Equatable, Hashable, ObservableObject {
    let name: String
    @Published var type: AttachmentType
    let created: Date

    @Published var thumbnail: NSImage? = nil

    // populated when initializing
    unowned var draft: DraftModel! = nil

    var markdown: String? {
        switch type {
        case .image:
            if let im = NSImage(contentsOf: self.path) {
                let size = im.size
                return """
\n<img width="\(Int(size.width))" alt="\((name as NSString).deletingPathExtension)" src="\(name)">\n
"""
            }
            return """
\n<img alt="\((name as NSString).deletingPathExtension)" src="\(name)">\n
"""
        case .file:
            return "\n<a href=\"\(name)\">\(name)</a>\n"
        default:
            return nil
        }
    }

    var path: URL {
        draft.attachmentsPath.appendingPathComponent(name, isDirectory: false)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(type)
        hasher.combine(draft)
        hasher.combine(created)
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
            && lhs.type == rhs.type
            && lhs.created == rhs.created
    }

    enum CodingKeys: String, CodingKey {
        case name
        case type
        case created
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(AttachmentType.self, forKey: .type)
        created = try container.decode(Date.self, forKey: .created)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(created, forKey: .created)
    }

    init(name: String, type: AttachmentType) {
        self.name = name
        self.type = type
        created = Date()
    }

    func loadThumbnail() {
        if type == .image,
            let image = NSImage(contentsOf: path)?.resizeSquare(maxLength: 128)  {
            thumbnail = image
        } else {
            if let rep = NSWorkspace.shared.icon(forFile: self.path.path)
                .bestRepresentation(for: NSRect(x: 0, y: 0, width: 128, height: 128), context: nil, hints: nil) {
                let image = NSImage(size: rep.size)
                image.addRepresentation(rep)
                thumbnail = image
            }
        }
    }
}
