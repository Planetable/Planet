import Foundation
import Stencil
import PathKit
import os
import SwiftSoup

class DraftModel: Identifiable, Equatable, Hashable, Codable, ObservableObject {
    static let previewTemplatePath = Bundle.main.url(forResource: "WriterBasic", withExtension: "html")!
    static let previewRenderEnv = Environment(
        loader: FileSystemLoader(paths: [Path(previewTemplatePath.path)]),
        extensions: [StencilExtension.common]
    )

    let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Draft")

    let id: UUID
    @Published var date: Date = Date()
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

    lazy var planetUUIDString: String = {
        switch target! {
        case .myPlanet(let wrapper):
            let planet = wrapper.value
            return planet.id.uuidString
        case .article(let wrapper):
            let article = wrapper.value
            return article.planet.id.uuidString
        }
    }()

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
        draft.attachments.forEach { attachment in
            attachment.draft = draft
            attachment.loadThumbnail()
        }
        return draft
    }

    static func load(from directoryPath: URL, article: MyArticleModel) throws -> DraftModel {
        let draftPath = directoryPath.appendingPathComponent("Draft.json", isDirectory: false)
        let data = try Data(contentsOf: draftPath)
        let draft = try JSONDecoder.shared.decode(DraftModel.self, from: data)
        draft.target = .article(Unowned(article))
        draft.attachments.forEach { attachment in
            attachment.draft = draft
            attachment.loadThumbnail()
        }
        return draft
    }

    static func create(for planet: MyPlanetModel) throws -> DraftModel {
        let draft = DraftModel(id: UUID(), title: "", content: "", attachments: [], target: .myPlanet(Unowned(planet)))
        try FileManager.default.createDirectory(at: draft.basePath, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: draft.attachmentsPath, withIntermediateDirectories: true)
        try draft.save()
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
            .filter { !["index.html", "article.json", "_videoThumbnail.png", "_grid.jpg", "_grid.png"].contains($0.lastPathComponent) }
            .map { filePath in
                let attachment = Attachment(name: filePath.lastPathComponent, type: AttachmentType.from(filePath))
                attachment.draft = draft
                let filePath = article.publicBasePath.appendingPathComponent(attachment.name, isDirectory: false)
                let attachmentPath = draft.attachmentsPath.appendingPathComponent(attachment.name, isDirectory: false)
                if FileManager.default.fileExists(atPath: attachmentPath.path) {
                    try FileManager.default.removeItem(at: attachmentPath)
                }
                try FileManager.default.copyItem(at: filePath, to: attachmentPath)
                attachment.loadThumbnail()
                return attachment
            }

        try draft.save()
        return draft
    }

    func hasAttachment(name: String) -> Bool {
        attachments.contains { $0.name == name }
    }

    @discardableResult func addAttachment(path: URL) throws -> Attachment {
        try addAttachment(path: path, type: AttachmentType.from(path))
    }

    @discardableResult func addAttachment(path: URL, type: AttachmentType) throws -> Attachment {
        let name = path.lastPathComponent
        let targetPath = attachmentsPath.appendingPathComponent(name, isDirectory: false)
        if FileManager.default.fileExists(atPath: targetPath.path) {
            try FileManager.default.removeItem(at: targetPath)
        }
        try FileManager.default.copyItem(at: path, to: targetPath)
        if type == .video {
            // only allow one video attachment
            attachments.removeAll { $0.type == .video || $0.name == name }
        } else {
            attachments.removeAll { $0.name == name }
        }
        let attachment = Attachment(name: name, type: type)
        attachment.draft = self
        attachments.append(attachment)
        attachment.loadThumbnail()
        return attachment
    }

    func deleteAttachment(name: String) throws {
        if let attachment = attachments.first(where: { $0.name == name }) {
            try FileManager.default.removeItem(at: attachment.path)
            attachments.removeAll { $0.name == name }
        }
    }

    func preprocessContentForMarkdown() -> String {
        var processedContent = content
        let timestamp = Int(Date().timeIntervalSince1970)
        // not very efficient, but let's see if we observe performance problem
        //for attachment in attachments.filter({ $0.type == .image }) {
        //    let name = attachment.name
        //    let find = attachment.markdown!
        //    let replace = "![\(name)](\(name)?t=\(timestamp))"
        //    processedContent = processedContent.replacingOccurrences(of: find, with: replace)
        //}
        return processedContent
    }

    func renderPreview() throws {
        logger.info("Rendering preview for draft \(self.id)")

        guard let html = CMarkRenderer.renderMarkdownHTML(markdown: preprocessContentForMarkdown()) else {
            throw PlanetError.RenderMarkdownError
        }
        let output = try Self.previewRenderEnv.renderTemplate(
            name: Self.previewTemplatePath.path,
            context: ["content_html": html]
        )
        try output.data(using: .utf8)?.write(to: previewPath)

        logger.info("Rendered preview for draft \(self.id) and saved to \(self.previewPath)")
    }

    func saveToArticle() throws {
        let planet: MyPlanetModel
        let article: MyArticleModel
        switch target! {
        case .myPlanet(let wrapper):
            planet = wrapper.value
            article = try MyArticleModel.compose(link: nil, title: title, content: content, summary: nil, planet: planet)
            planet.articles.insert(article, at: 0)
        case .article(let wrapper):
            article = wrapper.value
            planet = article.planet
            // workaround: force reset link
            article.link = "/\(article.id)/"
            article.title = title
            article.content = content
        }
        try FileManager.default.contentsOfDirectory(at: article.publicBasePath, includingPropertiesForKeys: nil)
            .forEach { try FileManager.default.removeItem(at: $0) }
        var videoFilename: String? = nil
        var audioFilename: String? = nil
        var currentAttachments: [String] = []
        for attachment in attachments {
            let name = attachment.name
            if attachment.type == .video {
                videoFilename = name
            }
            if attachment.type == .audio {
                audioFilename = name
            }
            currentAttachments.append(name)
            let targetPath = article.publicBasePath.appendingPathComponent(name, isDirectory: false)
            // copy attachment to article folder, in case file operation fails, the draft still maintains its integrity
            // if we found storage is a problem, we can move attachment instead
            try FileManager.default.copyItem(at: attachment.path, to: targetPath)
        }
        article.attachments = currentAttachments
        article.videoFilename = videoFilename
        article.audioFilename = audioFilename
        if let contentHTML = CMarkRenderer.renderMarkdownHTML(markdown: article.content), let soup = try? SwiftSoup.parseBodyFragment(contentHTML), let summary = try? soup.text() {
            if summary.count > 280 {
                article.summary = summary.prefix(280) + "..."
            } else {
                article.summary = summary
            }
        }
        try article.save()
        try article.savePublic()
        try delete()
        try planet.copyTemplateAssets()
        planet.updated = Date()
        try planet.save()
        try planet.savePublic()

        Task {
            try await planet.publish()
        }

        Task { @MainActor in
            PlanetStore.shared.selectedView = .myPlanet(planet)
            PlanetStore.shared.refreshSelectedArticles()
            // wrap it to delay the state change
            Task { @MainActor in
                if PlanetStore.shared.selectedArticle == article {
                    NotificationCenter.default.post(name: .loadArticle, object: nil)
                } else {
                    PlanetStore.shared.selectedArticle = article
                }
            }
        }
    }

    func save() throws {
        try JSONEncoder.shared.encode(self).write(to: infoPath)
    }

    func delete() throws {
        switch target! {
        case .myPlanet(let wrapper):
            let planet = wrapper.value
            planet.drafts.removeAll { $0.id == id }
        case .article(let wrapper):
            let article = wrapper.value
            article.draft = nil
        }
        try FileManager.default.removeItem(at: basePath)
    }
}
