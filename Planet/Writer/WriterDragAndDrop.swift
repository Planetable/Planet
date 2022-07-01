import Foundation
import SwiftUI

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
        let supportedExtensions = ["png", "jpeg", "gif", "tiff", "jpg", "webp"]
        Task {
            for provider in providers {
                if let item = try? await provider.loadItem(forTypeIdentifier: kUTTypeFileURL as String),
                   let data = item as? Data,
                   let path = URL(dataRepresentation: data, relativeTo: nil),
                   supportedExtensions.contains(path.pathExtension) {
                    if let newArticleDraft = draft as? NewArticleDraftModel {
                        let type = WriterStore.shared.guessAttachmentType(path: path)
                        try? newArticleDraft.addAttachment(path: path, type: type)
                    } else
                    if let editArticleDraft = draft as? EditArticleDraftModel {
                        let type = WriterStore.shared.guessAttachmentType(path: path)
                        try? editArticleDraft.addAttachment(path: path, type: type)
                    } else {
                        throw PlanetError.InternalError
                    }
                }
            }
        }
        return true
    }
}
