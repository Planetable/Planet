import Foundation
import UniformTypeIdentifiers

@MainActor class WriterViewModel: ObservableObject {
    @Published var attachmentType: AttachmentType = .file
    @Published var isChoosingAttachment = false
    @Published var allowedContentTypes: [UTType] = []
    @Published var allowMultipleSelection = false
    @Published var isMediaTrayOpen = false
    @Published var isShowingEmptyTitleAlert = false
    @Published var isShowingClosingWindowConfirmation = false

    func chooseImages() {
        attachmentType = .image
        allowedContentTypes = [.image]
        allowMultipleSelection = true
        isChoosingAttachment = true
    }

    func chooseVideo() {
        attachmentType = .video
        allowedContentTypes = [.video, .movie]
        allowMultipleSelection = false
        isChoosingAttachment = true
    }
}
