//
//  AppContentDropDelegate.swift
//  PlanetLite
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

// TODO: Rename this to QuickShareDropDelegate and use it in ArticleList too
class AppContentDropDelegate: DropDelegate {
    init() {
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .copy)
    }

    func validateDrop(info: DropInfo) -> Bool {
        guard !PlanetStore.shared.isQuickSharing else { return false }
        guard let _ = info.itemProviders(for: [.image]).first else { return false }
        return true
    }

    func performDrop(info: DropInfo) -> Bool {
        guard !PlanetStore.shared.isQuickSharing else { return false }
        Task { @MainActor in
            if #available(macOS 13.0, *) {
                var urls: [URL] = []
                for provider in info.itemProviders(for: [.image, .pdf, .movie]) {
                    if let url = try? await provider.loadItem(forTypeIdentifier: UTType.image.identifier) as? URL {
                        urls.append(url)
                    }
                    if let url = try? await provider.loadItem(forTypeIdentifier: UTType.pdf.identifier) as? URL {
                        urls.append(url)
                    }
                    if let url = try? await provider.loadItem(forTypeIdentifier: UTType.movie.identifier) as? URL {
                        urls.append(url)
                        debugPrint("Drop file accepted: \(url)")
                    }
                }
                if urls.count > 0 {
                    do {
                        try PlanetQuickShareViewModel.shared.prepareFiles(urls)
                        PlanetStore.shared.isQuickSharing = true
                    } catch {
                        let alert = NSAlert()
                        alert.messageText = "Failed to Create Post"
                        alert.informativeText = error.localizedDescription
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
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
                if urls.count > 0 {
                    do {
                        try PlanetQuickShareViewModel.shared.prepareFiles(urls)
                        PlanetStore.shared.isQuickSharing = true
                    } catch {
                        let alert = NSAlert()
                        alert.messageText = "Failed to Create Post"
                        alert.informativeText = error.localizedDescription
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                    }
                }
            }
        }
        return true
    }
}
