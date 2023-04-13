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

    var id: UUID
    @Published var date: Date
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

    func contentRaw() -> String {
        // Sort attachments by name to make sure the order is consistent
        attachments.sort { $0.name < $1.name }
        let attachmentNames: String = attachments.map { $0.name }.joined(separator: ",")
        let currentContent = "\(date)\(title)\(content)\(attachmentNames)"
        return currentContent
    }
    func contentSHA256() -> String {
        let currentContent = contentRaw()
        return currentContent.sha256()
    }
    var initialContentSHA256: String = ""

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
        case id, date, title, content, attachments
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        if let date = try container.decodeIfPresent(Date.self, forKey: .date) {
            self.date = date
        } else {
            self.date = Date()
        }
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        attachments = try container.decode([Attachment].self, forKey: .attachments)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encode(attachments, forKey: .attachments)
    }

    init(id: UUID, date: Date = Date(), title: String, content: String, attachments: [Attachment], target: DraftTarget) {
        self.id = id
        self.date = date
        self.title = title
        self.content = content
        self.attachments = attachments
        self.target = target
        let contentSHA256String = self.contentSHA256()
        debugPrint("Computed contentSHA256 for \(self.title) during init: \(contentSHA256String)")
        self.initialContentSHA256 = contentSHA256String
    }

    static func load(from directoryPath: URL, planet: MyPlanetModel) throws -> DraftModel {
        let draftId = directoryPath.lastPathComponent
        let draftPath = directoryPath.appendingPathComponent("Draft.json", isDirectory: false)
        let data = try Data(contentsOf: draftPath)
        let draft = try JSONDecoder.shared.decode(DraftModel.self, from: data)
        if draft.id != UUID(uuidString: draftId) {
            draft.id = UUID(uuidString: draftId)!
        }
        draft.target = .myPlanet(Unowned(planet))
        let contentSHA256String = draft.contentSHA256()
        debugPrint("Computed contentSHA256 for \(draft.title) during load/planet: \(contentSHA256String)")
        draft.initialContentSHA256 = contentSHA256String
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
        let contentSHA256String = draft.contentSHA256()
        debugPrint("Computed contentSHA256 for \(draft.title) during load/article: \(contentSHA256String)")
        draft.initialContentSHA256 = contentSHA256String
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
            date: article.created,
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

        draft.initialContentSHA256 = draft.contentSHA256()

        try draft.save()
        return draft
    }

    func hasAttachment(name: String) -> Bool {
        attachments.contains { $0.name == name }
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

    @discardableResult func addAttachmentFromData(data: Data, fileName: String, forContentType contentType: String) throws -> Attachment {
        let targetPath = attachmentsPath.appendingPathComponent(fileName, isDirectory: false)
        if FileManager.default.fileExists(atPath: targetPath.path) {
            try FileManager.default.removeItem(at: targetPath)
        }
        try data.write(to: targetPath, options: .atomic)
        let type = AttachmentType.fromContentType(contentType)
        if type == .video {
            attachments.removeAll { $0.type == .video || $0.name == fileName }
        } else {
            attachments.removeAll { $0.name == fileName }
        }
        let attachment = Attachment(name: fileName, type: type)
        attachment.draft = self
        attachments.append(attachment)
        attachment.loadThumbnail()
        return attachment
    }

    func deleteAttachment(name: String) {
        if let attachment = attachments.first(where: { $0.name == name }) {
            do {
                if FileManager.default.fileExists(atPath: attachment.path.path) {
                    try FileManager.default.removeItem(at: attachment.path)
                }
                attachments.removeAll { $0.name == name }
            } catch {
                debugPrint("\(error)")
            }
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
            article = try MyArticleModel.compose(link: nil, date: date, title: title, content: content, summary: nil, planet: planet)
            var articles = planet.articles
            articles?.append(article)
            articles?.sort(by: { $0.created > $1.created })
            planet.articles = articles
        case .article(let wrapper):
            article = wrapper.value
            planet = article.planet
            if let articleSlug = article.slug, articleSlug.count > 0 {
                article.link = "/\(articleSlug)/"
            } else {
                article.link = "/\(article.id)/"
            }
            article.created = date
            article.title = title
            article.content = content
            // reorder articles after editing.
            var articles = planet.articles
            articles?.sort(by: { $0.created > $1.created })
            planet.articles = articles
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
        debugPrint("Deleting draft \(id) at \(basePath.path)")
        // Remove the folder if it exists
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: basePath.path, isDirectory: &isDirectory) {
            try FileManager.default.removeItem(at: basePath)
        }
    }
}
