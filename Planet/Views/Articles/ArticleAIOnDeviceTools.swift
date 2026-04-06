//
//  ArticleAIOnDeviceTools.swift
//  Planet
//
//  Created with AI assistance on 3/31/26.
//

#if canImport(FoundationModels)

import Foundation
import FoundationModels

// MARK: - Tool Argument Types

@available(macOS 26.0, *)
@Generable(description: "Arguments for reading an article")
struct ReadArticleArguments: Sendable {
    @Guide(description: "Optional UUID of the article to read. Defaults to the currently opened article.")
    var articleID: String?
    @Guide(description: "Optional list of top-level JSON field names to return. Returns all fields if omitted.")
    var fields: [String]?
}

@available(macOS 26.0, *)
@Generable(description: "Arguments for writing changes to an article")
struct WriteArticleArguments: Sendable {
    @Guide(description: "Optional UUID of the article to update. Defaults to the currently opened article.")
    var articleID: String?
    @Guide(description: "New title for the article.")
    var title: String?
    @Guide(description: "New content to append to the article in Markdown format. Set replaceContent to true to replace instead of append.")
    var content: String?
    @Guide(description: "Set to true only when the user explicitly asks to replace the full article content. Defaults to false (append).")
    var replaceContent: Bool?
}

@available(macOS 26.0, *)
@Generable(description: "Arguments for reading a planet's settings")
struct ReadPlanetArguments: Sendable {
    @Guide(description: "Optional UUID of the planet to read. Defaults to the current article's planet.")
    var planetID: String?
    @Guide(description: "Optional list of top-level JSON field names to return. Returns all fields if omitted.")
    var fields: [String]?
}

@available(macOS 26.0, *)
@Generable(description: "Arguments for writing changes to a planet's settings")
struct WritePlanetArguments: Sendable {
    @Guide(description: "Optional UUID of the planet to update. Defaults to the current article's planet.")
    var planetID: String?
    @Guide(description: "New name for the planet.")
    var name: String?
    @Guide(description: "New description/about text for the planet.")
    var about: String?
}

@available(macOS 26.0, *)
@Generable(description: "Arguments for searching articles")
struct SearchArticlesArguments: Sendable {
    @Guide(description: "Search query. Supports phrases in quotes and -negation.")
    var query: String
    @Guide(description: "Maximum number of results to return. Defaults to 10, max 50.")
    var limit: Int?
    @Guide(description: "Optional UUID of a planet to restrict search to.")
    var planetID: String?
}

// MARK: - Tool Context

@MainActor
final class OnDeviceToolContext: Sendable {
    let articleID: UUID?
    let planetID: UUID?

    init(articleID: UUID?, planetID: UUID?) {
        self.articleID = articleID
        self.planetID = planetID
    }

    func resolveMyArticle(articleID: String?) -> MyArticleModel? {
        if let articleID = articleID, let uuid = UUID(uuidString: articleID) {
            for planet in PlanetStore.shared.myPlanets {
                if let found = (planet.articles ?? []).first(where: { $0.id == uuid }) {
                    return found
                }
            }
            // Fall through to default if UUID didn't match — on-device model may hallucinate IDs
        }
        if let selfArticleID = self.articleID {
            for planet in PlanetStore.shared.myPlanets {
                if let found = (planet.articles ?? []).first(where: { $0.id == selfArticleID }) {
                    return found
                }
            }
        }
        return PlanetStore.shared.selectedArticle as? MyArticleModel
    }

    func resolveMyPlanet(planetID: String?) -> MyPlanetModel? {
        if let planetID = planetID, let uuid = UUID(uuidString: planetID) {
            if let found = PlanetStore.shared.myPlanets.first(where: { $0.id == uuid }) {
                return found
            }
            // Fall through to default if UUID didn't match — on-device model may hallucinate IDs
        }
        if let pid = self.planetID {
            return PlanetStore.shared.myPlanets.first(where: { $0.id == pid })
        }
        if let myArticle = resolveMyArticle(articleID: nil) {
            return myArticle.planet
        }
        return PlanetStore.shared.myPlanets.first
    }

