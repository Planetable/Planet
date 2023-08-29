import Foundation


@MainActor class WriterStore: ObservableObject {
    static let shared = WriterStore()

    private var writerWindows: [UUID: WriterWindow] = [:]

    func newArticle(for planet: MyPlanetModel) throws {
        let draft: DraftModel
        if planet.drafts.isEmpty {
            draft = try DraftModel.create(for: planet)
            planet.drafts.append(draft)
        } else {
            draft = planet.drafts[0]
        }
        draft.initialContentSHA256 = draft.contentSHA256()
        openWriterWindow(forDraft: draft)
    }

    func editArticle(for article: MyArticleModel) throws {
        let draft: DraftModel
        if let articleDraft = article.draft {
            draft = articleDraft
        } else {
            draft = try DraftModel.create(from: article)
            article.draft = draft
        }
        // If draft is created earlier than August 29, 2023, fix tags
        let tagsFeatureDate = Date(timeIntervalSince1970: 1693292400)
        if draft.createdAt < tagsFeatureDate {
            if let articleTags = article.tags {
                draft.tags = articleTags
                try? draft.save()
            }
        }
        draft.initialContentSHA256 = draft.contentSHA256()
        openWriterWindow(forDraft: draft)
    }

    func closeWriterWindow(byDraftID id: UUID) {
        if let window = writerWindows[id] {
            window.close()
        }
        writerWindows.removeValue(forKey: id)
    }

    // MARK: -

    private func openWriterWindow(forDraft draft: DraftModel) {
        let id = draft.id
        if let window = writerWindows[id] {
            window.makeKeyAndOrderFront(nil)
        } else {
            let window = WriterWindow(draft: draft)
            writerWindows[id] = window
        }
    }
}
