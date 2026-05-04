//
//  ArticleAIOnDeviceTools.swift
//  Planet
//
//  Created with AI assistance on 3/31/26.
//

import Foundation

struct ArticleAIRepoGrepRequest: Sendable {
    let pattern: String
    let path: String?
    let literal: Bool
    let caseSensitive: Bool
    let maxResults: Int
}

struct ArticleAIRepoGrepMatch: Sendable {
    let path: String
    let line: Int
    let column: Int
    let text: String

    var jsonObject: [String: Any] {
        [
            "path": path,
            "line": line,
            "column": column,
            "text": text,
        ]
    }
}

struct ArticleAIRepoGrepResult: Sendable {
    let pattern: String
    let searchRoot: String
    let literal: Bool
    let caseSensitive: Bool
    let filesScanned: Int
    let totalMatches: Int
    let truncated: Bool
    let matches: [ArticleAIRepoGrepMatch]

    var jsonObject: [String: Any] {
        [
            "ok": true,
            "pattern": pattern,
            "search_root": searchRoot,
            "literal": literal,
            "case_sensitive": caseSensitive,
            "files_scanned": filesScanned,
            "total_matches": totalMatches,
            "returned_matches": matches.count,
            "truncated": truncated,
            "matches": matches.map { $0.jsonObject },
        ]
    }

    func jsonString() -> String {
        guard JSONSerialization.isValidJSONObject(jsonObject),
            let data = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys]),
            let text = String(data: data, encoding: .utf8)
        else {
            return #"{"ok":false,"error":"Failed to encode grep result."}"#
        }
        return text
    }
}

private struct ArticleAIRepoGrepError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}

enum ArticleAIRepoGrep {
    private static let maxFileSizeBytes = 2_000_000
    private static let maxPreviewLength = 400

    static func searchAsync(request: ArticleAIRepoGrepRequest, repoRoot: URL) async throws -> ArticleAIRepoGrepResult {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    let result = try search(request: request, repoRoot: repoRoot)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    static func search(request: ArticleAIRepoGrepRequest, repoRoot: URL) throws -> ArticleAIRepoGrepResult {
        let pattern = request.pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pattern.isEmpty else {
            throw ArticleAIRepoGrepError(message: "Missing required `pattern`.")
        }

        let resolvedRepoRoot = repoRoot.standardizedFileURL.resolvingSymlinksInPath()
        let searchRoot = try resolveSearchRoot(input: request.path, repoRoot: resolvedRepoRoot)
        let maxResults = min(200, max(1, request.maxResults))
        let regex: NSRegularExpression?
        if request.literal {
            regex = nil
        } else {
            do {
                regex = try NSRegularExpression(
                    pattern: pattern,
                    options: request.caseSensitive ? [] : [.caseInsensitive]
                )
            } catch {
                throw ArticleAIRepoGrepError(message: "Invalid regex pattern: \(error.localizedDescription)")
            }
        }

        var filesScanned = 0
        var matches: [ArticleAIRepoGrepMatch] = []
        var truncated = false
        let fileManager = FileManager.default

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: searchRoot.path, isDirectory: &isDirectory) else {
            throw ArticleAIRepoGrepError(message: "Path does not exist: \(searchRoot.path)")
        }

        if isDirectory.boolValue {
            let resourceKeys: Set<URLResourceKey> = [
                .isDirectoryKey,
                .isRegularFileKey,
                .isSymbolicLinkKey,
                .fileSizeKey,
            ]
            guard let enumerator = fileManager.enumerator(
                at: searchRoot,
                includingPropertiesForKeys: Array(resourceKeys),
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                throw ArticleAIRepoGrepError(message: "Failed to enumerate files under \(searchRoot.path)")
            }

            while let fileURL = enumerator.nextObject() as? URL {
                if matches.count >= maxResults {
                    truncated = true
                    break
                }

                let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys)
                if resourceValues?.isDirectory == true {
                    if fileURL.lastPathComponent == ".git" {
                        enumerator.skipDescendants()
                    }
                    continue
                }
                if resourceValues?.isSymbolicLink == true {
                    continue
                }
                guard resourceValues?.isRegularFile == true else {
                    continue
                }
                if let fileSize = resourceValues?.fileSize, fileSize > maxFileSizeBytes {
                    continue
                }
                if searchFile(
                    fileURL,
                    repoRoot: resolvedRepoRoot,
                    pattern: pattern,
                    literal: request.literal,
                    caseSensitive: request.caseSensitive,
                    regex: regex,
                    maxResults: maxResults,
                    matches: &matches
                ) {
                    filesScanned += 1
                }
            }
        } else {
            if searchFile(
                searchRoot,
                repoRoot: resolvedRepoRoot,
                pattern: pattern,
                literal: request.literal,
                caseSensitive: request.caseSensitive,
                regex: regex,
                maxResults: maxResults,
                matches: &matches
            ) {
                filesScanned += 1
            }
        }

