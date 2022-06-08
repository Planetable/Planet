import Foundation
import Stencil
import PathKit
import Ink

@MainActor class WriterStore: ObservableObject {
    static let shared = WriterStore()

    let previewRenderEnv: Stencil.Environment
    let writerTemplateName: String

    @Published var writers: [DraftModel: WriterWindow] = [:]
    @Published var activeDraft: DraftModel? = nil

    init() {
        let writerTemplatePath = Bundle.main.url(forResource: "WriterBasic", withExtension: "html")!
        previewRenderEnv = Environment(
            loader: FileSystemLoader(paths: [Path(writerTemplatePath.path)]),
            extensions: [StencilExtension.get()]
        )
        writerTemplateName = writerTemplatePath.lastPathComponent
    }

    func newArticle(for planet: MyPlanetModel) throws {
        let draft: NewArticleDraftModel
        if planet.drafts.isEmpty {
            draft = try NewArticleDraftModel.create(for: planet)
            try draft.save()
            planet.drafts.append(draft)
        } else {
            draft = planet.drafts[0]
        }

        if let window = writers[draft] {
            window.makeKeyAndOrderFront(nil)
        } else {
            let window = WriterWindow(draft: draft)
            writers[draft] = window
        }
    }

    func editArticle(for article: MyArticleModel) throws {
        let draft: EditArticleDraftModel
        if let d = article.draft {
            draft = d
        } else {
            draft = try EditArticleDraftModel.create(from: article)
            try draft.save()
            article.draft = draft
        }

        if let window = writers[draft] {
            window.makeKeyAndOrderFront(nil)
        } else {
            let window = WriterWindow(draft: draft)
            writers[draft] = window
        }
    }

    func guessAttachmentType(path: URL) -> AttachmentType {
        let fileExtension = path.pathExtension
        if ["jpg", "jpeg", "png", "tiff", "gif"].contains(fileExtension) {
            return .image
        }
        return .file
    }

    func setActiveDraft(draft: DraftModel?) {
        activeDraft = draft
    }

    func renderPreview(for draft: DraftModel) throws {
        let content: String
        let previewPath: URL
        if let newArticleDraft = draft as? NewArticleDraftModel {
            content = newArticleDraft.content
            previewPath = newArticleDraft.previewPath
        } else
        if let editArticleDraft = draft as? EditArticleDraftModel {
            content = editArticleDraft.content
            previewPath = editArticleDraft.previewPath
        } else {
            throw PlanetError.InternalError
        }

        let html = MarkdownParser().html(from: content.trim())
        let output = try previewRenderEnv.renderTemplate(name: writerTemplateName, context: ["content_html": html])
        try output.data(using: .utf8)?.write(to: previewPath)
    }
}
