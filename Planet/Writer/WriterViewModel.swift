import Foundation
import UniformTypeIdentifiers

@MainActor class WriterViewModel: ObservableObject {
    struct VideoCompressionBackup {
        let compressedAttachmentName: String
        let originalVideoURL: URL
    }

    struct VideoCompressionSummary {
        let compressedAttachmentName: String
        let originalSizeBytes: Int64?
        let compressedSizeBytes: Int64?
        let elapsedTime: TimeInterval
        let averageFramesPerSecond: Double?
    }

    static let choosingAttachment: Notification.Name = Notification.Name("WriterChooseAttachmentsNotification")

    @Published var attachmentType: AttachmentType = .file
    @Published var allowedContentTypes: [UTType] = []
    @Published var allowMultipleSelection = false
    @Published var isMediaTrayOpen = false
    @Published var isShowingDiscardConfirmation = false
    @Published var madeDiscardChoice = false
    @Published private(set) var videoCompressionBackup: VideoCompressionBackup?
    @Published private(set) var videoCompressionSummary: VideoCompressionSummary?

    func matchingVideoCompressionBackup(for attachment: Attachment) -> VideoCompressionBackup? {
        guard let videoCompressionBackup,
              videoCompressionBackup.compressedAttachmentName == attachment.name,
              FileManager.default.fileExists(atPath: videoCompressionBackup.originalVideoURL.path)
        else {
            return nil
        }

        return videoCompressionBackup
    }

    func storeVideoCompressionBackup(
        originalVideoURL: URL,
        compressedAttachmentName: String
    ) {
        clearVideoCompressionBackup()
        videoCompressionBackup = VideoCompressionBackup(
            compressedAttachmentName: compressedAttachmentName,
            originalVideoURL: originalVideoURL
        )
    }

    func syncVideoCompressionBackup(for attachment: Attachment?) {
        guard let videoCompressionBackup else {
            return
        }

        guard let attachment,
              videoCompressionBackup.compressedAttachmentName == attachment.name,
              FileManager.default.fileExists(atPath: videoCompressionBackup.originalVideoURL.path)
        else {
            clearVideoCompressionBackup()
            return
        }
    }

    func clearVideoCompressionBackup() {
        guard let videoCompressionBackup else {
            return
        }

        try? FileManager.default.removeItem(
            at: videoCompressionBackup.originalVideoURL.deletingLastPathComponent()
        )
        self.videoCompressionBackup = nil
    }

    func matchingVideoCompressionSummary(for attachment: Attachment) -> VideoCompressionSummary? {
        guard let videoCompressionSummary,
              videoCompressionSummary.compressedAttachmentName == attachment.name
        else {
            return nil
        }

        return videoCompressionSummary
    }

    func storeVideoCompressionSummary(
        compressedAttachmentName: String,
        originalSizeBytes: Int64?,
        compressedSizeBytes: Int64?,
        elapsedTime: TimeInterval,
        averageFramesPerSecond: Double?
    ) {
        videoCompressionSummary = VideoCompressionSummary(
            compressedAttachmentName: compressedAttachmentName,
            originalSizeBytes: originalSizeBytes,
            compressedSizeBytes: compressedSizeBytes,
            elapsedTime: elapsedTime,
            averageFramesPerSecond: averageFramesPerSecond
        )
    }

    func syncVideoCompressionSummary(for attachment: Attachment?) {
        guard let videoCompressionSummary else {
            return
        }

        guard let attachment,
              videoCompressionSummary.compressedAttachmentName == attachment.name
        else {
            clearVideoCompressionSummary()
            return
        }
    }

    func clearVideoCompressionSummary() {
        videoCompressionSummary = nil
    }

    func chooseImages() {
        attachmentType = .image
        allowedContentTypes = [.png, .webP, .jpeg, .gif, .heic, .heif, .tiff, .image]
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