        if matches.count >= maxResults {
            truncated = true
        }

        return ArticleAIRepoGrepResult(
            pattern: pattern,
            searchRoot: searchRoot.path,
            literal: request.literal,
            caseSensitive: request.caseSensitive,
            filesScanned: filesScanned,
            totalMatches: matches.count,
            truncated: truncated,
            matches: matches
        )
    }

    private static func resolveSearchRoot(input: String?, repoRoot: URL) throws -> URL {
        guard let input, !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return repoRoot
        }

        let candidate: URL
        if input.hasPrefix("/") {
            candidate = URL(fileURLWithPath: input)
        } else {
            candidate = repoRoot.appendingPathComponent(input)
        }
        let resolved = candidate.standardizedFileURL.resolvingSymlinksInPath()
        let repoRootPath = repoRoot.path
        let resolvedPath = resolved.path
        let insideRoot = resolvedPath == repoRootPath || resolvedPath.hasPrefix(repoRootPath + "/")
        guard insideRoot else {
            throw ArticleAIRepoGrepError(message: "`path` must stay under \(repoRootPath)")
        }
        guard FileManager.default.fileExists(atPath: resolvedPath) else {
            throw ArticleAIRepoGrepError(message: "Path does not exist: \(resolvedPath)")
        }
        return resolved
    }

    @discardableResult
    private static func searchFile(
        _ fileURL: URL,
        repoRoot: URL,
        pattern: String,
        literal: Bool,
        caseSensitive: Bool,
        regex: NSRegularExpression?,
        maxResults: Int,
        matches: inout [ArticleAIRepoGrepMatch]
    ) -> Bool {
        guard let text = loadSearchableText(from: fileURL) else {
            return false
        }

        let remaining = maxResults - matches.count
        guard remaining > 0 else {
            return true
        }

        let relativePath = makeRelativePath(fileURL, repoRoot: repoRoot)
        var lineNumber = 0
        var localMatches: [ArticleAIRepoGrepMatch] = []
        text.enumerateLines { line, stop in
            if localMatches.count >= remaining {
                stop = true
                return
            }

            lineNumber += 1
            let remainingForLine = remaining - localMatches.count
            guard remainingForLine > 0 else {
                stop = true
                return
            }

            let columns = matchColumns(
                in: line,
                pattern: pattern,
                literal: literal,
                caseSensitive: caseSensitive,
                regex: regex,
                limit: remainingForLine
            )
            guard !columns.isEmpty else {
                return
            }

            let preview = truncatedPreview(for: line)
            for column in columns {
                localMatches.append(
                    ArticleAIRepoGrepMatch(
                        path: relativePath,
                        line: lineNumber,
                        column: column,
                        text: preview
                    )
                )
            }

            if localMatches.count >= remaining {
                stop = true
            }
        }
        matches.append(contentsOf: localMatches)
        return true
    }

    private static func makeRelativePath(_ fileURL: URL, repoRoot: URL) -> String {
        let rootPath = repoRoot.path
        let filePath = fileURL.standardizedFileURL.resolvingSymlinksInPath().path
        if filePath == rootPath {
            return fileURL.lastPathComponent
        }
        if filePath.hasPrefix(rootPath + "/") {
            return String(filePath.dropFirst(rootPath.count + 1))
        }
        return fileURL.lastPathComponent
    }

    private static func loadSearchableText(from fileURL: URL) -> String? {
        guard let data = try? Data(contentsOf: fileURL, options: [.mappedIfSafe]) else {
            return nil
        }
        guard !isProbablyBinary(data) else {
            return nil
        }
        if let text = String(data: data, encoding: .utf8) {
            return text
        }
        if let text = String(data: data, encoding: .utf16) {
            return text
        }
        if let text = String(data: data, encoding: .utf16LittleEndian) {
            return text
        }
        if let text = String(data: data, encoding: .utf16BigEndian) {
            return text
        }
        return nil
    }

    private static func isProbablyBinary(_ data: Data) -> Bool {
        let prefix = data.prefix(1024)
        return prefix.contains(0)
    }

    private static func matchColumns(
        in line: String,
        pattern: String,
        literal: Bool,
        caseSensitive: Bool,
        regex: NSRegularExpression?,
        limit: Int
    ) -> [Int] {
        guard limit > 0 else {
            return []
        }

        if literal {
            let options: String.CompareOptions = caseSensitive ? [] : [.caseInsensitive]
            var columns: [Int] = []
            var searchStart = line.startIndex

            while searchStart < line.endIndex,
                columns.count < limit,
                let range = line.range(of: pattern, options: options, range: searchStart..<line.endIndex)
            {
                columns.append(line.distance(from: line.startIndex, to: range.lowerBound) + 1)
                searchStart = range.isEmpty ? line.index(after: searchStart) : range.upperBound
            }

            return columns
        }

        let searchRange = NSRange(line.startIndex..<line.endIndex, in: line)
        var columns: [Int] = []
        regex?.enumerateMatches(in: line, options: [], range: searchRange) { match, _, stop in
            guard let match,
                let range = Range(match.range, in: line)
            else {
                return
            }

            columns.append(line.distance(from: line.startIndex, to: range.lowerBound) + 1)
            if columns.count >= limit {
                stop.pointee = true
            }
        }
        return columns
    }

    private static func truncatedPreview(for line: String) -> String {
        if line.count <= maxPreviewLength {
            return line
        }
        return String(line.prefix(maxPreviewLength)) + "..."
    }
}

