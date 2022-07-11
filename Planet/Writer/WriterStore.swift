import Foundation
import os

@MainActor class WriterStore: ObservableObject {
    static let shared = WriterStore()

    let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "WriterStore")

    @Published var writers: [DraftModel: WriterWindow] = [:]
    @Published var activeDraft: DraftModel? = nil

    func newArticle(for planet: MyPlanetModel) throws {
        let draft: DraftModel
        if planet.drafts.isEmpty {
            draft = try DraftModel.create(for: planet)
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
}
