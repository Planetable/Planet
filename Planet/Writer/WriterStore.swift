import Foundation


@MainActor class WriterStore: ObservableObject {
    static let shared = WriterStore()

    private var writerWindows: [UUID: WriterWindow] = [:]

    func newArticle(for planet: MyPlanetModel) throws {
        try newArticle(
            for: planet,
            initialTitle: "",
            initialContent: "",
            attachmentURLs: [],
            forceNewDraft: false
        )
    }

    func newArticle(
        for planet: MyPlanetModel,
        initialTitle: String,
        initialContent: String,
        attachmentURLs: [URL] = [],
        forceNewDraft: Bool = false
    ) throws {
        let draft: DraftModel
        let createdNewDraft = forceNewDraft || planet.drafts.isEmpty
        if createdNewDraft {
            draft = try DraftModel.create(for: planet)
            planet.drafts.append(draft)
        } else {
            draft = planet.drafts[0]
        }
        if createdNewDraft {
            draft.title = initialTitle
            draft.content = initialContent
            for attachmentURL in attachmentURLs {
                try draft.addAttachment(path: attachmentURL, type: AttachmentType.from(attachmentURL))
            }
            try draft.save()
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

    func isEditing(article: MyArticleModel) -> Bool {
        writerWindows.values.contains { window in
            switch window.draft.target! {
            case .article(let wrapper):
                return wrapper.value.id == article.id
            case .myPlanet:
                return false
            }
        }
    }

    func hasActiveWriterWindows() -> Bool {
        if writerWindows.filter({ $0.value.isVisible }).count > 0 {
            return true
        }
        return false
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
