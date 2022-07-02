import Foundation

class NewArticleDraftModel: DraftModel, Codable {
    // populated when initializing
    weak var planet: MyPlanetModel! = nil

    lazy var basePath = planet.draftsPath.appendingPathComponent(id.uuidString, isDirectory: true)
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

    static func load(from directoryPath: URL, planet: MyPlanetModel) throws -> NewArticleDraftModel {
        let draftPath = directoryPath.appendingPathComponent("Draft.json", isDirectory: false)
        let data = try Data(contentsOf: draftPath)
        let draft = try JSONDecoder.shared.decode(NewArticleDraftModel.self, from: data)
        draft.planet = planet
        return draft
    }

    static func create(for planet: MyPlanetModel) throws -> NewArticleDraftModel {
        let draft = NewArticleDraftModel(id: UUID(), title: "", content: "", attachments: [])
        draft.planet = planet
        try FileManager.default.createDirectory(at: draft.basePath, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: draft.attachmentsPath, withIntermediateDirectories: true)
        return draft
    }

    func hasAttachment(name: String) -> Bool {
        attachments.contains(where: { $0.name == name })
    }

    func addAttachment(path: URL, type: AttachmentType) throws {
        let name = path.lastPathComponent
        let targetPath = attachmentsPath.appendingPathComponent(name, isDirectory: false)
        if FileManager.default.fileExists(atPath: targetPath.path) {
            try FileManager.default.removeItem(at: targetPath)
        }
        try FileManager.default.copyItem(at: path, to: targetPath)
        if !hasAttachment(name: name) {
            attachments.append(Attachment(name: name, type: type, status: .new))
        }
    }

    func deleteAttachment(name: String) {
        if hasAttachment(name: name) {
            attachments.removeAll { $0.name == name }
        }
    }

    func getAttachmentPath(name: String) -> URL? {
        if hasAttachment(name: name) {
            return attachmentsPath.appendingPathComponent(name)
        }
        return nil
    }

    func saveToArticle() throws {
        let article = try MyArticleModel.compose(link: nil, title: title, content: content, planet: planet)
        for attachment in attachments {
            if attachment.type == .video {
                article.hasVideo = true
                article.videoFilename = attachment.name
            }
            let sourcePath = attachmentsPath.appendingPathComponent(attachment.name, isDirectory: false)
            let targetPath = article.publicBasePath.appendingPathComponent(attachment.name, isDirectory: false)
            try FileManager.default.copyItem(at: sourcePath, to: targetPath)
        }
        planet.articles.insert(article, at: 0)
        planet.finalizeChange()
    }

    func save() throws {
        let data = try JSONEncoder.shared.encode(self)
        try data.write(to: infoPath)
    }

    func delete() throws {
        try FileManager.default.removeItem(at: basePath)
    }
}
