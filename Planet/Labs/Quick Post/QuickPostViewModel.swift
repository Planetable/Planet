//
//  QuickPostViewModel.swift
//  Planet
//
//  Created by Xin Liu on 7/30/24.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

private struct QuickPostImportedMediaFile {
    let url: URL
    let attachmentType: AttachmentType
    let isTemporary: Bool
}

class QuickPostViewModel: ObservableObject {
    static let shared = QuickPostViewModel()

    private static let supportedImagePasteboardTypes: [(type: NSPasteboard.PasteboardType, fileExtension: String)] = [
        (NSPasteboard.PasteboardType(UTType.png.identifier), "png"),
        (NSPasteboard.PasteboardType(UTType.jpeg.identifier), "jpg"),
        (NSPasteboard.PasteboardType(UTType.gif.identifier), "gif"),
        (NSPasteboard.PasteboardType(UTType.tiff.identifier), "tiff"),
        (NSPasteboard.PasteboardType("public.heic"), "heic"),
        (NSPasteboard.PasteboardType("public.heif"), "heif"),
        (NSPasteboard.PasteboardType("public.webp"), "webp")
    ]
    private static let supportedVideoPasteboardTypes: [(type: NSPasteboard.PasteboardType, fileExtension: String)] = [
        (NSPasteboard.PasteboardType(UTType.mpeg4Movie.identifier), "mp4"),
        (NSPasteboard.PasteboardType(UTType.quickTimeMovie.identifier), "mov"),
        (NSPasteboard.PasteboardType(UTType.movie.identifier), "mov")
    ]
    private static let supportedAudioPasteboardTypes: [(type: NSPasteboard.PasteboardType, fileExtension: String)] = [
        (NSPasteboard.PasteboardType(UTType.mp3.identifier), "mp3"),
        (NSPasteboard.PasteboardType(UTType.mpeg4Audio.identifier), "m4a"),
        (NSPasteboard.PasteboardType(UTType.wav.identifier), "wav"),
        (NSPasteboard.PasteboardType(UTType.audio.identifier), "m4a")
    ]
    static let supportedPasteContentTypes: [UTType] = [
        .fileURL,
        .image,
        .movie,
        .audio,
        .mpeg4Movie,
        .quickTimeMovie,
        .mp3,
        .mpeg4Audio,
        .wav
    ]

    @Published var allowedContentTypes: [UTType] = []
    @Published var allowMultipleSelection = false

    @Published var content: String = ""

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
        guard pasteboardContainsSupportedMedia(pasteboard) else {
            return false
        }
        do {
            let pastedFiles = try pastedMediaFiles(from: pasteboard)
            guard !pastedFiles.isEmpty else { return false }
            try importMediaFiles(pastedFiles)
            debugPrint("Pasted files: \(fileURLs)")
        } catch {
            debugPrint("failed to process pasted media in Quick Post: \(error)")
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
        guard url.isFileURL else { return nil }
        if let fileType = UTType(filenameExtension: url.pathExtension.lowercased()) {
            if fileType.conforms(to: .image) {
                return .image
            }
            if fileType.conforms(to: .movie) || fileType.conforms(to: .video) {
                return .video
            }
            if fileType.conforms(to: .audio) {
                return .audio
            }
        }
        let attachmentType = AttachmentType.from(url)
        switch attachmentType {
        case .image, .video, .audio:
            return attachmentType
        default:
            return nil
        }
    }

    private func pastedMediaFiles(from pasteboard: NSPasteboard) throws -> [QuickPostImportedMediaFile] {
        var files: [QuickPostImportedMediaFile] = []
        do {
            if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
                for fileURL in fileURLs {
                    guard let attachmentType = supportedAttachmentType(for: fileURL) else {
                        continue
                    }
                    files.append(try importedMediaFile(fromPastedFile: fileURL, attachmentType: attachmentType))
                }
            }

            if let items = pasteboard.pasteboardItems {
                for item in items where !item.types.contains(.fileURL) {
                    if let pastedFile = try importedMediaFile(from: item) {
                        files.append(pastedFile)
                    }
                }
            } else if files.isEmpty, let pastedFile = try importedMediaFile(from: pasteboard) {
                files.append(pastedFile)
            }
        } catch {
            cleanupImportedFiles(files)
            throw error
        }

