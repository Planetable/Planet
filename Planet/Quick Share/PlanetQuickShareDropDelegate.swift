//
//  PlanetQuickShareDropDelegate.swift
//  Planet
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers


class PlanetQuickShareDropDelegate: DropDelegate {
    init() {}

    static func processDropInfo(_ info: DropInfo) async -> [URL] {
        var urls: [URL] = []
        if #available(macOS 13.0, *) {
            for provider in info.itemProviders(for: [.image, .movie, .pdf]) {
                if let url = try? await provider.loadItem(forTypeIdentifier: UTType.image.identifier) as? URL {
                    urls.append(url)
                    debugPrint("Drop file accepted: \(url)")
                }
                if let url = try? await provider.loadItem(forTypeIdentifier: UTType.pdf.identifier) as? URL {
                    urls.append(url)
                    debugPrint("Drop file accepted: \(url)")
                }
                if let url = try? await provider.loadItem(forTypeIdentifier: UTType.movie.identifier) as? URL {
                    urls.append(url)
                    debugPrint("Drop file accepted: \(url)")
                }
            }
        } else {
            var urls: [URL] = []
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
        return urls
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .copy)
    }

    func validateDrop(info: DropInfo) -> Bool {
        guard let _ = info.itemProviders(for: [.image]).first else { return false }
        return true
    }

    func performDrop(info: DropInfo) -> Bool {
        Task { @MainActor in
            let urls: [URL] = await Self.processDropInfo(info)
            if urls.count > 0 {
                do {
                    try PlanetQuickShareViewModel.shared.prepareFiles(urls)
                } catch {
                    let alert = NSAlert()
                    alert.messageText = "Failed to Add Attachments"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
        return true
    }
}
