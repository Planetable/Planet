import AppKit
import Foundation
import UniformTypeIdentifiers

struct DragPasteboardMediaFile {
    let url: URL
    let attachmentType: AttachmentType
    let isTemporary: Bool
    let pasteboardType: NSPasteboard.PasteboardType?

    init(
        url: URL,
        attachmentType: AttachmentType,
        isTemporary: Bool,
        pasteboardType: NSPasteboard.PasteboardType? = nil
    ) {
        self.url = url
        self.attachmentType = attachmentType
        self.isTemporary = isTemporary
        self.pasteboardType = pasteboardType
    }
}

enum DragPasteboardMedia {
    struct Flavor {
        let type: NSPasteboard.PasteboardType
        let fileExtension: String
        let attachmentType: AttachmentType
        let convertsImageDataToPNG: Bool

        init(
            type: NSPasteboard.PasteboardType,
            fileExtension: String,
            attachmentType: AttachmentType,
            convertsImageDataToPNG: Bool = false
        ) {
            self.type = type
            self.fileExtension = fileExtension
            self.attachmentType = attachmentType
            self.convertsImageDataToPNG = convertsImageDataToPNG
        }
    }

    static let imageFlavors: [Flavor] = [
        Flavor(type: NSPasteboard.PasteboardType(UTType.png.identifier), fileExtension: "png", attachmentType: .image),
        Flavor(type: NSPasteboard.PasteboardType(UTType.jpeg.identifier), fileExtension: "jpg", attachmentType: .image),
        Flavor(type: NSPasteboard.PasteboardType("CorePasteboardFlavorType 0x4A504547"), fileExtension: "jpg", attachmentType: .image),
        Flavor(type: NSPasteboard.PasteboardType(UTType.gif.identifier), fileExtension: "gif", attachmentType: .image),
        Flavor(type: NSPasteboard.PasteboardType(UTType.tiff.identifier), fileExtension: "tiff", attachmentType: .image),
        Flavor(type: .tiff, fileExtension: "tiff", attachmentType: .image),
        Flavor(type: NSPasteboard.PasteboardType("NeXT TIFF v4.0 pasteboard type"), fileExtension: "tiff", attachmentType: .image),
        Flavor(type: NSPasteboard.PasteboardType("public.heic"), fileExtension: "heic", attachmentType: .image),
        Flavor(type: NSPasteboard.PasteboardType("public.heif"), fileExtension: "heif", attachmentType: .image),
        Flavor(type: NSPasteboard.PasteboardType("public.webp"), fileExtension: "webp", attachmentType: .image),
        Flavor(
            type: NSPasteboard.PasteboardType(UTType.image.identifier),
            fileExtension: "png",
            attachmentType: .image,
            convertsImageDataToPNG: true
        )
    ]

    static let videoFlavors: [Flavor] = [
        Flavor(type: NSPasteboard.PasteboardType(UTType.mpeg4Movie.identifier), fileExtension: "mp4", attachmentType: .video),
        Flavor(type: NSPasteboard.PasteboardType(UTType.quickTimeMovie.identifier), fileExtension: "mov", attachmentType: .video),
        Flavor(type: NSPasteboard.PasteboardType(UTType.movie.identifier), fileExtension: "mov", attachmentType: .video)
    ]

    static let audioFlavors: [Flavor] = [
        Flavor(type: NSPasteboard.PasteboardType(UTType.mp3.identifier), fileExtension: "mp3", attachmentType: .audio),
        Flavor(type: NSPasteboard.PasteboardType(UTType.mpeg4Audio.identifier), fileExtension: "m4a", attachmentType: .audio),
        Flavor(type: NSPasteboard.PasteboardType(UTType.wav.identifier), fileExtension: "wav", attachmentType: .audio),
        Flavor(type: NSPasteboard.PasteboardType(UTType.audio.identifier), fileExtension: "m4a", attachmentType: .audio)
    ]

    static let documentFlavors: [Flavor] = [
        Flavor(type: NSPasteboard.PasteboardType(UTType.pdf.identifier), fileExtension: "pdf", attachmentType: .file)
    ]

