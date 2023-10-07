import Foundation
import UniformTypeIdentifiers

@MainActor class WriterViewModel: ObservableObject {
    static let choosingAttachment: Notification.Name = Notification.Name("WriterChooseAttachmentsNotification")
    
    @Published var attachmentType: AttachmentType = .file
    @Published var allowedContentTypes: [UTType] = []
    @Published var allowMultipleSelection = false
    @Published var isMediaTrayOpen = false
    @Published var isShowingDiscardConfirmation = false
    @Published var madeDiscardChoice = false

    func chooseImages() {
        attachmentType = .image
        allowedContentTypes = [.png, .webP, .jpeg, .gif]
        allowMultipleSelection = true
        NotificationCenter.default.post(name: Self.choosingAttachment, object: nil)
    }

    func chooseVideo() {
        attachmentType = .video
        allowedContentTypes = [.mpeg4Movie, .quickTimeMovie]
        allowMultipleSelection = false
        NotificationCenter.default.post(name: Self.choosingAttachment, object: nil)
    }

    func chooseAudio() {
        attachmentType = .audio
        allowedContentTypes = [.mp3, .mpeg4Audio, .wav]
        allowMultipleSelection = false
        NotificationCenter.default.post(name: Self.choosingAttachment, object: nil)
    }
}
