@preconcurrency import AVFoundation
import SwiftUI

private struct CompressionProgressSessionReference: @unchecked Sendable {
    let session: AVAssetExportSession
}

private enum CompressionStorageDecision {
    case blocked
    case compressWithoutBackup
    case compressWithBackup
}

struct VideoInfoRow: View {
    @ObservedObject var videoAttachment: Attachment
    @ObservedObject var viewModel: WriterViewModel
    let removeAction: () -> Void

    @State private var videoInfo: VideoAttachmentInfo?
    @State private var compressionProgress: Double = 0
    @State private var compressionTask: Task<Void, Never>?
    @State private var compressionProgressTimer: Timer?
    @State private var activeExportSession: AVAssetExportSession?
    @State private var compressionStartedAt: Date?
    @State private var compressionFramesPerSecond: Double?
    @State private var isCompressing: Bool = false
    @State private var isShowingCompressionOptions: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(videoDetails.indices, id: \.self) { index in
                            let detail = videoDetails[index]
                            VStack(alignment: .leading, spacing: 2) {
                                Text(detail.title)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(detail.value)
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.primary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .trailing, spacing: 8) {
                    if hasCompressionBackup {
                        Button(
                            "Revert to Original",
                            systemImage: "arrow.counterclockwise",
                            action: revertToOriginal
                        )
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(isCompressing)
                        .help("Restore the original video so you can choose another preset.")
                    } else {
                        Button(
                            "Compress",
                            systemImage: "rectangle.compress.vertical",
                            action: openCompressionOptions
                        )
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(compressButtonDisabled)
                        .help(compressButtonHelpText)
                    }

                    Button("Remove Video", systemImage: "trash", role: .destructive, action: removeAction)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(isCompressing)
                }
            }

