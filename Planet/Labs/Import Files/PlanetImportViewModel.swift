//
//  PlanetImportViewModel.swift
//  Planet
//
//  Created by Kai on 6/20/25.
//

import Foundation
import SwiftUI
import Logging


enum InlineResourceType {
    case image
    case audio
    case video
    case file
    case markdownLink
    case markdownImage

    func regexPattern() -> String {
        switch self {
        case .image:
            return #"<img\s+[^>]*src="([^"]+)""#
        case .audio:
            return #"<audio\s+[^>]*src="([^"]+)""#
        case .video:
            return #"<video\s+[^>]*src="([^"]+)""#
        case .file:
            // MARK: TODO: add from UTType
            return #"<a\s+[^>]*href="([^"]+\.(zip|rar|7z|tar|gz|bz2|pdf|docx?|xlsx?|pptx?|csv|sh|txt|mp3|wav|mp4|mov|avi|mkv|flac|jpg|jpeg|png|gif|bmp|svg|webp|swift|c|cpp|h|py|js|json|xml|html?|css|exe|dmg|app|apk|msi))"[^>]*>"#
        case .markdownLink:
            return #"\[([^\]]*)\]\(([^)]+)\)"#
        case .markdownImage:
            return #"!\[([^\]]*)\]\(([^)]+)\)"#
        }
    }

    // MARK: -

    func extractSourcesFromHTMLContent(_ htmlContent: String) -> [URL] {
        let pattern = self.regexPattern()
        var sources: [URL] = []

        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let matches = regex.matches(in: htmlContent, options: [], range: NSRange(htmlContent.startIndex..., in: htmlContent))
            for match in matches {
                let rangeIndex = (self == .markdownLink || self == .markdownImage) ? 2 : 1
                if let range = Range(match.range(at: rangeIndex), in: htmlContent) {
                    if let url = URL(string: String(htmlContent[range])) {
                        sources.append(url)
                    }
                }
            }
        }
        return sources
    }
}


class PlanetImportViewModel: ObservableObject {
    static let shared = PlanetImportViewModel()

    static let logger = Logger(label: "Import Markdown Files")

    @Published var showingPreview: Bool = false
    @Published var previewMarkdownURL: URL?

    @Published private(set) var markdownURLs: [URL] = []
    @Published private(set) var missingResources: [String: [URL]] = [:]
    @Published private(set) var validating: [URL] = []
    @Published private(set) var importUUID: UUID = UUID()
    @Published private(set) var previewUpdated: Date = Date()

    @MainActor
    func updateMarkdownURLs(_ urls: [URL]) {
        importUUID = UUID()
        validating.removeAll()
        missingResources.removeAll()
        markdownURLs = urls
    }

    @MainActor
    func reloadResources() {
        missingResources.removeAll()
        previewUpdated = Date()
    }

    func updateResource(_ url: URL, forMarkdown markdownURL: URL) throws {
        let markdownFilenameMD5 = markdownURL.lastPathComponent.md5()
        let importURL = try importDirectory().appendingPathComponent(markdownFilenameMD5)
        if !FileManager.default.fileExists(atPath: importURL.path) {
            try FileManager.default.createDirectory(at: importURL, withIntermediateDirectories: true)
        }
        let targetURL = importURL.appendingPathComponent(url.lastPathComponent)
        try FileManager.default.copyItem(at: url, to: targetURL)
        Task.detached {
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run {
                self.reloadResources()
            }
        }
    }