    static func readablePasteboardTypes(
        allowing attachmentTypes: Set<AttachmentType>,
        includeFileURL: Bool = true
    ) -> [NSPasteboard.PasteboardType] {
        let dataTypes = readableDataPasteboardTypes(allowing: attachmentTypes)
        return includeFileURL ? [.fileURL] + dataTypes : dataTypes
    }

    static func readableDataPasteboardTypes(
        allowing attachmentTypes: Set<AttachmentType>
    ) -> [NSPasteboard.PasteboardType] {
        flavors(allowing: attachmentTypes).map(\.type)
    }

    static func containsSupportedMedia(
        in pasteboard: NSPasteboard,
        allowing attachmentTypes: Set<AttachmentType>,
        includeFileURLs: Bool = true
    ) -> Bool {
        if includeFileURLs,
           let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           fileURLs.contains(where: { supportedAttachmentType(for: $0, allowing: attachmentTypes) != nil }) {
            return true
        }

        let dataTypes = readableDataPasteboardTypes(allowing: attachmentTypes)
        if let items = pasteboard.pasteboardItems {
            if items.contains(where: { item in
                itemContainsReadableData(item, matching: dataTypes)
            }) {
                return true
            }
        }

        return pasteboard.availableType(from: dataTypes) != nil
    }

    static func supportedAttachmentType(
        for url: URL,
        allowing attachmentTypes: Set<AttachmentType>
    ) -> AttachmentType? {
        guard url.isFileURL else { return nil }
        if let fileType = UTType(filenameExtension: url.pathExtension.lowercased()) {
            if attachmentTypes.contains(.image), fileType.conforms(to: .image) {
                return .image
            }
            if attachmentTypes.contains(.video),
               fileType.conforms(to: .movie) || fileType.conforms(to: .video) {
                return .video
            }
            if attachmentTypes.contains(.audio), fileType.conforms(to: .audio) {
                return .audio
            }
            if attachmentTypes.contains(.file), fileType.conforms(to: .pdf) {
                return .file
            }
        }

        let attachmentType = AttachmentType.from(url)
        switch attachmentType {
        case .image, .video, .audio:
            return attachmentTypes.contains(attachmentType) ? attachmentType : nil
        case .file:
            return attachmentTypes.contains(.file) && url.pathExtension.lowercased() == "pdf" ? .file : nil
        }
    }

    static func importedFiles(
        from pasteboard: NSPasteboard,
        allowing attachmentTypes: Set<AttachmentType>,
        convertHEICFileURLsToJPEG: Bool = false
    ) throws -> [DragPasteboardMediaFile] {
        var files: [DragPasteboardMediaFile] = []
        var importedFileURLPaths: Set<String> = []
        var firstImportError: Error?

        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for fileURL in fileURLs {
                guard let attachmentType = supportedAttachmentType(for: fileURL, allowing: attachmentTypes) else {
                    continue
                }
                do {
                    files.append(
                        try makeTemporaryFile(
                            from: fileURL,
                            attachmentType: attachmentType,
                            convertHEICFileURLsToJPEG: convertHEICFileURLsToJPEG
                        )
                    )
                    importedFileURLPaths.insert(standardizedFilePath(for: fileURL))
                } catch {
                    firstImportError = firstImportError ?? error
                }
            }
        }

        if let items = pasteboard.pasteboardItems {
            for item in items {
                guard shouldImportRawData(
                    from: item,
                    allowing: attachmentTypes,
                    importedFileURLPaths: importedFileURLPaths
                ) else {
                    continue
                }
                do {
                    if let importedFile = try makeTemporaryFile(from: item, allowing: attachmentTypes) {
                        files.append(importedFile)
                    }
                } catch {
                    firstImportError = firstImportError ?? error
                }
            }
        }

        if files.isEmpty {
            do {
                if let importedFile = try makeTemporaryFile(from: pasteboard, allowing: attachmentTypes) {
                    files.append(importedFile)
                }
            } catch {
                firstImportError = firstImportError ?? error
            }
        }

