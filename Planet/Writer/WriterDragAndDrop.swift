import Foundation
import SwiftUI
import UniformTypeIdentifiers


class WriterDragAndDrop: ObservableObject, DropDelegate {
    private struct ImportedTextDocument {
        let title: String?
        let content: String
    }

    private enum TextImportChoice {
        case append
        case overwrite
        case cancel
    }

    @ObservedObject var draft: DraftModel

    init(draft: DraftModel) {
        self.draft = draft
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .copy)
    }

    func validateDrop(info: DropInfo) -> Bool {
        guard let _ = info.itemProviders(for: [.fileURL]).first else { return false }
        return true
    }

    func performDrop(info: DropInfo) -> Bool {
        let providers = info.itemProviders(for: [.fileURL])
        Task(priority: .userInitiated) {
            var urls: [URL] = []
            for provider in providers {
                if let item = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier),
                   let data = item as? Data,
                   let path = URL(dataRepresentation: data, relativeTo: nil) {
                    urls.append(path)
                }
            }
            await Self.handleDroppedFiles(urls, for: draft, insertAttachmentMarkdown: false)
        }
        return true
    }

    @MainActor
    static func handleDroppedFiles(
        _ fileURLs: [URL],
        for draft: DraftModel,
        insertAttachmentMarkdown: Bool
    ) async {
        let urls = deduplicatedFileURLs(fileURLs)
        guard !urls.isEmpty else { return }

        let textDocumentURLs = urls.filter { isImportableTextFile($0) }
        if textDocumentURLs.count > 1 {
            presentAlert(
                title: "Failed to Import Text",
                message: "Drop a single Markdown or text file at a time."
            )
            return
        }

        do {
            try withSecurityScopedAccess(to: urls) {
                if let textDocumentURL = textDocumentURLs.first {
                    let document = try loadTextDocument(from: textDocumentURL)
                    switch resolveTextImportChoice(for: draft) {
                    case .append:
                        appendTextDocument(document, to: draft)
                    case .overwrite:
                        overwriteDraft(draft, with: document)
                    case .cancel:
                        return
                    }
                }

                let attachmentURLs = urls.filter { !textDocumentURLs.contains($0) }
                let shouldInsertAttachmentMarkdown = insertAttachmentMarkdown && textDocumentURLs.isEmpty
                try attachFiles(
                    attachmentURLs,
                    to: draft,
                    insertMarkdownIntoContent: shouldInsertAttachmentMarkdown
                )
                try draft.save()
                try draft.renderPreview()
            }
        } catch {
            presentAlert(title: "Failed to Import Text", message: error.localizedDescription)
        }
    }

    private static func deduplicatedFileURLs(_ urls: [URL]) -> [URL] {
        var deduplicated: [URL] = []
        var seenPaths = Set<String>()
        for url in urls {
            let path = url.standardizedFileURL.path
            if seenPaths.insert(path).inserted {
                deduplicated.append(url)
            }
        }
        return deduplicated
    }

    private static func isImportableTextFile(_ url: URL) -> Bool {
        ["md", "markdown", "txt"].contains(url.pathExtension.lowercased())
    }

    private static func withSecurityScopedAccess<T>(to urls: [URL], _ body: () throws -> T) throws -> T {
        let scopedURLs = urls.filter { $0.startAccessingSecurityScopedResource() }
        defer {
            scopedURLs.forEach { $0.stopAccessingSecurityScopedResource() }
        }
        return try body()
    }

    private static func loadTextDocument(from url: URL) throws -> ImportedTextDocument {
        var usedEncoding = String.Encoding.utf8.rawValue
        let content = try NSString(contentsOf: url, usedEncoding: &usedEncoding) as String
        if let extracted = extractLeadingMarkdownH1(from: content) {
            return ImportedTextDocument(title: extracted.title, content: extracted.content)
        }
        return ImportedTextDocument(title: nil, content: content)
    }

    private static func extractLeadingMarkdownH1(from content: String) -> (title: String, content: String)? {
        let normalizedContent = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        var lines = normalizedContent.components(separatedBy: "\n")

        guard let headingIndex = lines.firstIndex(where: {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) else {
            return nil
        }

        let line = lines[headingIndex].trimmingCharacters(in: .whitespaces)
        guard line.hasPrefix("#"), !line.hasPrefix("##") else {
            return nil
        }

        let remainder = line.dropFirst()
        guard let first = remainder.first, first == " " || first == "\t" else {
            return nil
        }

        var title = String(remainder).trimmingCharacters(in: .whitespacesAndNewlines)
        title = title.replacingOccurrences(of: #"\s#+\s*$"#, with: "", options: .regularExpression)
        title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            return nil
        }

        lines.remove(at: headingIndex)
        if headingIndex < lines.count,
            lines[headingIndex].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            lines.remove(at: headingIndex)
        }

        return (title: title, content: lines.joined(separator: "\n"))
    }

    private static func resolveTextImportChoice(for draft: DraftModel) -> TextImportChoice {
        let hasExistingTitle = !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasExistingContent = !draft.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard hasExistingTitle || hasExistingContent else {
            return .overwrite
        }

        let alert = NSAlert()
        alert.messageText = "Import Text into Writer?"
        alert.informativeText = "This Writer already has a title or content."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Append")
        alert.addButton(withTitle: "Overwrite")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return .append
        case .alertSecondButtonReturn:
            return .overwrite
        default:
            return .cancel
        }
    }

    private static func appendTextDocument(_ document: ImportedTextDocument, to draft: DraftModel) {
        if draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let title = document.title
        {
            draft.title = title
        }

        let importedContent = document.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !importedContent.isEmpty else { return }

        let existingContent = draft.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if existingContent.isEmpty {
            draft.content = document.content
        } else {
            draft.content += "\n\n" + document.content
        }
    }

    private static func overwriteDraft(_ draft: DraftModel, with document: ImportedTextDocument) {
        draft.title = document.title ?? ""
        draft.content = document.content
    }

    private static func attachFiles(
        _ urls: [URL],
        to draft: DraftModel,
        insertMarkdownIntoContent: Bool
    ) throws {
        for url in urls {
            let attachment = try draft.addAttachment(path: url, type: AttachmentType.from(url))
            if insertMarkdownIntoContent, let markdown = attachment.markdown {
                NotificationCenter.default.post(
                    name: .writerNotification(.insertText, for: attachment.draft),
                    object: markdown
                )
            }
        }
    }

    private static func presentAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