            compressionStatusRow()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
        .task(id: videoAttachment.created) {
            viewModel.syncVideoCompressionBackup(for: videoAttachment)
            viewModel.syncVideoCompressionSummary(for: videoAttachment)
            await loadVideoInfo()
        }
        .sheet(isPresented: $isShowingCompressionOptions) {
            compressionOptionsSheet()
        }
        .onDisappear {
            cancelCompression()
        }
    }

    private var videoDetails: [(title: String, value: String)] {
        guard let videoInfo else {
            return [
                ("Length", "Loading..."),
                ("Resolution", "Loading..."),
                ("Codec", "Loading..."),
                ("Color Space", "Loading..."),
                ("Bitrate", "Loading..."),
                ("Frame Rate", "Loading..."),
                ("File Size", "Loading..."),
            ]
        }

        return [
            ("Length", videoInfo.duration),
            ("Resolution", videoInfo.resolution),
            ("Codec", videoInfo.codec),
            ("Color Space", videoInfo.colorSpace),
            ("Bitrate", videoInfo.bitrate),
            ("Frame Rate", videoInfo.frameRate),
            ("File Size", videoInfo.fileSize),
        ]
    }

    private var availableCompressionOptions: [VideoCompressionJob.Option] {
        guard
            let videoInfo,
            let width = videoInfo.pixelWidth,
            let height = videoInfo.pixelHeight
        else {
            return []
        }

        return VideoCompressionJob.Option.allCases.filter {
            $0.isAvailable(forWidth: width, height: height)
                && (!videoInfo.containsHDR || $0.usesHEVC)
        }
    }

    private var hasCompressionBackup: Bool {
        viewModel.matchingVideoCompressionBackup(for: videoAttachment) != nil
    }

    private var compressionSummary: WriterViewModel.VideoCompressionSummary? {
        viewModel.matchingVideoCompressionSummary(for: videoAttachment)
    }

    private var compressButtonDisabled: Bool {
        isCompressing
            || videoAttachment.videoCompressionPreset != nil
            || videoInfo == nil
            || availableCompressionOptions.isEmpty
    }

    private var compressButtonHelpText: String {
        videoAttachment.videoCompressionPreset != nil
            ? "This video has already been compressed."
            : "Compress this video."
    }

    @MainActor
    private func openCompressionOptions() {
        let assessment = compressionStorageDecision(for: videoAttachment.path)
        guard assessment.decision != .blocked else {
            showInsufficientDiskSpaceAlert(
                videoSizeBytes: assessment.videoSizeBytes,
                availableCapacityBytes: assessment.availableCapacityBytes
            )
            return
        }

        isShowingCompressionOptions = true
    }

    @MainActor
    private func startCompression(using option: VideoCompressionJob.Option) {
        guard !isCompressing else {
            return
        }

        let assessment = compressionStorageDecision(for: videoAttachment.path)
        guard assessment.decision != .blocked else {
            isShowingCompressionOptions = false
            showInsufficientDiskSpaceAlert(
                videoSizeBytes: assessment.videoSizeBytes,
                availableCapacityBytes: assessment.availableCapacityBytes
            )
            return
        }

        isShowingCompressionOptions = false
        isCompressing = true
        compressionProgress = 0
        compressionStartedAt = nil
        compressionFramesPerSecond = nil
        viewModel.clearVideoCompressionSummary()

        compressionTask = Task { @MainActor in
            var preparedExport: VideoCompressionJob.PreparedExport?
            var backupURL: URL?
            let sourceURL = videoAttachment.path
            let originalSizeBytes = fileSizeBytes(for: sourceURL)

            do {
                let job = VideoCompressionJob(sourceURL: sourceURL, option: option)
                let export = try await job.prepareExport()
                preparedExport = export
                if assessment.decision == .compressWithBackup {
                    backupURL = try await Task.detached {
                        try VideoInfoRow.makeCompressionBackup(for: sourceURL)
                    }.value
                }
                try Task.checkCancellation()
                activeExportSession = export.session
                let startedAt = Date()
                compressionStartedAt = startedAt
                startCompressionProgressTimer(for: export.session)

                try await VideoCompressionJob.export(export.session)

                guard !Task.isCancelled else {
                    if let backupURL {
                        cleanupCompressionBackup(at: backupURL)
                    }
                    export.cleanupTemporaryFiles()
                    resetCompressionState()
                    return
                }

                updateCompressionProgress(1)
                let elapsedTime = max(Date().timeIntervalSince(startedAt), 0)
                let averageFramesPerSecond = averageCompressionFramesPerSecond(
                    elapsedTime: elapsedTime
                )
                let compressedSizeBytes = fileSizeBytes(for: export.outputURL)

                let newAttachment = try videoAttachment.draft.replaceVideoAttachment(
                    videoAttachment,
                    withVideoAt: export.outputURL,
                    compressionPreset: option.id
                )
                viewModel.storeVideoCompressionSummary(
                    compressedAttachmentName: newAttachment.name,
                    originalSizeBytes: originalSizeBytes,
                    compressedSizeBytes: compressedSizeBytes,
                    elapsedTime: elapsedTime,
                    averageFramesPerSecond: averageFramesPerSecond
                )
                if let backupURL {
                    viewModel.storeVideoCompressionBackup(
                        originalVideoURL: backupURL,
                        compressedAttachmentName: newAttachment.name
                    )
                }
                export.cleanupTemporaryFiles()
                resetCompressionState()
            } catch is CancellationError {
                if let backupURL {
                    cleanupCompressionBackup(at: backupURL)
                }
                preparedExport?.cleanupTemporaryFiles()
                resetCompressionState()
            } catch {
                if let backupURL {
                    cleanupCompressionBackup(at: backupURL)
                }
                preparedExport?.cleanupTemporaryFiles()
                resetCompressionState()
                PlanetStore.shared.alert(
                    title: "Failed to Compress Video",
                    message: error.localizedDescription
                )
            }
        }
    }

    @MainActor
    private func startCompressionProgressTimer(for session: AVAssetExportSession) {
        stopCompressionProgressTimer()
        let reference = CompressionProgressSessionReference(session: session)
        let timer = Timer(timeInterval: 0.1, repeats: true) { _ in
            updateCompressionProgress(min(max(Double(reference.session.progress), 0), 1))
        }
        RunLoop.main.add(timer, forMode: .common)
        compressionProgressTimer = timer
    }

    @MainActor
    private func stopCompressionProgressTimer() {
        compressionProgressTimer?.invalidate()
        compressionProgressTimer = nil
    }

    @MainActor
    private func cancelCompression() {
        activeExportSession?.cancelExport()
        compressionTask?.cancel()
        resetCompressionState()
    }

    @MainActor
    private func resetCompressionState() {
        stopCompressionProgressTimer()
        activeExportSession = nil
        isCompressing = false
        compressionProgress = 0
        compressionStartedAt = nil
        compressionFramesPerSecond = nil
        compressionTask = nil
    }

    @MainActor
    private func revertToOriginal() {
        guard let backup = viewModel.matchingVideoCompressionBackup(for: videoAttachment) else {
            return
        }

        do {
            _ = try videoAttachment.draft.replaceVideoAttachment(
                videoAttachment,
                withVideoAt: backup.originalVideoURL,
                compressionPreset: nil
            )
            viewModel.clearVideoCompressionSummary()
            viewModel.clearVideoCompressionBackup()
        } catch {
            PlanetStore.shared.alert(
                title: "Failed to Revert Video",
                message: error.localizedDescription
            )
        }
    }

    private var compressionStatusText: String {
        let progressText = "\(Int((compressionProgress * 100).rounded()))%"
        guard let compressionFramesPerSecond,
              compressionFramesPerSecond.isFinite,
              compressionFramesPerSecond > 0
        else {
            return "Compressing video... \(progressText)"
        }

        return "Compressing video... \(progressText) · \(formattedFramesPerSecond(compressionFramesPerSecond))"
    }

    private func updateCompressionProgress(_ progress: Double) {
        compressionProgress = progress

        guard
            let compressionStartedAt,
            let totalFrames = compressionTotalFrames,
            totalFrames > 0
        else {
            compressionFramesPerSecond = nil
            return
        }

        let elapsed = Date().timeIntervalSince(compressionStartedAt)
        guard elapsed >= 0.25 else {
            return
        }

        compressionFramesPerSecond = (progress * totalFrames) / elapsed
    }

    private var compressionTotalFrames: Double? {
        guard
            let duration = videoInfo?.durationSecondsValue,
            let frameRate = videoInfo?.frameRateValue,
            duration > 0,
            frameRate > 0
        else {
            return nil
        }

        return duration * frameRate
    }

    private func formattedFramesPerSecond(_ framesPerSecond: Double) -> String {
        if framesPerSecond >= 10 {
            return String(format: "%.0f fps", framesPerSecond)
        } else {
            return String(format: "%.1f fps", framesPerSecond)
        }
    }

    private func averageCompressionFramesPerSecond(elapsedTime: TimeInterval) -> Double? {
        guard
            elapsedTime > 0,
            let totalFrames = compressionTotalFrames,
            totalFrames > 0
        else {
            return nil
        }

        return totalFrames / elapsedTime
    }

    @ViewBuilder
    private func compressionOptionsSheet() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Compress Video")
                    .font(.title3.weight(.semibold))
                Text("Choose a codec and maximum size for this attachment.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if videoInfo?.containsHDR == true {
                    Text("HDR source detected. H264 options are hidden to preserve the original color space.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 10) {
                ForEach(availableCompressionOptions) { option in
                    Button {
                        startCompression(using: option)
                    } label: {
                        Text(option.title)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    isShowingCompressionOptions = false
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(width: 360)
    }

    private func compressionStorageDecision(
        for sourceURL: URL
    ) -> (decision: CompressionStorageDecision, videoSizeBytes: Int64?, availableCapacityBytes: Int64?) {
        guard let videoSizeBytes = fileSizeBytes(for: sourceURL), videoSizeBytes > 0 else {
            return (.compressWithoutBackup, nil, temporaryDirectoryAvailableCapacityBytes())
        }

        guard let availableCapacityBytes = temporaryDirectoryAvailableCapacityBytes() else {
            return (.compressWithoutBackup, videoSizeBytes, nil)
        }

        if availableCapacityBytes < videoSizeBytes {
            return (.blocked, videoSizeBytes, availableCapacityBytes)
        }

        let tenTimesVideoSize = videoSizeBytes.multipliedReportingOverflow(by: 10)
        if !tenTimesVideoSize.overflow, availableCapacityBytes >= tenTimesVideoSize.partialValue {
            return (.compressWithBackup, videoSizeBytes, availableCapacityBytes)
        }

        return (.compressWithoutBackup, videoSizeBytes, availableCapacityBytes)
    }

    private func fileSizeBytes(for url: URL) -> Int64? {
        guard let fileSize = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
            return nil
        }
        return Int64(fileSize)
    }

    private func temporaryDirectoryAvailableCapacityBytes() -> Int64? {
        let temporaryDirectory = FileManager.default.temporaryDirectory
        if let resourceValues = try? temporaryDirectory.resourceValues(
            forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey]
        ) {
            if let availableCapacity = resourceValues.volumeAvailableCapacityForImportantUsage {
                return availableCapacity
            }
            if let availableCapacity = resourceValues.volumeAvailableCapacity {
                return Int64(availableCapacity)
            }
        }

        if let attributes = try? FileManager.default.attributesOfFileSystem(
            forPath: temporaryDirectory.path
        ) {
            if let availableCapacity = attributes[.systemFreeSize] as? NSNumber {
                return availableCapacity.int64Value
            }
            if let availableCapacity = attributes[.systemFreeSize] as? Int64 {
                return availableCapacity
            }
        }

        return nil
    }

    private static func makeCompressionBackup(for sourceURL: URL) throws -> URL {
        let backupDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PlanetVideoCompressionBackup", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: backupDirectory,
            withIntermediateDirectories: true
        )

        let backupURL = backupDirectory.appendingPathComponent(
            sourceURL.lastPathComponent,
            isDirectory: false
        )
        try FileManager.default.copyItem(at: sourceURL, to: backupURL)
        return backupURL
    }

    private func cleanupCompressionBackup(at backupURL: URL) {
        try? FileManager.default.removeItem(at: backupURL.deletingLastPathComponent())
    }

    private func showInsufficientDiskSpaceAlert(
        videoSizeBytes: Int64?,
        availableCapacityBytes: Int64?
    ) {
        let message: String
        if let videoSizeBytes, let availableCapacityBytes {
            message = "Planet needs at least \(formattedByteCount(videoSizeBytes)) of free temporary disk space to compress this video. Only \(formattedByteCount(availableCapacityBytes)) is currently available."
        } else {
            message = "Planet needs at least as much free temporary disk space as the source video size to compress this video."
        }

        PlanetStore.shared.alert(
            title: "Not Enough Disk Space to Compress Video",
            message: message
        )
    }

    private func formattedByteCount(_ byteCount: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
    }

    private func formattedCompressionDuration(_ elapsedTime: TimeInterval) -> String {
        if elapsedTime >= 10 {
            return String(format: "%.1fs", elapsedTime)
        } else {
            return String(format: "%.2fs", elapsedTime)
        }
    }

    private func formattedSize(_ byteCount: Int64?) -> String {
        guard let byteCount else {
            return "Unknown"
        }

        return formattedByteCount(byteCount)
    }

    private func compressionSummaryText(
        for summary: WriterViewModel.VideoCompressionSummary
    ) -> String {
        let sizeReductionText = "\(formattedSize(summary.originalSizeBytes)) → \(formattedSize(summary.compressedSizeBytes))"
        var details: [String] = [
            "Size \(sizeReductionText)",
            "Took \(formattedCompressionDuration(summary.elapsedTime))",
        ]

        if let averageFramesPerSecond = summary.averageFramesPerSecond,
           averageFramesPerSecond.isFinite,
           averageFramesPerSecond > 0 {
            details.append("Avg \(formattedFramesPerSecond(averageFramesPerSecond))")
        }

        return details.joined(separator: " · ")
    }

    @ViewBuilder
    private func compressionStatusRow() -> some View {
        if isCompressing {
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: compressionProgress, total: 1)
                    .progressViewStyle(.linear)
                HStack {
                    Text(compressionStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Cancel") {
                        cancelCompression()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .transition(.opacity)
        } else if let compressionSummary {
            Label {
                Text(compressionSummaryText(for: compressionSummary))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
    }

    @MainActor
    private func loadVideoInfo() async {
        videoInfo = nil
        let info = await VideoAttachmentInfo.load(from: videoAttachment.path)

        guard !Task.isCancelled else {
            return
        }

        videoInfo = info
    }
}
