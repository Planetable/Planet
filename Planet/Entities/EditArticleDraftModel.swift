import Foundation

class EditArticleDraftModel: DraftModel, Codable {
    // populated when initializing
    weak var article: MyArticleModel! = nil

    lazy var basePath = article.planet.articleDraftsPath
        .appendingPathComponent(article.id.uuidString, isDirectory: true)
    lazy var infoPath = basePath.appendingPathComponent("Draft.json", isDirectory: false)
    lazy var attachmentsPath = basePath.appendingPathComponent("Attachments", isDirectory: true)
    // put preview in attachments directory since attachments use relative URL of the same level in HTML
    // example markdown when adding image: [example](example.png)
    lazy var previewPath = attachmentsPath.appendingPathComponent("preview.html", isDirectory: false)

    enum CodingKeys: String, CodingKey {
        case id, title, content, attachments
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let title = try container.decode(String.self, forKey: .title)
        let content = try container.decode(String.self, forKey: .content)
        let attachments = try container.decode([Attachment].self, forKey: .attachments)
        super.init(id: id, title: title, content: content, attachments: attachments)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encode(attachments, forKey: .attachments)
    }

    override init(id: UUID, title: String, content: String, attachments: [Attachment]) {
        super.init(id: id, title: title, content: content, attachments: attachments)
    }

    static func load(from directoryPath: URL, article: MyArticleModel) throws -> EditArticleDraftModel {
        let draftPath = directoryPath.appendingPathComponent("Draft.json", isDirectory: false)
        let data = try Data(contentsOf: draftPath)
        let draft = try JSONDecoder.shared.decode(EditArticleDraftModel.self, from: data)
        draft.article = article
        return draft
    }

    static func create(from article: MyArticleModel) throws -> EditArticleDraftModel {
        let publicArticleFiles = try FileManager.default.contentsOfDirectory(
            at: article.publicBasePath,
            includingPropertiesForKeys: nil
        )
        let attachments: [Attachment] = publicArticleFiles
            .map { $0.lastPathComponent }   // get filename
            .filter { $0 != "index.html" }  // exclude index.html
            .map { Attachment(name: $0, type: .image, status: .existing) }
        let draft = EditArticleDraftModel(
            id: UUID(),
            title: article.title,
            content: article.content,
            attachments: attachments
        )
        draft.article = article
        try FileManager.default.createDirectory(at: draft.basePath, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: draft.attachmentsPath, withIntermediateDirectories: true)
        return draft
    }

    func hasAttachment(name: String) -> Bool {
        if let attachment = attachments.first(where: { $0.name == name }) {
            return attachment.status != .deleted
        }
        return false
    }

    func addAttachment(path: URL, type: AttachmentType) throws {
        let name = path.lastPathComponent
        let targetPath = attachmentsPath.appendingPathComponent(name, isDirectory: false)
        if FileManager.default.fileExists(atPath: targetPath.path) {
            try FileManager.default.removeItem(at: targetPath)
        }
        try FileManager.default.copyItem(at: path, to: targetPath)
        if var attachment = attachments.first(where: { $0.name == name }) {
            switch attachment.status {
            case .deleted, .existing:
                attachment.status = .overwrite
            default:
                attachments.append(Attachment(name: name, type: type, status: .new))
            }
        }
    }

    func deleteAttachment(name: String) {
        if var attachment = attachments.first(where: { $0.name == name }) {
            switch attachment.status {
            case .new:
                attachments.removeAll { $0.name == name }
            default:
                attachment.status = .deleted
            }
        }
    }

    func revertAttachment(name: String) {
        if var attachment = attachments.first(where: { $0.name == name }) {
            switch attachment.status {
            case .deleted, .overwrite:
                attachment.status = .existing
            default:
                break
            }
        }
    }

    func getAttachmentPath(name: String) -> URL? {
        if let attachment = attachments.first(where: { $0.name == name }) {
            switch attachment.status {
            case .existing, .deleted:
                return article.publicBasePath.appendingPathComponent(name, isDirectory: false)
            case .new, .overwrite:
                return attachmentsPath.appendingPathComponent(name, isDirectory: false)
            }
        }
        return nil
    }

    func saveToArticle() throws {
        for attachment in attachments {
            let name = attachment.name
            let targetPath = article.publicBasePath.appendingPathComponent(name, isDirectory: false)
            switch attachment.status {
            case .new:
                let sourcePath = attachmentsPath.appendingPathComponent(name)
                try FileManager.default.copyItem(at: sourcePath, to: targetPath)
            case .overwrite:
                let sourcePath = attachmentsPath.appendingPathComponent(name)
                try FileManager.default.removeItem(at: targetPath)
                try FileManager.default.moveItem(at: sourcePath, to: targetPath)
            case .deleted:
                try FileManager.default.removeItem(at: targetPath)
            default:
                break
            }
        }
        article.planet.updated = Date()
        try article.planet.save()
        try article.planet.savePublic()
        Task {
            try await article.planet.publish()
        }
    }

    func save() throws {
        let data = try JSONEncoder.shared.encode(self)
        try data.write(to: infoPath)
    }

    func delete() throws {
        try FileManager.default.removeItem(at: basePath)
    }
}
