//
//  QuickPostViewModel.swift
//  Planet
//
//  Created by Xin Liu on 7/30/24.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

private typealias QuickPostImportedMediaFile = DragPasteboardMediaFile

class QuickPostViewModel: ObservableObject {
    static let shared = QuickPostViewModel()

    private static let supportedAttachmentTypes: Set<AttachmentType> = [.image, .video, .audio]
    static let supportedMediaPasteboardTypes = DragPasteboardMedia.readablePasteboardTypes(
        allowing: supportedAttachmentTypes
    )

    @Published var allowedContentTypes: [UTType] = []
    @Published var allowMultipleSelection = false

    @Published var content: String = ""
    @Published var textContentHeight: CGFloat = 0
    @Published var showDiscardAlert: Bool = false

    var hasContent: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !fileURLs.isEmpty
    }

    @Published var heroImage: String? = nil
    @Published var fileURLs: [URL] = []

    @Published var audioURL: URL? = nil
    @Published var videoURL: URL? = nil
    private var temporaryFileURLs: Set<URL> = []

    @MainActor
    func prepareFiles(_ files: [URL]) throws {
        var importedFiles: [QuickPostImportedMediaFile] = []
        do {
            for file in files {
                guard let attachmentType = supportedAttachmentType(for: file) else {
                    continue
                }
                importedFiles.append(
                    try importedMediaFile(fromSelectedFile: file, attachmentType: attachmentType)
                )
            }
            try importMediaFiles(importedFiles)
        } catch {
            cleanupImportedFiles(importedFiles)
            throw error
        }
    }

    @MainActor
    func addFilesFromOpenPanel(_ files: [URL], type: AttachmentType) throws {
        var importedFiles: [QuickPostImportedMediaFile] = []
        do {
            for file in files {
                importedFiles.append(try importedMediaFile(fromSelectedFile: file, attachmentType: type))
            }
            try importMediaFiles(importedFiles)
        } catch {
            cleanupImportedFiles(importedFiles)
            throw error
        }
    }

    @MainActor
    @discardableResult
    func processMediaPasteIfAvailable() -> Bool {
        let pasteboard = NSPasteboard.general
        return processMediaIfAvailable(from: pasteboard, action: "paste")
    }

    func canImportMedia(from pasteboard: NSPasteboard) -> Bool {
        DragPasteboardMedia.containsSupportedMedia(
            in: pasteboard,
            allowing: Self.supportedAttachmentTypes
        )
    }

    @MainActor
    @discardableResult
    func processMediaDropIfAvailable(from pasteboard: NSPasteboard) -> Bool {
        processMediaIfAvailable(from: pasteboard, action: "drop")
    }

    @MainActor
    @discardableResult
    private func processMediaIfAvailable(from pasteboard: NSPasteboard, action: String) -> Bool {
        log(
            "QuickPost media \(action) started types=\(pasteboard.types?.map(\.rawValue).sorted().joined(separator: ",") ?? "nil")"
        )
        guard canImportMedia(from: pasteboard) else {
            log("QuickPost media \(action) skipped: no supported media")
            return false
        }
        do {
            let pastedFiles = try DragPasteboardMedia.importedFiles(
                from: pasteboard,
                allowing: Self.supportedAttachmentTypes,
                convertHEICFileURLsToJPEG: true
            )
            guard !pastedFiles.isEmpty else {
                log("QuickPost media \(action) found no importable files after media scan", level: .warning)
                return action == "drop"
            }
            try importMediaFiles(pastedFiles)
            log("QuickPost media \(action) imported files=\(pastedFiles.map { $0.url.lastPathComponent }.joined(separator: ","))")
        } catch {
            log("QuickPost media \(action) failed error=\(error.localizedDescription)", level: .error)
        }
        return true
    }

    func processPasteItems(_ providers: [NSItemProvider]) {
        guard !providers.isEmpty else { return }
        Task { @MainActor in
            _ = self.processMediaPasteIfAvailable()
        }
    }

    @MainActor
    func removeFile(_ url: URL) {
        fileURLs.removeAll { $0 == url }
        if audioURL == url {
            audioURL = nil
        }
        if videoURL == url {
            videoURL = nil
        }
        content = content.replacingOccurrences(of: url.htmlCode, with: "")
        cleanupTemporaryFileIfNeeded(url)
    }

    @MainActor
    func cleanup() {
        for url in temporaryFileURLs {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryFileURLs.removeAll()
        content = ""
        textContentHeight = 0
        heroImage = nil
        fileURLs = []
        audioURL = nil
        videoURL = nil
    }

    @MainActor
    private func importMediaFiles(_ importedFiles: [QuickPostImportedMediaFile]) throws {
        let newVideos = importedFiles.filter { $0.attachmentType == .video }
        if newVideos.count > 1 {
            cleanupImportedFiles(importedFiles)
            presentPasteAlert(
                title: "Failed to Paste Video",
                message: "Quick Post only supports one video attachment. Paste a single video at a time."
            )
            return
        }

        let newAudios = importedFiles.filter { $0.attachmentType == .audio }
        if newAudios.count > 1 {
            cleanupImportedFiles(importedFiles)
            presentPasteAlert(
                title: "Failed to Paste Audio",
                message: "Quick Post only supports one audio attachment. Paste a single audio file at a time."
            )
            return
        }

        if newVideos.first != nil, let existingVideoURL = videoURL {
            removeFile(existingVideoURL)
        }
        if newAudios.first != nil, let existingAudioURL = audioURL {
            removeFile(existingAudioURL)
        }

        for importedFile in importedFiles {
            if importedFile.isTemporary {
                temporaryFileURLs.insert(importedFile.url)
            }
            fileURLs.removeAll { $0 == importedFile.url }
            fileURLs.append(importedFile.url)
            switch importedFile.attachmentType {
            case .audio:
                audioURL = importedFile.url
            case .video:
                videoURL = importedFile.url
            default:
                break
            }
        }
    }

    private func supportedAttachmentType(for url: URL) -> AttachmentType? {
        DragPasteboardMedia.supportedAttachmentType(
            for: url,
            allowing: Self.supportedAttachmentTypes
        )
    }

    private func importedMediaFile(
        fromSelectedFile sourceURL: URL,
        attachmentType: AttachmentType
    ) throws -> QuickPostImportedMediaFile {
        if attachmentType == .image,
           let convertedImage = try makeTemporaryJPEGImageFileIfNeeded(from: sourceURL) {
            return convertedImage
        }
        return QuickPostImportedMediaFile(
            url: sourceURL,
            attachmentType: attachmentType,
            isTemporary: false
        )
    }

    private func makeTemporaryJPEGImageFileIfNeeded(from sourceURL: URL) throws -> QuickPostImportedMediaFile? {
        let fileExtension = sourceURL.pathExtension.lowercased()
        guard ["heic", "heif"].contains(fileExtension) else {
            return nil
        }

        let accessedSecurityScope = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessedSecurityScope {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        guard let imageData = try? Data(contentsOf: sourceURL),
              let image = NSImage(data: imageData),
              let jpegData = image.JPEGData else {
            return nil
        }

        let temporaryURL = DragPasteboardMedia.uniqueTemporaryFileURL(
            baseName: UUID().uuidString,
            fileExtension: "jpg"
        )
        try jpegData.write(to: temporaryURL, options: .atomic)
        return QuickPostImportedMediaFile(
            url: temporaryURL,
            attachmentType: .image,
            isTemporary: true
        )
    }

    private func cleanupImportedFiles(_ importedFiles: [QuickPostImportedMediaFile]) {
        for importedFile in importedFiles where importedFile.isTemporary {
            try? FileManager.default.removeItem(at: importedFile.url)
        }
    }

    private func cleanupTemporaryFileIfNeeded(_ url: URL) {
        guard temporaryFileURLs.contains(url) else { return }
        try? FileManager.default.removeItem(at: url)
        temporaryFileURLs.remove(url)
    }

    private func presentPasteAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n("OK"))
        alert.runModal()
    }

    private func log(_ message: String, level: PlanetLogger.Level = .info) {
        PlanetLogger.log("DragDrop: \(message)", level: level)
    }
}
