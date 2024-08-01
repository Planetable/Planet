//
//  QuickPostViewModel.swift
//  Planet
//
//  Created by Xin Liu on 7/30/24.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

class QuickPostViewModel: ObservableObject {
    static let shared = QuickPostViewModel()

    @Published var content: String = ""

    @Published var heroImage: String? = nil
    @Published var fileURLs: [URL] = []

    @MainActor
    func prepareFiles(_ files: [URL]) throws {
        fileURLs += files
        debugPrint("Pasted files: \(fileURLs)")
    }

    func processPasteItems(_ providers: [NSItemProvider]) {
        Task(priority: .utility) {
            var urls: [URL] = []
            var handled: [NSItemProvider] = []
            for provider in providers {
                // handle .fileURL
                let urlData = try? await provider.loadItem(
                    forTypeIdentifier: UTType.fileURL.identifier
                )
                if let urlData = urlData as? Data {
                    let imageURL =
                        NSURL(absoluteURLWithDataRepresentation: urlData, relativeTo: nil) as URL
                    if isImageFile(url: imageURL) {
                        urls.append(imageURL)
                        handled.append(provider)
                    }
                }
                // handle .image
                if handled.contains(provider) {
                    continue
                }
                let imageData = try? await provider.loadItem(
                    forTypeIdentifier: UTType.image.identifier
                )
                if let imageData = imageData, let data = imageData as? Data,
                    let image = NSImage(data: data)
                {
                    if let pngImageData = image.PNGData {
                        // Write the image as a PNG into temporary and add it to the attachments
                        let fileName = UUID().uuidString + ".png"
                        // Save image to temporary directory
                        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(
                            fileName
                        )
                        do {
                            try pngImageData.write(to: fileURL)
                            urls.append(fileURL)
                        }
                        catch {
                            debugPrint("Failed to write image to temporary directory: \(error)")
                        }
                    }
                }
            }
            guard urls.count > 0 else { return }
            let processedURLs = urls
            Task { @MainActor in
                do {
                    try QuickPostViewModel.shared.prepareFiles(processedURLs)
                }
                catch {
                    debugPrint("failed to process paste images: \(error)")
                }
            }
        }
    }

    private func isImageFile(url: URL) -> Bool {
        let imageTypes: [UTType] = [.png, .jpeg, .gif, .tiff, .gif]
        if let fileUTI = UTType(filenameExtension: url.pathExtension),
            imageTypes.contains(fileUTI)
        {
            return true
        }
        return false
    }

    func cleanup() {
    }
}