    func encodeToDictionary<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder.shared.encode(value)
        let json = try JSONSerialization.jsonObject(with: data)
        guard let dict = json as? [String: Any] else {
            throw NSError(domain: "OnDeviceTools", code: 1, userInfo: [NSLocalizedDescriptionKey: "Model JSON is not an object"])
        }
        return dict
    }

    func filter(dictionary: [String: Any], fields: [String]?) -> [String: Any] {
        guard let fields = fields, !fields.isEmpty else { return dictionary }
        return dictionary.filter { fields.contains($0.key) }
    }

    func syncDraftIfExists(for article: MyArticleModel) throws {
        let draftDirectoryPath = article.planet.articleDraftsPath.appendingPathComponent(
            article.id.uuidString,
            isDirectory: true
        )
        let draftInfoPath = draftDirectoryPath.appendingPathComponent("Draft.json", isDirectory: false)
        guard FileManager.default.fileExists(atPath: draftInfoPath.path) else {
            return
        }
        let draft: DraftModel
        if let existing = article.draft {
            draft = existing
        } else {
            draft = try DraftModel.load(from: draftDirectoryPath, article: article)
            article.draft = draft
        }
        draft.date = article.created
        draft.title = article.title
        draft.content = article.content
        draft.heroImage = article.heroImage
        draft.externalLink = article.externalLink ?? ""
        draft.tags = article.tags ?? [:]
        try draft.save()
    }

    func reloadStoreAndRestoreSelection(preferredArticleID: UUID?) throws {
        let selectedViewSnapshot = PlanetStore.shared.selectedView
        try PlanetStore.shared.load()

        if let selectedViewSnapshot = selectedViewSnapshot {
            switch selectedViewSnapshot {
            case .today:
                PlanetStore.shared.selectedView = .today
            case .unread:
                PlanetStore.shared.selectedView = .unread
            case .starred:
                PlanetStore.shared.selectedView = .starred
            case .myPlanet(let planet):
                if let refreshed = PlanetStore.shared.myPlanets.first(where: { $0.id == planet.id }) {
                    PlanetStore.shared.selectedView = .myPlanet(refreshed)
                } else {
                    PlanetStore.shared.selectedView = nil
                }
            case .followingPlanet(let planet):
                if let refreshed = PlanetStore.shared.followingPlanets.first(where: { $0.id == planet.id }) {
                    PlanetStore.shared.selectedView = .followingPlanet(refreshed)
                } else {
                    PlanetStore.shared.selectedView = nil
                }
            }
        } else {
            PlanetStore.shared.selectedView = nil
        }

        PlanetStore.shared.refreshSelectedArticles()
        if let preferredArticleID = preferredArticleID {
            if let selected = PlanetStore.shared.selectedArticleList?.first(where: { $0.id == preferredArticleID }) {
                PlanetStore.shared.selectedArticle = selected
            } else {
                for planet in PlanetStore.shared.myPlanets {
                    if let myArticle = (planet.articles ?? []).first(where: { $0.id == preferredArticleID }) {
                        PlanetStore.shared.selectedArticle = myArticle
                        break
                    }
                }
            }
        }
    }
}

// MARK: - Logging

private func onDeviceToolLog(_ message: String) {
    ArticleAIDebugLogger.log("[OnDeviceTool] \(message)")
}

// MARK: - Read Article Tool

@available(macOS 26.0, *)
struct ReadArticleTool: Tool {
    let context: OnDeviceToolContext

    var name: String { "read_article" }
    var description: String { "Read the current article or a specific article by UUID. Returns article properties as JSON." }

