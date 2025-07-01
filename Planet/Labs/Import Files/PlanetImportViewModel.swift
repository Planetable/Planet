//
//  PlanetImportViewModel.swift
//  Planet
//
//  Created by Kai on 6/20/25.
//

import Foundation
import SwiftUI


enum InlineResourceType {
    case image
    case audio
    case video
    case file
    case markdownLink
    case markdownImage

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
        case .markdownLink:
            return #"\[([^\]]*)\]\(([^)]+)\)"#
        case .markdownImage:
            return #"!\[([^\]]*)\]\(([^)]+)\)"#
        }
    }

    // MARK: -

    func extractSourcesFromHTMLContent(_ htmlContent: String) -> [String] {
        let pattern = self.regexPatternForElement()
        var sources: [String] = []
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let matches = regex.matches(in: htmlContent, options: [], range: NSRange(htmlContent.startIndex..., in: htmlContent))
            for match in matches {
                let rangeIndex = (self == .markdownLink || self == .markdownImage) ? 2 : 1
                if let range = Range(match.range(at: rangeIndex), in: htmlContent) {
                    sources.append(String(htmlContent[range]))
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

    func validateMarkdown(_ url: URL) async throws -> Bool {
        Task { @MainActor in
            if !validating.contains(url) {
                validating.append(url)
            }
        }
        defer {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000)
                validating = validating.filter({ $0 != url })
            }
        }

        let markdownContent = try String(contentsOf: url)
        let markdownLinks = extractMarkdownLinksFromContent(markdownContent)
        let markdownImages = extractMarkdownImagesFromContent(markdownContent)
        let images = extractImageSourcesFromHTMLContent(markdownContent)
        let videos = extractVideoSourcesFromHTMLContent(markdownContent)
        let audios = extractAudioSourcesFromHTMLContent(markdownContent)
        let files = extractFileSourcesFromHTMLContent(markdownContent)

        debugPrint("markdown links: \(markdownLinks)")
        debugPrint("markdown images: \(markdownImages)")
        debugPrint("image sources: \(images)")
        debugPrint("video sources: \(videos)")
        debugPrint("audio sources: \(audios)")
        debugPrint("file sources: \(files)")

        return true
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

    private func extractMarkdownLinksFromContent(_ content: String) -> [String] {
        return InlineResourceType.markdownLink.extractSourcesFromHTMLContent(content)
    }
    
    private func extractMarkdownImagesFromContent(_ content: String) -> [String] {
        return InlineResourceType.markdownImage.extractSourcesFromHTMLContent(content)
    }

    private func extractImageSourcesFromHTMLContent(_ content: String) -> [String] {
        return InlineResourceType.image.extractSourcesFromHTMLContent(content)
    }

    private func extractVideoSourcesFromHTMLContent(_ content: String) -> [String] {
        return InlineResourceType.video.extractSourcesFromHTMLContent(content)
    }

    private func extractAudioSourcesFromHTMLContent(_ content: String) -> [String] {
        return InlineResourceType.audio.extractSourcesFromHTMLContent(content)
    }

    private func extractFileSourcesFromHTMLContent(_ content: String) -> [String] {
        return InlineResourceType.file.extractSourcesFromHTMLContent(content)
    }
}