    func validateMarkdown(_ markdownURL: URL) async throws -> Bool {
        Task { @MainActor in
            if !validating.contains(markdownURL) {
                validating.append(markdownURL)
            }
        }
        defer {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000)
                validating = validating.filter({ $0 != markdownURL })
            }
        }
        let localURLs = try getLocalURLs(fromMarkdown: markdownURL)
        let key = markdownURL.absoluteString.md5()
        let unaccessibleLocalSources = localURLs.filter { url in
            if isResourceAccessible(url, forMarkdown: markdownURL) {
                Self.logger.info(.init(stringLiteral: "\(url.path) is accessible"))
                return false
            }
            Self.logger.info(.init(stringLiteral: "\(url.path) is inaccessible"))
            Task.detached(priority: .utility) {
                await MainActor.run {
                    self.updateMissingResource(url, forKey: key)
                }
            }
            return true
        }
        Self.logger.info(.init(stringLiteral: "Unaccessible Local Sources:"))
        Self.logger.info(.init(stringLiteral: unaccessibleLocalSources.map({ $0.absoluteString }).joined(separator: ", ")))
        return unaccessibleLocalSources.isEmpty
    }

    func localResourcesFromMarkdown(_ markdownURL: URL) throws -> [URL] {
        return try getLocalURLs(fromMarkdown: markdownURL)
    }

    func updatedLocalResource(_ url: URL, forMarkdown markdownURL: URL) -> URL? {
        // MARK: TODO: return updated url for this markdown.
        return nil
    }

    func prepareToImport() async throws {
        let url = try importDirectory()
        Self.logger.info("Prepare to import markdown files at temp directory: \(url)")
    }

    func cancelImport() {
        Task { @MainActor in
            PlanetImportManager.shared.dismiss()
        }
        Task.detached(priority: .background) {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            self.cleanup()
        }
    }

    func importToPlanet(_ planet: MyPlanetModel) {
        defer {
            cancelImport()
        }

        Self.logger.info(.init(stringLiteral: "About to import to planet: \(planet.name)"))

        var importArticles: [MyArticleModel] = []
        for url in markdownURLs {
            Self.logger.info(.init(stringLiteral: "Process and import markdown: \(url) ..."))
            do {
                let title = try titleFromMarkdown(url)
                let date = try dateFromMarkdown(url)
                let content = try contentFromMarkdown(url)
                let article = try MyArticleModel.compose(
                    link: nil,
                    date: date,
                    title: title,
                    content: content,
                    summary: nil,
                    planet: planet
                )
                // Add local resources as attachments
                let resources = try localResourcesFromMarkdown(url)
                Self.logger.info("Process local resources: \(resources.map({ $0.absoluteString }).joined(separator: ", "))")
                if resources.count > 0 {
                    var attachments: [String] = []
                    var multiLevelResources: [URL: String] = [:]
                    for resourceURL in resources {
                        let filename: String?
                        let sourceURL: URL?
                        let targetURL: URL?
                        if !FileManager.default.fileExists(atPath: resourceURL.path) {
                            // Multi-level inline resources
                            let baseURL = url.deletingLastPathComponent()
                            let baseResourceURL = baseURL.appendingPathComponent(resourceURL.path)
                            if FileManager.default.fileExists(atPath: baseResourceURL.path) {
                                /*
                                 Handle multi-level inline resources when importing Markdown
                                    - Flatten nested resource paths (e.g. resource/screenshots/1.png → resource-screenshots-1.png)
                                    - Rewrite article content to reference the renamed attachments
                                 */
                                let components = resourceURL.path.split(separator: "/")
                                let singleLevelFilename = components.joined(separator: "-")
                                filename = singleLevelFilename
                                sourceURL = baseResourceURL
                                targetURL = article.publicBasePath.appendingPathComponent(singleLevelFilename)
                                if components.count > 1 {
                                    multiLevelResources[resourceURL] = singleLevelFilename
                                }
                            }
                            // User updated inline resources
                            else if let updatedResourceURL = updatedLocalResource(resourceURL, forMarkdown: url) {
                                filename = url.lastPathComponent
                                sourceURL = updatedResourceURL
                                targetURL = article.publicBasePath.appendingPathComponent(url.lastPathComponent)
                            }
                            else {
                                continue
                            }
                        } else {
                            filename = url.lastPathComponent
                            sourceURL = resourceURL
                            targetURL = article.publicBasePath.appendingPathComponent(url.lastPathComponent)
                        }
                        if let filename, let sourceURL, let targetURL {
                            try copySelectedFile(sourceURL, to: targetURL)
                            attachments.append(filename)
                        }
                    }
                    article.attachments = attachments
                    // Update article content by replacing multi-level inline resources
                    if multiLevelResources.keys.count > 1 {
                        Self.logger.info("Multi-level resources: urls: \(multiLevelResources.keys.map( {$0.absoluteString}).joined(separator: ", ")), names: \(multiLevelResources.values.joined(separator: ", "))")
                        multiLevelResources.forEach { url, filename in
                            article.content = article.content.replacingOccurrences(of: url.path, with: filename)
                        }
                    }
                } else {
                    article.attachments = []
                }
                article.tags = [:]
                importArticles.append(article)
            } catch {
                Self.logger.info(.init(stringLiteral: "Failed to import markdown: \(url), error: \(error)"))
                failedToImport(error: error)
            }
        }

        guard importArticles.count > 0 else {
            Self.logger.info(.init(stringLiteral: "Markdown files not found, abort importing."))
            return
        }

        var articles = planet.articles
        articles?.append(contentsOf: importArticles)
        articles?.sort(by: { MyArticleModel.reorder(a: $0, b: $1) })
        planet.articles = articles

        for article in importArticles {
            do {
                try article.save()
                try article.savePublic()
            } catch {
                Self.logger.info(.init(stringLiteral: "Failed to import article: \(article.title), error: \(error)"))
            }
        }

        do {
            try planet.copyTemplateAssets()
            planet.updated = Date()
            try planet.save()
            Task(priority: .userInitiated) {
                try await planet.savePublic()
                try await planet.publish()
            }
        } catch {
            Self.logger.info(.init(stringLiteral: "Failed to save target planet, error: \(error)"))
        }

        Task { @MainActor in
            PlanetStore.shared.selectedView = .myPlanet(planet)
            PlanetStore.shared.refreshSelectedArticles()
        }

        Self.logger.info(.init(stringLiteral: "Imported markdown files."))
    }

    func failedToImport(error: Error) {
        let alert = NSAlert()
        alert.messageText = "Failed to Import Files"
        alert.informativeText = error.localizedDescription
        alert.runModal()
        cancelImport()
    }

    // MARK: -

    private func cleanup() {
        do {
            let url = try importDirectory()
            try FileManager.default.removeItem(at: url)
        } catch {
            debugPrint("failed to clean up temp import directory: \(error)")
        }
    }

    @MainActor
    private func updateMissingResource(_ url: URL, forKey key: String) {
        if self.missingResources[key] == nil {
            self.missingResources[key] = []
        }
        if let urls: [URL] = self.missingResources[key] {
            if !urls.contains(url) {
                self.missingResources[key]?.append(url)
            }
        }
        guard validating.count == 0 else { return }
        previewUpdated = Date()
    }

    private func importDirectory() throws -> URL {
        let tempURL = URLUtils.temporaryPath.appendingPathComponent("ImportMarkdownFiles")
        if !FileManager.default.fileExists(atPath: tempURL.path) {
            try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)
        }
        let importURL = tempURL.appendingPathComponent(importUUID.uuidString)
        if !FileManager.default.fileExists(atPath: importURL.path) {
            try FileManager.default.createDirectory(at: importURL, withIntermediateDirectories: true)
        }
        return importURL
    }

    private func copySelectedFile(_ sourceURL: URL, to targetURL: URL) throws {
        guard sourceURL.startAccessingSecurityScopedResource() else {
            throw NSError(domain: NSCocoaErrorDomain,
                          code: NSFileReadNoPermissionError,
                          userInfo: [NSLocalizedDescriptionKey : "Sandbox read permission denied at: \(sourceURL.path)"])
        }
        defer {
            sourceURL.stopAccessingSecurityScopedResource()
        }
        try FileManager.default.copyItem(at: sourceURL, to: targetURL)
    }

    private func isResourceLocalURL(_ url: URL) -> Bool {
        // Proper file URLs
        if url.isFileURL {
            return true
        }

        // No scheme & no host  →  root or relative path
        if url.scheme == nil, url.host == nil {
            return true
        }

        // Windows drive-letter path parsed as scheme “C”, “D”
        if let s = url.scheme, s.count == 1, s.first!.isLetter {
            return true
        }

        // UNC share literally written as \\SERVER\Share\file.png
        if url.absoluteString.hasPrefix("\\\\") {
            return true
        }

        return false
    }

    private func isResourceAccessible(_ url: URL, forMarkdown markdownURL: URL) -> Bool {
        do {
            let baseURL = markdownURL.deletingLastPathComponent()
            Self.logger.info("Is resource available: \(url), base url: \(baseURL)")
            let exists = FileManager.default.fileExists(atPath: baseURL.appendingPathComponent(url.path).path) || FileManager.default.fileExists(atPath: url.path)
            if exists {
                Self.logger.info("Resource available at: \(url)")
                return true
            } else {
                // Validate one more time in re-located directory if user has updated this resource manually.
                let markdownFilenameMD5 = markdownURL.lastPathComponent.md5()
                let importURL = try importDirectory().appendingPathComponent(markdownFilenameMD5)
                let updatedURL = importURL.appendingPathComponent(url.lastPathComponent)
                let flag = FileManager.default.fileExists(atPath: updatedURL.path)
                if flag {
                    Self.logger.info("Updated resource available at: \(updatedURL)")
                }
                return flag
            }
        } catch {
            return false
        }
    }

    private func titleFromMarkdown(_ markdownURL: URL) throws -> String {
        let title = markdownURL.deletingPathExtension().lastPathComponent
        if title.count <= 3 {
            let content = try contentFromMarkdown(markdownURL)
            let lines = content.components(separatedBy: .newlines)
            for line in lines {
                if line.hasPrefix("# ") {
                    return line.replacingOccurrences(of: "# ", with: "")
                }
            }
        }
        return title
    }

    private func dateFromMarkdown(_ markdownURL: URL) throws -> Date {
        let attributes = try FileManager.default.attributesOfItem(atPath: markdownURL.path)
        return attributes[FileAttributeKey.creationDate] as! Date
    }

    private func contentFromMarkdown(_ markdownURL: URL) throws -> String {
        return try String(contentsOf: markdownURL, encoding: .utf8).trim()
    }

    private func getLocalURLs(fromMarkdown url: URL) throws -> [URL] {
        let markdownFileName = url.lastPathComponent
        let markdownBaseURL = url.deletingLastPathComponent()
        Self.logger.info(.init(stringLiteral: "Validating markdown file: \(markdownFileName), base url: \(markdownBaseURL)"))

        let markdownContent = try String(contentsOf: url)

        let markdownLinks = extractMarkdownLinksFromContent(markdownContent).filter({ isResourceLocalURL($0) })
        let markdownImages = extractMarkdownImagesFromContent(markdownContent).filter({ isResourceLocalURL($0) })
        let images = extractImageSourcesFromHTMLContent(markdownContent).filter({ isResourceLocalURL($0) })
        let videos = extractVideoSourcesFromHTMLContent(markdownContent).filter({ isResourceLocalURL($0) })
        let audios = extractAudioSourcesFromHTMLContent(markdownContent).filter({ isResourceLocalURL($0) })
        let files = extractFileSourcesFromHTMLContent(markdownContent).filter({ isResourceLocalURL($0) })

        Self.logger.info(.init(stringLiteral: "Local Markdown Links:"))
        Self.logger.info(.init(stringLiteral: markdownLinks.map({ $0.absoluteString }).joined(separator: ", ")))

        Self.logger.info(.init(stringLiteral: "Local Markdown Images:"))
        Self.logger.info(.init(stringLiteral: markdownImages.map({ $0.absoluteString }).joined(separator: ", ")))

        Self.logger.info(.init(stringLiteral: "Local HTML Image Sources:"))
        Self.logger.info(.init(stringLiteral: images.map({ $0.absoluteString }).joined(separator: ", ")))

        Self.logger.info(.init(stringLiteral: "Local HTML Video Sources:"))
        Self.logger.info(.init(stringLiteral: videos.map({ $0.absoluteString }).joined(separator: ", ")))

        Self.logger.info(.init(stringLiteral: "Local HTML Audio Sources:"))
        Self.logger.info(.init(stringLiteral: audios.map({ $0.absoluteString }).joined(separator: ", ")))

        Self.logger.info(.init(stringLiteral: "Local HTML File Sources:"))
        Self.logger.info(.init(stringLiteral: files.map({ $0.absoluteString }).joined(separator: ", ")))

        let uniqueLocalSources = Set(markdownLinks + markdownImages + images + videos + audios + files)
        return Array(uniqueLocalSources) 
    }

    private func extractMarkdownLinksFromContent(_ content: String) -> [URL] {
        return InlineResourceType.markdownLink.extractSourcesFromHTMLContent(content)
    }
    
    private func extractMarkdownImagesFromContent(_ content: String) -> [URL] {
        return InlineResourceType.markdownImage.extractSourcesFromHTMLContent(content)
    }

    private func extractImageSourcesFromHTMLContent(_ content: String) -> [URL] {
        return InlineResourceType.image.extractSourcesFromHTMLContent(content)
    }

    private func extractVideoSourcesFromHTMLContent(_ content: String) -> [URL] {
        return InlineResourceType.video.extractSourcesFromHTMLContent(content)
    }

    private func extractAudioSourcesFromHTMLContent(_ content: String) -> [URL] {
        return InlineResourceType.audio.extractSourcesFromHTMLContent(content)
    }

    private func extractFileSourcesFromHTMLContent(_ content: String) -> [URL] {
        return InlineResourceType.file.extractSourcesFromHTMLContent(content)
    }
}
