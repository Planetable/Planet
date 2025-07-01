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
    @Published var previewURL: URL?

    @Published private(set) var markdownURLs: [URL] = []
    @Published private(set) var validating: [URL] = []
    @Published private(set) var importUUID: UUID = UUID()

    @MainActor
    func updateMarkdownURLs(_ urls: [URL]) {
        importUUID = UUID()
        validating.removeAll()
        markdownURLs = urls
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
        let baseMarkdownURL = markdownURL.deletingLastPathComponent()
        let localURLs = try getLocalURLs(fromMarkdown: markdownURL)
        let unaccessibleLocalSources = localURLs.filter { url in
            if isResourceAccessible(withBaseURL: baseMarkdownURL, url: url) {
                Self.logger.info(.init(stringLiteral: "\(url.path) is accessible"))
                return false
            }
            Self.logger.info(.init(stringLiteral: "\(url.path) is inaccessible"))
            return true
        }
        Self.logger.info(.init(stringLiteral: "Unaccessible Local Sources:"))
        Self.logger.info(.init(stringLiteral: unaccessibleLocalSources.map({ $0.absoluteString }).joined(separator: ", ")))
        return unaccessibleLocalSources.isEmpty
    }

    func titleFromMarkdown(_ markdownURL: URL) throws -> String {
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

    func dateFromMarkdown(_ markdownURL: URL) throws -> Date {
        let attributes = try FileManager.default.attributesOfItem(atPath: markdownURL.path)
        return attributes[FileAttributeKey.creationDate] as! Date
    }

    func contentFromMarkdown(_ markdownURL: URL) throws -> String {
        return try String(contentsOf: markdownURL, encoding: .utf8).trim()
    }

    func prepareToImport() async throws {
        let url = try importDirectory()
        debugPrint("prepare to import at url: \(url)")
    }

    func cancelImport() {
        Task { @MainActor in
            PlanetImportManager.shared.dismiss()
        }
        cleanup()
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

    private func importDirectory() throws -> URL {
        let tempURL = URLUtils.temporaryPath.appendingPathComponent("ImportMarkdownFiles")
        if !FileManager.default.fileExists(atPath: tempURL.path) {
            try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)
        }
        let importURL = tempURL.appendingPathComponent(importUUID.uuidString)
        if FileManager.default.fileExists(atPath: importURL.path) {
            try FileManager.default.removeItem(at: importURL)
        }
        try FileManager.default.createDirectory(at: importURL, withIntermediateDirectories: true)
        return importURL
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

    private func isResourceAccessible(withBaseURL baseURL: URL, url: URL) -> Bool {
        return FileManager.default.fileExists(atPath: baseURL.appendingPathComponent(url.path).path) || FileManager.default.fileExists(atPath: url.path)
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