    func call(arguments: ReadArticleArguments) async throws -> String {
        onDeviceToolLog("read_article called articleID=\(arguments.articleID ?? "nil"), fields=\(arguments.fields ?? [])")
        let result: String = try await MainActor.run {
            guard let myArticle = context.resolveMyArticle(articleID: arguments.articleID) else {
                return "Error: Article not found."
            }
            let full = try context.encodeToDictionary(myArticle)
            let filtered = context.filter(dictionary: full, fields: arguments.fields)
            let data = try JSONSerialization.data(withJSONObject: filtered, options: [.prettyPrinted, .sortedKeys])
            return String(data: data, encoding: .utf8) ?? "Error: Failed to encode article."
        }
        onDeviceToolLog("read_article result length=\(result.count)")
        return result
    }
}

// MARK: - Write Article Tool

@available(macOS 26.0, *)
struct WriteArticleTool: Tool {
    let context: OnDeviceToolContext

    var name: String { "write_article" }
    var description: String { "Write changes to the current article or a specific article by UUID. By default new content is appended. Set replaceContent to true only when the user explicitly asks to replace the full content." }

    func call(arguments: WriteArticleArguments) async throws -> String {
        onDeviceToolLog("write_article called articleID=\(arguments.articleID ?? "nil"), title=\(arguments.title ?? "nil"), contentLength=\(arguments.content?.count ?? 0), replaceContent=\(arguments.replaceContent ?? false)")
        let writeResult: (changedFields: [String], refreshed: MyArticleModel)? = try await MainActor.run {
            guard let myArticle = context.resolveMyArticle(articleID: arguments.articleID) else {
                return nil
            }

            var updated = try context.encodeToDictionary(myArticle)
            var changedFields: [String] = []

            if let title = arguments.title {
                updated["title"] = title
                changedFields.append("title")
            }

            if let newContent = arguments.content {
                let replaceContent = arguments.replaceContent ?? false
                if replaceContent {
                    updated["content"] = newContent
                } else {
                    let existing = myArticle.content
                    if existing.isEmpty {
                        updated["content"] = newContent
                    } else {
                        updated["content"] = "\(existing)\n\n---\n\n\(newContent)"
                    }
                }
                changedFields.append("content")
            }

            guard !changedFields.isEmpty else {
                return nil
            }

            updated["id"] = myArticle.id.uuidString
            let updatedData = try JSONSerialization.data(withJSONObject: updated, options: [.prettyPrinted, .sortedKeys])
            _ = try JSONDecoder.shared.decode(MyArticleModel.self, from: updatedData)
            try updatedData.write(to: myArticle.path, options: .atomic)

            try context.reloadStoreAndRestoreSelection(preferredArticleID: myArticle.id)
            let refreshed = context.resolveMyArticle(articleID: myArticle.id.uuidString) ?? myArticle
            try context.syncDraftIfExists(for: refreshed)
            return (changedFields, refreshed)
        }

        guard let writeResult else {
            onDeviceToolLog("write_article failed: article not found or no changes")
            return "Error: Article not found or no changes provided."
        }

        if writeResult.changedFields.contains("title") || writeResult.changedFields.contains("content") {
            let articleBox = OnDeviceUncheckedSendableBox(writeResult.refreshed)
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                DispatchQueue.global(qos: .utility).async {
                    do {
                        try articleBox.value.savePublic()
                        continuation.resume(returning: ())
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            await MainActor.run {
                NotificationCenter.default.post(name: .loadArticle, object: nil)
            }
        }

        let result = "Updated fields: \(writeResult.changedFields.joined(separator: ", "))"
        onDeviceToolLog("write_article success: \(result)")
        return result
    }
}

// MARK: - Read Planet Tool

@available(macOS 26.0, *)
struct ReadPlanetTool: Tool {
    let context: OnDeviceToolContext

    var name: String { "read_planet" }
    var description: String { "Read the current planet's settings or a specific planet by UUID. Returns planet properties as JSON." }

    func call(arguments: ReadPlanetArguments) async throws -> String {
        try await MainActor.run {
            guard let planet = context.resolveMyPlanet(planetID: arguments.planetID) else {
                return "Error: Planet not found."
            }
            let full = try context.encodeToDictionary(planet)
            let filtered = context.filter(dictionary: full, fields: arguments.fields)
            let data = try JSONSerialization.data(withJSONObject: filtered, options: [.prettyPrinted, .sortedKeys])
            return String(data: data, encoding: .utf8) ?? "Error: Failed to encode planet."
        }
    }
}

// MARK: - Write Planet Tool

@available(macOS 26.0, *)
struct WritePlanetTool: Tool {
    let context: OnDeviceToolContext

    var name: String { "write_planet" }
    var description: String { "Write changes to the current planet's settings or a specific planet by UUID." }

    func call(arguments: WritePlanetArguments) async throws -> String {
        try await MainActor.run {
            guard let planet = context.resolveMyPlanet(planetID: arguments.planetID) else {
                return "Error: Planet not found."
            }

            var updated = try context.encodeToDictionary(planet)
            var changedFields: [String] = []

            if let name = arguments.name {
                updated["name"] = name
                changedFields.append("name")
            }

            if let about = arguments.about {
                updated["about"] = about
                changedFields.append("about")
            }

            guard !changedFields.isEmpty else {
                return "Error: No changes provided."
            }

            updated["id"] = planet.id.uuidString
            let updatedData = try JSONSerialization.data(withJSONObject: updated, options: [.prettyPrinted, .sortedKeys])
            _ = try JSONDecoder.shared.decode(MyPlanetModel.self, from: updatedData)
            try updatedData.write(to: planet.infoPath, options: .atomic)

            try context.reloadStoreAndRestoreSelection(preferredArticleID: nil)

            return "Updated fields: \(changedFields.joined(separator: ", "))"
        }
    }
}

// MARK: - Search Articles Tool

@available(macOS 26.0, *)
struct SearchArticlesTool: Tool {
    var name: String { "search_articles" }
    var description: String { "Search across all articles by keyword or topic. Returns matching article titles and previews." }

    func call(arguments: SearchArticlesArguments) async throws -> String {
        let limit = min(50, max(1, arguments.limit ?? 10))
        let allResults = await PlanetStore.shared.searchAllArticles(text: arguments.query)

        var filtered = allResults
        if let planetIDString = arguments.planetID,
           let planetUUID = UUID(uuidString: planetIDString) {
            filtered = filtered.filter { $0.planetID == planetUUID }
        }

        let limited = Array(filtered.prefix(limit))
        if limited.isEmpty {
            return "No articles found matching \"\(arguments.query)\"."
        }

        let lines = limited.map { result in
            let chatLink = "planet://article/\(result.planetKind.rawValue)/\(result.planetID.uuidString)/\(result.articleID.uuidString)"
            return """
            - title: \(result.title)
              planet: \(result.planetName)
              planet_kind: \(result.planetKind.rawValue)
              planet_id: \(result.planetID.uuidString)
              article_id: \(result.articleID.uuidString)
              chat_link: \(chatLink)
              preview: \(result.preview)
            """
        }
        return "Found \(filtered.count) result(s):\n\(lines.joined(separator: "\n"))"
    }
}

// MARK: - Helper

private final class OnDeviceUncheckedSendableBox<Value>: @unchecked Sendable {
    let value: Value
    init(_ value: Value) {
        self.value = value
    }
}

// MARK: - Factory

@available(macOS 26.0, *)
enum OnDeviceToolFactory {
    @MainActor
    static func makeTools(articleID: UUID?, planetID: UUID?) -> (tools: [any Tool], context: OnDeviceToolContext) {
        let context = OnDeviceToolContext(articleID: articleID, planetID: planetID)
        let tools: [any Tool] = [
            ReadArticleTool(context: context),
            WriteArticleTool(context: context),
            ReadPlanetTool(context: context),
            WritePlanetTool(context: context),
            SearchArticlesTool(),
        ]
        return (tools, context)
    }
}

#endif