        return files
    }

    private func pasteboardContainsSupportedMedia(_ pasteboard: NSPasteboard) -> Bool {
        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           fileURLs.contains(where: { supportedAttachmentType(for: $0) != nil }) {
            return true
        }

        let supportedTypes =
            Self.supportedImagePasteboardTypes.map(\.type)
            + [NSPasteboard.PasteboardType(UTType.image.identifier)]
            + Self.supportedVideoPasteboardTypes.map(\.type)
            + Self.supportedAudioPasteboardTypes.map(\.type)

        if let items = pasteboard.pasteboardItems {
            return items.contains { item in
                item.types.contains { supportedTypes.contains($0) }
            }
        }

        return pasteboard.availableType(from: supportedTypes) != nil
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

    private func importedMediaFile(
        fromPastedFile sourceURL: URL,
        attachmentType: AttachmentType
    ) throws -> QuickPostImportedMediaFile {
        if attachmentType == .image,
           let convertedImage = try makeTemporaryJPEGImageFileIfNeeded(from: sourceURL) {
            return convertedImage
        }

        let typeIdentifier = try? sourceURL.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier
        let fileExtension = resolvedFileExtension(
            preferred: sourceURL.pathExtension,
            typeIdentifier: typeIdentifier,
            attachmentType: attachmentType
        )
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)

        let accessedSecurityScope = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessedSecurityScope {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        try FileManager.default.copyItem(at: sourceURL, to: temporaryURL)
        return QuickPostImportedMediaFile(
            url: temporaryURL,
            attachmentType: attachmentType,
            isTemporary: true
        )
    }

    private func importedMediaFile(from pasteboard: NSPasteboard) throws -> QuickPostImportedMediaFile? {
        for supportedType in Self.supportedImagePasteboardTypes {
            if let data = pasteboard.data(forType: supportedType.type) {
                return try makeTemporaryImportedMediaFile(
                    from: data,
                    attachmentType: .image,
                    fileExtension: supportedType.fileExtension
                )
            }
        }
        if let data = pasteboard.data(forType: NSPasteboard.PasteboardType(UTType.image.identifier)) {
            return try makeTemporaryPNGImageFile(from: data)
        }
        for supportedType in Self.supportedVideoPasteboardTypes {
            if let data = pasteboard.data(forType: supportedType.type) {
                return try makeTemporaryImportedMediaFile(
                    from: data,
                    attachmentType: .video,
                    fileExtension: supportedType.fileExtension
                )
            }
        }
        for supportedType in Self.supportedAudioPasteboardTypes {
            if let data = pasteboard.data(forType: supportedType.type) {
                return try makeTemporaryImportedMediaFile(
                    from: data,
                    attachmentType: .audio,
                    fileExtension: supportedType.fileExtension
                )
            }
        }
        return nil
    }

    private func importedMediaFile(from pasteboardItem: NSPasteboardItem) throws -> QuickPostImportedMediaFile? {
        for supportedType in Self.supportedImagePasteboardTypes {
            if let data = pasteboardItem.data(forType: supportedType.type) {
                return try makeTemporaryImportedMediaFile(
                    from: data,
                    attachmentType: .image,
                    fileExtension: supportedType.fileExtension
                )
            }
        }
        if let data = pasteboardItem.data(forType: NSPasteboard.PasteboardType(UTType.image.identifier)) {
            return try makeTemporaryPNGImageFile(from: data)
        }
        for supportedType in Self.supportedVideoPasteboardTypes {
            if let data = pasteboardItem.data(forType: supportedType.type) {
                return try makeTemporaryImportedMediaFile(
                    from: data,
                    attachmentType: .video,
                    fileExtension: supportedType.fileExtension
                )
            }
        }
        for supportedType in Self.supportedAudioPasteboardTypes {
            if let data = pasteboardItem.data(forType: supportedType.type) {
                return try makeTemporaryImportedMediaFile(
                    from: data,
                    attachmentType: .audio,
                    fileExtension: supportedType.fileExtension
                )
            }
        }
        return nil
    }

    private func makeTemporaryImportedMediaFile(
        from data: Data,
        attachmentType: AttachmentType,
        fileExtension: String
    ) throws -> QuickPostImportedMediaFile {
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)
        try data.write(to: temporaryURL, options: .atomic)
        return QuickPostImportedMediaFile(
            url: temporaryURL,
            attachmentType: attachmentType,
            isTemporary: true
        )
    }

    private func makeTemporaryPNGImageFile(from data: Data) throws -> QuickPostImportedMediaFile? {
        guard let image = NSImage(data: data), let pngData = image.PNGData else {
            return nil
        }
        return try makeTemporaryImportedMediaFile(
            from: pngData,
            attachmentType: .image,
            fileExtension: "png"
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

        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        try jpegData.write(to: temporaryURL, options: .atomic)
        return QuickPostImportedMediaFile(
            url: temporaryURL,
            attachmentType: .image,
            isTemporary: true
        )
    }

    private func resolvedFileExtension(
        preferred: String,
        typeIdentifier: String?,
        attachmentType: AttachmentType
    ) -> String {
        if !preferred.isEmpty {
            return preferred.lowercased()
        }
        if let typeIdentifier,
           let matchedType = supportedPasteboardTypes(for: attachmentType)
            .first(where: { $0.type.rawValue == typeIdentifier }) {
            return matchedType.fileExtension
        }
        switch attachmentType {
        case .video:
            return "mov"
        case .audio:
            return "m4a"
        default:
            return "png"
        }
    }

    private func supportedPasteboardTypes(
        for attachmentType: AttachmentType
    ) -> [(type: NSPasteboard.PasteboardType, fileExtension: String)] {
        switch attachmentType {
        case .image:
            return Self.supportedImagePasteboardTypes
        case .video:
            return Self.supportedVideoPasteboardTypes
        case .audio:
            return Self.supportedAudioPasteboardTypes
        default:
            return []
        }
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
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
