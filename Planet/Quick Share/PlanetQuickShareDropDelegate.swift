//
//  PlanetQuickShareDropDelegate.swift
//  Planet
//

import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers


class PlanetQuickShareDropDelegate: DropDelegate {
    private final class ActiveFilePromise: @unchecked Sendable {
        let id = UUID()
        let receiver: NSFilePromiseReceiver
        let destinationDirectory: URL
        let queue: OperationQueue

        init(receiver: NSFilePromiseReceiver, destinationDirectory: URL) {
            self.receiver = receiver
            self.destinationDirectory = destinationDirectory
            self.queue = OperationQueue()
            self.queue.name = "xyz.planetable.Planet.drag-drop.file-promise.\(id.uuidString)"
            self.queue.qualityOfService = .userInitiated
        }
    }

    private static let activePromiseLock = NSLock()
    private static var activePromises: [UUID: ActiveFilePromise] = [:]

    static let supportedContentTypes: [UTType] = {
        let filePromiseTypes = NSFilePromiseReceiver.readableDraggedTypes.map {
            UTType($0) ?? UTType(importedAs: $0)
        }
        return filePromiseTypes + [.fileURL, .image, .movie, .pdf, .mp3]
    }()

    init() {}

    static func processDropInfo(_ info: DropInfo) async -> [URL] {
        log(
            "processDropInfo started providers=\(info.itemProviders(for: supportedContentTypes).count) location=\(describeLocation(info.location))"
        )

        var urls: [URL] = []
        if #available(macOS 13.0, *) {
            for provider in info.itemProviders(for: [.image, .movie, .pdf, .mp3]) {
                log("provider types=\(provider.registeredTypeIdentifiers.sorted().joined(separator: ","))")
                if let url = try? await provider.loadItem(forTypeIdentifier: UTType.image.identifier) as? URL {
                    urls.append(url)
                    log("Drop file (image) accepted: \(quote(url.path))")
                }
                if let url = try? await provider.loadItem(forTypeIdentifier: UTType.pdf.identifier) as? URL {
                    urls.append(url)
                    log("Drop file (pdf) accepted: \(quote(url.path))")
                }
                if let url = try? await provider.loadItem(forTypeIdentifier: UTType.movie.identifier) as? URL {
                    urls.append(url)
                    log("Drop file (video) accepted: \(quote(url.path))")
                }
                if let url = try? await provider.loadItem(forTypeIdentifier: UTType.mp3.identifier) as? URL {
                    urls.append(url)
                    log("Drop file (mp3 audio) accepted: \(quote(url.path))")
                }
            }
        } else {
            let supportedExtensions = ["png", "heic", "jpeg", "gif", "tiff", "jpg", "webp"]
            for provider in info.itemProviders(for: [.fileURL]) {
                if let item = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier),
                   let data = item as? Data,
                   let path = URL(dataRepresentation: data, relativeTo: nil),
                   supportedExtensions.contains(path.pathExtension) {
                    urls.append(path)
                }
            }
        }
        log("processDropInfo finished urls=\(urls.count)")
        return urls
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .copy)
    }

    func validateDrop(info: DropInfo) -> Bool {
        let providerCount = info.itemProviders(for: Self.supportedContentTypes).count
        let hasDirectImage = Self.dragPasteboardHasDirectImage()
        let hasPromise = Self.dragPasteboardHasFilePromise()
        let isValid = providerCount > 0 || hasDirectImage || hasPromise
        Self.log(
            "validateDrop valid=\(isValid) providers=\(providerCount) hasDirectImage=\(hasDirectImage) hasPromise=\(hasPromise) location=\(Self.describeLocation(info.location))"
        )
        return isValid
    }

    func performDrop(info: DropInfo) -> Bool {
        if let imageURL = Self.imageFileFromDragPasteboard() {
            Self.log("performDrop received directPasteboardImage")
            Task { @MainActor in
                do {
                    try PlanetQuickShareViewModel.shared.prepareFiles([imageURL])
                } catch {
                    Self.log("performDrop failed to prepare directPasteboardImage error=\(error.localizedDescription)", level: .error)
                    let alert = NSAlert()
                    alert.messageText = L10n("Failed to Add Attachments")
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: L10n("OK"))
                    alert.runModal()
                }
            }
            return true
        }

        if Self.receivePromisedFileFromDragPasteboard({ fileURL in
            Task { @MainActor in
                guard let fileURL else {
                    Self.log("performDrop promisedFile produced no URL", level: .warning)
                    return
                }
                do {
                    try PlanetQuickShareViewModel.shared.prepareFiles([fileURL])
                } catch {
                    Self.log("performDrop failed to prepare promisedFile error=\(error.localizedDescription)", level: .error)
                    let alert = NSAlert()
                    alert.messageText = L10n("Failed to Add Attachments")
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: L10n("OK"))
                    alert.runModal()
                }
            }
        }) {
            return true
        }

        Task { @MainActor in
            let urls: [URL] = await Self.processDropInfo(info)
            if urls.count > 0 {
                do {
                    try PlanetQuickShareViewModel.shared.prepareFiles(urls)
                } catch {
                    let alert = NSAlert()
                    alert.messageText = L10n("Failed to Add Attachments")
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: L10n("OK"))
                    alert.runModal()
                }
            }
        }
        return true
    }

    static func dragPasteboardHasDirectImage() -> Bool {
        let pasteboard = NSPasteboard(name: .drag)
        return DragPasteboardMedia.containsSupportedMedia(
            in: pasteboard,
            allowing: [.image],
            includeFileURLs: false
        )
    }

    static func dragPasteboardHasFilePromise() -> Bool {
        let pasteboard = NSPasteboard(name: .drag)
        return pasteboard.canReadObject(forClasses: [NSFilePromiseReceiver.self], options: nil)
    }

    static func imageFileFromDragPasteboard() -> URL? {
        let pasteboard = NSPasteboard(name: .drag)
        log("dragPasteboard direct image scan types=\(pasteboard.types?.map(\.rawValue).sorted().joined(separator: ",") ?? "nil")")
        do {
            guard let imageFile = try DragPasteboardMedia.firstImportedDataFile(
                from: pasteboard,
                allowing: [.image],
                baseName: "Dropped Image"
            ) else {
                log("dragPasteboard direct image missing")
                return nil
            }
            log(
                "dragPasteboard direct image accepted type=\(quote(imageFile.pasteboardType?.rawValue ?? "unknown")) url=\(quote(imageFile.url.path))"
            )
            return imageFile.url
        } catch {
            log("dragPasteboard direct image failed error=\(error.localizedDescription)", level: .warning)
            return nil
        }
    }

    @discardableResult
    static func receivePromisedFileFromDragPasteboard(_ completion: @escaping @Sendable (URL?) -> Void) -> Bool {
        let pasteboard = NSPasteboard(name: .drag)
        log("dragPasteboard types=\(pasteboard.types?.map(\.rawValue).sorted().joined(separator: ",") ?? "nil")")
        guard let objects = pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self], options: nil),
              let receiver = objects.first as? NSFilePromiseReceiver
        else {
            log("dragPasteboard filePromiseReceiver missing")
            return false
        }

        log(
            "filePromiseReceiver found fileTypes=\(quote(receiver.fileTypes.joined(separator: ","))) fileNames=\(quote(receiver.fileNames.joined(separator: ",")))"
        )
        let destinationDirectory: URL
        do {
            destinationDirectory = try filePromiseDestinationDirectory()
        } catch {
            log("filePromiseReceiver failed to create destination error=\(error.localizedDescription)", level: .warning)
            completion(nil)
            return true
        }

        let promise = ActiveFilePromise(receiver: receiver, destinationDirectory: destinationDirectory)
        retainActivePromise(promise)
        log("filePromiseReceiver retained id=\(promise.id.uuidString) destination=\(quote(destinationDirectory.path))")
        promise.receiver.receivePromisedFiles(
            atDestination: promise.destinationDirectory,
            options: [:],
            operationQueue: promise.queue
        ) { url, error in
            releaseActivePromise(id: promise.id)
            defer {
                try? FileManager.default.removeItem(at: promise.destinationDirectory)
            }
            if let error {
                log("filePromiseReceiver failed error=\(error.localizedDescription)", level: .warning)
                completion(nil)
                return
            }

            do {
                let copiedURL = try copyPromisedFileToSandbox(url)
                log("filePromiseReceiver received url=\(quote(url.path)) copied=\(quote(copiedURL.path))")
                completion(copiedURL)
            } catch {
                log("filePromiseReceiver failed to copy promised file error=\(error.localizedDescription)", level: .warning)
                completion(nil)
            }
        }
        return true
    }

    private static func retainActivePromise(_ promise: ActiveFilePromise) {
        activePromiseLock.lock()
        activePromises[promise.id] = promise
        activePromiseLock.unlock()
    }

    private static func releaseActivePromise(id: UUID) {
        activePromiseLock.lock()
        activePromises[id] = nil
        activePromiseLock.unlock()
        log("filePromiseReceiver released id=\(id.uuidString)")
    }

    private static func filePromiseDestinationDirectory() throws -> URL {
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let parentURL = downloadsURL.appendingPathComponent(".PlanetFilePromises", isDirectory: true)
        let destinationURL = parentURL.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: destinationURL,
            withIntermediateDirectories: true
        )
        return destinationURL
    }

    private static func copyPromisedFileToSandbox(_ sourceURL: URL) throws -> URL {
        let fileExtension = sourceURL.pathExtension.isEmpty ? "jpg" : sourceURL.pathExtension
        let baseName = sourceURL.deletingPathExtension().lastPathComponent.sanitized().trim()
        let resolvedBaseName = baseName.isEmpty ? UUID().uuidString : baseName
        let destinationURL = uniqueTemporaryFileURL(
            baseName: resolvedBaseName,
            fileExtension: fileExtension
        )
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }

    private static func uniqueTemporaryFileURL(baseName: String, fileExtension: String) -> URL {
        DragPasteboardMedia.uniqueTemporaryFileURL(baseName: baseName, fileExtension: fileExtension)
    }

    static func prepareQuickShare(for fileURL: URL) {
        Task { @MainActor in
            do {
                try PlanetQuickShareViewModel.shared.prepareFiles([fileURL])
                PlanetStore.shared.isQuickSharing = true
                if #available(macOS 14.0, *) {
                    NSApp.activate()
                } else {
                    NSApp.activate(ignoringOtherApps: true)
                }
            } catch {
                log("prepareQuickShare failed error=\(error.localizedDescription)", level: .error)
                let alert = NSAlert()
                alert.messageText = L10n("Failed to Add Attachments")
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.addButton(withTitle: L10n("OK"))
                alert.runModal()
            }
        }
    }

    private static func log(_ message: String, level: PlanetLogger.Level = .info) {
        PlanetLogger.log("DragDrop: \(message)", level: level)
    }

    private static func describeLocation(_ location: CGPoint) -> String {
        "(\(String(format: "%.1f", location.x)),\(String(format: "%.1f", location.y)))"
    }

    private static func quote(_ value: String) -> String {
        let sanitized = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(sanitized)\""
    }
}
