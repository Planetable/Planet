import Foundation
import SwiftUI
import UniformTypeIdentifiers


class WriterDragAndDrop: ObservableObject, DropDelegate {
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
        if #available(macOS 13.0, *) {
            let providers = info.itemProviders(for: [.image])
            Task {
                for provider in providers {
                    if let url = try? await provider.loadItem(forTypeIdentifier: UTType.image.identifier) as? URL {
                        do {
                            try draft.addAttachment(path: url, type: AttachmentType.from(url))
                            try draft.save()
                        } catch {
                            debugPrint("failed to add attachment: \(error)")
                        }
                    }
                }
            }
        } else {
            let providers = info.itemProviders(for: [.fileURL])
            let supportedExtensions = ["png", "heic", "jpeg", "gif", "tiff", "jpg", "webp"]
            Task {
                for provider in providers {
                    if let item = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier),
                       let data = item as? Data,
                       let path = URL(dataRepresentation: data, relativeTo: nil),
                       supportedExtensions.contains(path.pathExtension) {
                        do {
                            try draft.addAttachment(path: path, type: AttachmentType.from(path))
                            try draft.save()
                        } catch {
                            debugPrint("failed to add attachment: \(error)")
                        }
                    }
                }
            }
        }
        return true
    }
}
