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
        let providers = info.itemProviders(for: [.fileURL])
        Task(priority: .userInitiated) {
            for provider in providers {
                if let item = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier),
                   let data = item as? Data,
                   let path = URL(dataRepresentation: data, relativeTo: nil) {
                    do {
                        try draft.addAttachment(path: path, type: AttachmentType.from(path))
                        try draft.save()
                    } catch {
                        debugPrint("failed to add attachment: \(error)")
                    }
                }
            }
        }
        return true
    }
}
