//
//  PlanetQuickSharePasteView.swift
//  Planet
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers


struct PlanetQuickSharePasteView: View {
    var body: some View {
        VStack {
            Text("")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .focusable()
        .opacity(0)
        .onPasteCommand(of: [.fileURL], perform: processPasteItems(_:))
    }
    
    private func processPasteItems(_ providers: [NSItemProvider]) {
        Task(priority: .utility) {
            var urls: [URL] = []
            for provider in providers {
                let urlData = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier)
                if let urlData = urlData as? Data {
                    let imageURL = NSURL(absoluteURLWithDataRepresentation: urlData, relativeTo: nil) as URL
                    if isImageFile(url: imageURL) {
                        urls.append(imageURL)
                    }
                }
            }
            guard urls.count > 0 else { return }
            let processedURLs = urls
            Task { @MainActor in
                do {
                    try PlanetQuickShareViewModel.shared.prepareFiles(processedURLs)
                } catch {
                    debugPrint("failed to process paste images: \(error)")
                }
            }
        }
    }
    
    private func isImageFile(url: URL) -> Bool {
        let imageTypes: [UTType] = [.png, .jpeg, .gif, .tiff, .gif]
        if let fileUTI = UTType(filenameExtension: url.pathExtension),
           imageTypes.contains(fileUTI) {
            return true
        }
        return false
    }
}


extension NSItemProvider: @unchecked Sendable {}
