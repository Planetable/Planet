import Foundation

class DraftModel: Identifiable, Equatable, Hashable, Codable, ObservableObject {
    let id: UUID
    @Published var title: String
    @Published var content: String
    @Published var attachments: [Attachment]

    enum DraftTarget {
        // draft for composing a new article
        case myPlanet(Unowned<MyPlanetModel>)
        // draft for editing an existing article
        case article(Unowned<MyArticleModel>)
    }

    // populated when initializing
    var target: DraftTarget!

    lazy var basePath: URL = {
        switch target! {
        case .article(let wrapper):
            let article = wrapper.value
            return article.planet.articleDraftsPath.appendingPathComponent(article.id.uuidString, isDirectory: true)
        case .myPlanet(let wrapper):
            let planet = wrapper.value
            return planet.draftsPath.appendingPathComponent(id.uuidString, isDirectory: true)
        }
    }()
    lazy var infoPath = basePath.appendingPathComponent("Draft.json", isDirectory: false)
    lazy var attachmentsPath = basePath.appendingPathComponent("Attachments", isDirectory: true)
    // put preview in attachments directory since attachments use relative URL of the same level in HTML
    // example markdown when adding image: [example](example.png)
    lazy var previewPath = attachmentsPath.appendingPathComponent("preview.html", isDirectory: false)

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

    enum CodingKeys: String, CodingKey {
        case id, title, content, attachments
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        attachments = try container.decode([Attachment].self, forKey: .attachments)
        attachments.forEach { $0.draft = self }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encode(attachments, forKey: .attachments)
    }

    init(id: UUID, title: String, content: String, attachments: [Attachment], target: DraftTarget) {
        self.id = id
        self.title = title
        self.content = content
        self.attachments = attachments
        self.target = target
    }

    static func load(from directoryPath: URL, planet: MyPlanetModel) throws -> DraftModel {
        let draftPath = directoryPath.appendingPathComponent("Draft.json", isDirectory: false)
        let data = try Data(contentsOf: draftPath)
        let draft = try JSONDecoder.shared.decode(DraftModel.self, from: data)
        draft.target = .myPlanet(Unowned(planet))
        return draft
    }

    static func load(from directoryPath: URL, article: MyArticleModel) throws -> DraftModel {
        let draftPath = directoryPath.appendingPathComponent("Draft.json", isDirectory: false)
        let data = try Data(contentsOf: draftPath)
        let draft = try JSONDecoder.shared.decode(DraftModel.self, from: data)
        draft.target = .article(Unowned(article))
        return draft
    }

    static func create(for planet: MyPlanetModel) throws -> DraftModel {
        let draft = DraftModel(id: UUID(), title: "", content: "", attachments: [], target: .myPlanet(Unowned(planet)))
        try FileManager.default.createDirectory(at: draft.basePath, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: draft.attachmentsPath, withIntermediateDirectories: true)
        return draft
    }

    static func create(from article: MyArticleModel) throws -> DraftModel {
        let draft = DraftModel(
            id: UUID(),
            title: article.title,
            content: article.content,
            attachments: [],
            target: .article(Unowned(article))
        )
        try FileManager.default.createDirectory(at: draft.basePath, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: draft.attachmentsPath, withIntermediateDirectories: true)

        // add existing attachments from article
        let publicArticleFiles = try FileManager.default.contentsOfDirectory(
            at: article.publicBasePath,
            includingPropertiesForKeys: nil
        )
        draft.attachments = try publicArticleFiles
            // exclude index.html, article.json
            .filter { ["index.html", "article.json"].contains($0.lastPathComponent) }
            .map { filePath in
                let attachment = Attachment(
                    name: filePath.lastPathComponent,
                    type: AttachmentType.from(filePath),
                    status: .existing
                )
                attachment.draft = draft
                let filePath = article.publicBasePath.appendingPathComponent(attachment.name, isDirectory: false)
                let attachmentPath = draft.attachmentsPath.appendingPathComponent(attachment.name, isDirectory: false)
                try FileManager.default.copyItem(at: filePath, to: attachmentPath)
                return attachment
            }

        return draft
    }

    func hasAttachment(name: String) -> Bool {
        if let attachment = attachments.first(where: { $0.name == name }) {
            return attachment.status != .deleted
        }
        return false
    }

    func addAttachment(path: URL) throws {
        try addAttachment(path: path, type: AttachmentType.from(path))
    }

    func addAttachment(path: URL, type: AttachmentType) throws {
        let name = path.lastPathComponent
        let targetPath = attachmentsPath.appendingPathComponent(name, isDirectory: false)
        if FileManager.default.fileExists(atPath: targetPath.path) {
            try FileManager.default.removeItem(at: targetPath)
        }
        try FileManager.default.copyItem(at: path, to: targetPath)
        if let attachment = attachments.first(where: { $0.name == name }) {
            switch attachment.status {
            case .deleted, .existing:
                attachment.status = .overwrite
            default:
                let attachment = Attachment(name: name, type: type, status: .new)
                attachment.draft = self
                attachments.append(attachment)
            }
        }
    }

    func deleteAttachment(name: String) {
        if let attachment = attachments.first(where: { $0.name == name }) {
            switch attachment.status {
            case .new:
                attachments.removeAll { $0.name == name }
            default:
                attachment.status = .deleted
            }
        }
    }

    func revertAttachment(name: String) throws {
        if let attachment = attachments.first(where: { $0.name == name }) {
            switch attachment.status {
            case .deleted, .overwrite:
                guard let path = attachment.path,
                      let oldPath = attachment.oldPath else {
                    throw PlanetError.InternalError
                }
                if FileManager.default.fileExists(atPath: path.path) {
                    try FileManager.default.removeItem(at: oldPath)
                }
                try FileManager.default.copyItem(at: oldPath, to: path)
                attachment.status = .existing
            default:
                break
            }
        }
    }

    func saveToArticle() throws {
        let planet: MyPlanetModel
        let article: MyArticleModel
        switch target! {
        case .myPlanet(let wrapper):
            planet = wrapper.value
            article = try MyArticleModel.compose(link: nil, title: title, content: content, planet: planet)
            planet.articles.insert(article, at: 0)
        case .article(let wrapper):
            article = wrapper.value
            planet = article.planet
            // force reset link
            article.link = "/\(article.id)/"
            article.title = title
            article.content = content
        }
        var videoFilename: String? = nil
        for attachment in attachments {
            let name = attachment.name
            if attachment.type == .video {
                videoFilename = name
            }
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
        article.videoFilename = videoFilename
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