        if files.isEmpty, let firstImportError {
            throw firstImportError
        }
        return files
    }

    static func firstImportedDataFile(
        from pasteboard: NSPasteboard,
        allowing attachmentTypes: Set<AttachmentType>,
        baseName: String
    ) throws -> DragPasteboardMediaFile? {
        var firstImportError: Error?
        do {
            if let importedFile = try makeTemporaryFile(from: pasteboard, allowing: attachmentTypes, baseName: baseName) {
                return importedFile
            }
        } catch {
            firstImportError = firstImportError ?? error
        }

        guard let items = pasteboard.pasteboardItems else {
            if let firstImportError {
                throw firstImportError
            }
            return nil
        }

        for item in items {
            do {
                if let importedFile = try makeTemporaryFile(from: item, allowing: attachmentTypes, baseName: baseName) {
                    return importedFile
                }
            } catch {
                firstImportError = firstImportError ?? error
            }
        }

        if let firstImportError {
            throw firstImportError
        }
        return nil
    }

    static func cleanupTemporaryFiles(_ files: [DragPasteboardMediaFile]) {
        for file in files where file.isTemporary {
            try? FileManager.default.removeItem(at: file.url)
        }
    }

    static func uniqueTemporaryFileURL(baseName: String, fileExtension: String) -> URL {
        let resolvedBaseName = baseName.sanitized().trim().isEmpty ? UUID().uuidString : baseName.sanitized().trim()
        let initialURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(resolvedBaseName)
            .appendingPathExtension(fileExtension)
        if !FileManager.default.fileExists(atPath: initialURL.path) {
            return initialURL
        }
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("\(resolvedBaseName)-\(UUID().uuidString)")
            .appendingPathExtension(fileExtension)
    }

    private static func flavors(allowing attachmentTypes: Set<AttachmentType>) -> [Flavor] {
        var result: [Flavor] = []
        if attachmentTypes.contains(.image) {
            result += imageFlavors
        }
        if attachmentTypes.contains(.video) {
            result += videoFlavors
        }
        if attachmentTypes.contains(.audio) {
            result += audioFlavors
        }
        if attachmentTypes.contains(.file) {
            result += documentFlavors
        }
        return result
    }

    private static func itemContainsReadableData(
        _ item: NSPasteboardItem,
        matching dataTypes: [NSPasteboard.PasteboardType]
    ) -> Bool {
        item.types.contains { dataTypes.contains($0) }
    }

    private static func shouldImportRawData(
        from item: NSPasteboardItem,
        allowing attachmentTypes: Set<AttachmentType>,
        importedFileURLPaths: Set<String>
    ) -> Bool {
        guard itemContainsReadableData(item, matching: readableDataPasteboardTypes(allowing: attachmentTypes)) else {
            return false
        }
        guard item.types.contains(.fileURL),
              let fileURL = fileURL(from: item) else {
            return true
        }
        return !importedFileURLPaths.contains(standardizedFilePath(for: fileURL))
    }

    private static func fileURL(from item: NSPasteboardItem) -> URL? {
        if let fileURL = urlFromFileURLString(item.string(forType: .fileURL)) {
            return fileURL
        }

        if let fileURLString = item.propertyList(forType: .fileURL) as? String,
           let fileURL = urlFromFileURLString(fileURLString) {
            return fileURL
        }

        if let data = item.data(forType: .fileURL),
           let fileURL = URL(dataRepresentation: data, relativeTo: nil),
           fileURL.isFileURL {
            return fileURL.standardizedFileURL
        }

        return nil
    }

    private static func urlFromFileURLString(_ string: String?) -> URL? {
        guard let string, !string.isEmpty else {
            return nil
        }
        if let url = URL(string: string), url.isFileURL {
            return url.standardizedFileURL
        }
        return URL(fileURLWithPath: string).standardizedFileURL
    }

    private static func standardizedFilePath(for url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    private static func makeTemporaryFile(
        from pasteboard: NSPasteboard,
        allowing attachmentTypes: Set<AttachmentType>,
        baseName: String = UUID().uuidString
    ) throws -> DragPasteboardMediaFile? {
        var firstImportError: Error?
        for flavor in flavors(allowing: attachmentTypes) {
            if let data = pasteboard.data(forType: flavor.type) {
                do {
                    return try makeTemporaryFile(from: data, flavor: flavor, baseName: baseName)
                } catch {
                    firstImportError = firstImportError ?? error
                }
            }
        }
        if let firstImportError {
            throw firstImportError
        }
        return nil
    }

    private static func makeTemporaryFile(
        from pasteboardItem: NSPasteboardItem,
        allowing attachmentTypes: Set<AttachmentType>,
        baseName: String = UUID().uuidString
    ) throws -> DragPasteboardMediaFile? {
        var firstImportError: Error?
        for flavor in flavors(allowing: attachmentTypes) {
            if let data = pasteboardItem.data(forType: flavor.type) {
                do {
                    return try makeTemporaryFile(from: data, flavor: flavor, baseName: baseName)
                } catch {
                    firstImportError = firstImportError ?? error
                }
            }
        }
        if let firstImportError {
            throw firstImportError
        }
        return nil
    }

    private static func makeTemporaryFile(
        from sourceURL: URL,
        attachmentType: AttachmentType,
        convertHEICFileURLsToJPEG: Bool
    ) throws -> DragPasteboardMediaFile {
        if convertHEICFileURLsToJPEG,
           attachmentType == .image,
           let convertedImage = try makeTemporaryJPEGImageFileIfNeeded(from: sourceURL) {
            return convertedImage
        }

        let typeIdentifier = try? sourceURL.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier
        let fileExtension = resolvedFileExtension(
            preferred: sourceURL.pathExtension,
            typeIdentifier: typeIdentifier,
            attachmentType: attachmentType
        )
        let temporaryURL = uniqueTemporaryFileURL(baseName: UUID().uuidString, fileExtension: fileExtension)
        let accessedSecurityScope = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessedSecurityScope {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }
        try FileManager.default.copyItem(at: sourceURL, to: temporaryURL)
        return DragPasteboardMediaFile(
            url: temporaryURL,
            attachmentType: attachmentType,
            isTemporary: true,
            pasteboardType: .fileURL
        )
    }

    private static func makeTemporaryFile(
        from data: Data,
        flavor: Flavor,
        baseName: String
    ) throws -> DragPasteboardMediaFile {
        if flavor.convertsImageDataToPNG {
            guard let image = NSImage(data: data), let pngData = image.PNGData else {
                throw CocoaError(.fileReadCorruptFile)
            }
            return try makeTemporaryFile(from: pngData, flavor: flavor, baseName: baseName, fileExtension: "png")
        }
        return try makeTemporaryFile(from: data, flavor: flavor, baseName: baseName, fileExtension: flavor.fileExtension)
    }

    private static func makeTemporaryFile(
        from data: Data,
        flavor: Flavor,
        baseName: String,
        fileExtension: String
    ) throws -> DragPasteboardMediaFile {
        let temporaryURL = uniqueTemporaryFileURL(baseName: baseName, fileExtension: fileExtension)
        try data.write(to: temporaryURL, options: .atomic)
        return DragPasteboardMediaFile(
            url: temporaryURL,
            attachmentType: flavor.attachmentType,
            isTemporary: true,
            pasteboardType: flavor.type
        )
    }

    private static func makeTemporaryJPEGImageFileIfNeeded(
        from sourceURL: URL
    ) throws -> DragPasteboardMediaFile? {
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

        let temporaryURL = uniqueTemporaryFileURL(baseName: UUID().uuidString, fileExtension: "jpg")
        try jpegData.write(to: temporaryURL, options: .atomic)
        return DragPasteboardMediaFile(
            url: temporaryURL,
            attachmentType: .image,
            isTemporary: true,
            pasteboardType: .fileURL
        )
    }

    private static func resolvedFileExtension(
        preferred: String,
        typeIdentifier: String?,
        attachmentType: AttachmentType
    ) -> String {
        if !preferred.isEmpty {
            return preferred.lowercased()
        }
        if let typeIdentifier,
           let matchedFlavor = flavors(allowing: [attachmentType])
            .first(where: { $0.type.rawValue == typeIdentifier }) {
            return matchedFlavor.fileExtension
        }
        switch attachmentType {
        case .video:
            return "mov"
        case .audio:
            return "m4a"
        case .file:
            return "pdf"
        default:
            return "png"
        }
    }
}
