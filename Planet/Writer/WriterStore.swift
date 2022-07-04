import Foundation
import Stencil
import PathKit
import Ink
import os

@MainActor class WriterStore: ObservableObject {
    static let shared = WriterStore()

    let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "WriterStore")

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
        writerTemplateName = writerTemplatePath.path
    }

    func newArticle(for planet: MyPlanetModel) throws {
        let draft: DraftModel
        if planet.drafts.isEmpty {
            draft = try DraftModel.create(for: planet)
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
        let draft: DraftModel
        if let articleDraft = article.draft {
            draft = articleDraft
        } else {
            draft = try DraftModel.create(from: article)
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

    func setActiveDraft(draft: DraftModel?) {
        activeDraft = draft
    }

    func renderPreview(for draft: DraftModel) throws {
        let content: String
        let previewPath: URL

        logger.info("Rendering preview for draft \(draft.id)")
        content = draft.content
        previewPath = draft.previewPath

        let html = MarkdownParser().html(from: content.trim())
        let output = try previewRenderEnv.renderTemplate(name: writerTemplateName, context: ["content_html": html])
        try output.data(using: .utf8)?.write(to: previewPath)
        logger.info("Rendered preview for draft \(draft.id) and saved to \(previewPath)")
    }
}
