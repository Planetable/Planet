import Foundation
import UniformTypeIdentifiers

class WriterViewModel: ObservableObject {
    static let imageTypes: [UTType] = [.png, .jpeg, .gif, .webP]
    static let videoTypes: [UTType] = [.mpeg4Movie, .quickTimeMovie]

    @Published var attachmentType: AttachmentType = .file
    @Published var isChoosingAttachment = false
    @Published var allowedContentTypes = imageTypes
    @Published var allowMultipleSelection = false
    @Published var isMediaTrayOpen = false
    @Published var hasVideo: Bool = false
    @Published var videoPath: URL?

    func chooseImages() {
        attachmentType = .image
        allowedContentTypes = WriterViewModel.imageTypes
        allowMultipleSelection = true
        isChoosingAttachment = true
    }

    func chooseVideo() {
        attachmentType = .video
        allowedContentTypes = WriterViewModel.videoTypes
        allowMultipleSelection = false
        isChoosingAttachment = true
    }
}