#if canImport(FoundationModels)

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
    @Guide(description: "Search query. Supports phrases in quotes and -negation. Use for semantic/topic search where wording may differ; for exact dates, IDs, title fragments, URLs, quoted text, or other literal tokens, use grep first.")
    var query: String
    @Guide(description: "Maximum number of results to return. Defaults to 10, max 50.")
    var limit: Int?
    @Guide(description: "Optional UUID of a planet to restrict search to.")
    var planetID: String?
}

@available(macOS 26.0, *)
@Generable(description: "Arguments for grep-style library search")
struct GrepArguments: Sendable {
    @Guide(description: "Required search pattern. For exact tokens from the user, pass the exact spelling and punctuation first, including date-like strings such as 2026-1-1. Leave literal as true unless regex is explicitly needed.")
    var pattern: String
    @Guide(description: "Optional relative file or directory under the Planet library root to search. Defaults to the library root.")
    var path: String?
    @Guide(description: "Optional. Treat pattern as literal text. Defaults to true; keep true for exact user-provided dates, IDs, titles, URLs, quoted text, identifiers, symbols, setting keys, and phrases.")
    var literal: Bool?
    @Guide(description: "Optional. Case-sensitive matching. Defaults to false.")
    var caseSensitive: Bool?
    @Guide(description: "Optional. Maximum matches to return. Defaults to 20, max 200.")
    var maxResults: Int?
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
    var description: String { "Read the current article or a specific article by UUID. Returns article properties as JSON, including chat_link metadata for linking in responses." }

    func call(arguments: ReadArticleArguments) async throws -> String {
        onDeviceToolLog("read_article called articleID=\(arguments.articleID ?? "nil"), fields=\(arguments.fields ?? [])")
        let result: String = try await MainActor.run {
            guard let myArticle = context.resolveMyArticle(articleID: arguments.articleID) else {
                return "Error: Article not found."
            }
            let full = try context.encodeToDictionary(myArticle)
            var filtered = context.filter(dictionary: full, fields: arguments.fields)
            filtered["article_id"] = myArticle.id.uuidString
            filtered["planet_id"] = myArticle.planet.id.uuidString
            filtered["planet_kind"] = PlanetKind.my.rawValue
            filtered["chat_link"] = "planet://article/\(PlanetKind.my.rawValue)/\(myArticle.planet.id.uuidString)/\(myArticle.id.uuidString)"
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
    var description: String { "Search across all articles by keyword or topic. Use for semantic/topic searches where wording may differ; for exact dates, IDs, title fragments, URLs, file paths, quoted text, or other literal tokens, use grep first." }

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

// MARK: - Grep Tool

@available(macOS 26.0, *)
struct GrepTool: Tool {
    var name: String { "grep" }
    var description: String { "Search text files in the Planet library for an exact string or regex. Best first tool for exact literal lookups such as dates, title fragments, quoted text, URLs, domains, file paths, UUIDs/IDs, tags, numbers, identifiers, symbols, proper nouns, and setting keys." }

    func call(arguments: GrepArguments) async throws -> String {
        let request = ArticleAIRepoGrepRequest(
            pattern: arguments.pattern,
            path: arguments.path,
            literal: arguments.literal ?? true,
            caseSensitive: arguments.caseSensitive ?? false,
            maxResults: arguments.maxResults ?? 20
        )
        onDeviceToolLog(
            "grep called pattern=\(arguments.pattern), path=\(arguments.path ?? "nil"), literal=\(arguments.literal ?? true), caseSensitive=\(arguments.caseSensitive ?? false), maxResults=\(arguments.maxResults ?? 20)"
        )
        do {
            let result = try await ArticleAIRepoGrep.searchAsync(request: request, repoRoot: URLUtils.repoPath())
            onDeviceToolLog(
                "grep result matches=\(result.totalMatches), filesScanned=\(result.filesScanned), truncated=\(result.truncated)"
            )
            return result.jsonString()
        } catch {
            onDeviceToolLog("grep failed: \(error.localizedDescription)")
            let payload: [String: Any] = [
                "ok": false,
                "error": error.localizedDescription,
            ]
            guard JSONSerialization.isValidJSONObject(payload),
                let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
                let text = String(data: data, encoding: .utf8)
            else {
                return #"{"ok":false,"error":"Failed to encode grep error."}"#
            }
            return text
        }
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
            GrepTool(),
        ]
        return (tools, context)
    }
}

#endif
