//
//  PlanetImportViewModel.swift
//  Planet
//
//  Created by Kai on 6/20/25.
//

import Foundation
import SwiftUI
import Markdown


struct InlineResourceCollector: MarkupVisitor {
    var links: [Markdown.Link] = []
    var images: [Markdown.Image] = []
    var htmlBlocks: [Markdown.HTMLBlock] = []

    mutating func visitLink(_ link: Markdown.Link) {
        links.append(link)
        visitChildren(of: link)
    }

    mutating func visitImage(_ image: Markdown.Image) {
        images.append(image)
        visitChildren(of: image)
    }

    mutating func visitHTMLBlock(_ htmlBlock: Markdown.HTMLBlock) {
        htmlBlocks.append(htmlBlock)
    }

    mutating func defaultVisit(_ markup: Markdown.Markup) {
        visitChildren(of: markup)
    }

    private mutating func visitChildren(of markup: Markdown.Markup) {
        for child in markup.children {
            let _ = visit(child)
        }
    }
}


enum InlineResourceType {
    case image
    case audio
    case video
    case file

    private func regexPatternForElement() -> String {
        switch self {
        case .image:
            return #"<img\s+[^>]*src="([^"]+)""#
        case .audio:
            return #"<audio\s+[^>]*src="([^"]+)""#
        case .video:
            return #"<video\s+[^>]*src="([^"]+)""#
        case .file:
            return #"<a\s+[^>]*href="([^"]+\.(zip|rar|7z|tar|gz|bz2|pdf|docx?|xlsx?|pptx?|csv|txt|mp3|wav|mp4|mov|avi|mkv|flac|jpg|jpeg|png|gif|bmp|svg|webp|swift|c|cpp|h|py|js|json|xml|html?|css|exe|dmg|app|apk|msi))"[^>]*>"#
        }
    }

    func extractSourcesFromHTMLBlock(_ htmlBlocks: [Markdown.HTMLBlock]) -> [String] {
        let pattern = self.regexPatternForElement()
        var sources: [String] = []
        for htmlBlock in htmlBlocks {
            let htmlContent = htmlBlock.rawHTML
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: htmlContent, options: [], range: NSRange(htmlContent.startIndex..., in: htmlContent))
                for match in matches {
                    if let range = Range(match.range(at: 1), in: htmlContent) {
                        sources.append(String(htmlContent[range]))
                    }
                }
            }
        }
        return sources
    }
}


class PlanetImportViewModel: ObservableObject {
    static let shared = PlanetImportViewModel()

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

    func validateMarkdown(_ url: URL) async -> Bool {
        Task { @MainActor in
            if !validating.contains(url) {
                validating.append(url)
            }
        }
        defer {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                validating = validating.filter({ $0 != url })
            }
        }
        return false
    }

    func prepareToImport() async throws {
        let url = try importDirectory()
        debugPrint("prepare to import at url: \(url)")
    }

    func cancelImport() {
        Task { @MainActor in
            PlanetImportManager.shared.cancelImport()
        }
        do {
            let url = try importDirectory()
            try FileManager.default.removeItem(at: url)
        } catch {
            debugPrint("failed to clean up temp import directory: \(error)")
        }
    }

    // MARK: -

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

    private func extractImageSourcesFromHTMLBlock(_ htmlBlocks: [Markdown.HTMLBlock]) -> [String] {
        return InlineResourceType.image.extractSourcesFromHTMLBlock(htmlBlocks)
    }

    private func extractVideoSourcesFromHTMLBlock(_ htmlBlocks: [Markdown.HTMLBlock]) -> [String] {
        return InlineResourceType.video.extractSourcesFromHTMLBlock(htmlBlocks)
    }

    private func extractAudioSources(_ htmlBlocks: [Markdown.HTMLBlock]) -> [String] {
        return InlineResourceType.audio.extractSourcesFromHTMLBlock(htmlBlocks)
    }

    private func extractFileSources(_ htmlBlocks: [Markdown.HTMLBlock]) -> [String] {
        return InlineResourceType.file.extractSourcesFromHTMLBlock(htmlBlocks)
    }
}
