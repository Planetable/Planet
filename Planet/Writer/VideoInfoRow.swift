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

private struct CompressionStorageAssessment {
    let decision: CompressionStorageDecision
    let videoSizeBytes: Int64?
    let requiredCapacityBytes: Int64?
    let requiredCapacityWithBackupBytes: Int64?
    let availableCapacityBytes: Int64?
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
    @State private var lastLoggedCompressionProgressStep: Int = -1
    @State private var presentableCompressionOptions: [VideoCompressionJob.Option] = []
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
        let assessments = availableCompressionOptions.map {
            ($0, compressionStorageAssessment(for: videoAttachment.path, option: $0))
        }
        let feasibleOptions = assessments.compactMap { option, assessment in
            assessment.decision == .blocked ? nil : option
        }
        presentableCompressionOptions = feasibleOptions
        guard !feasibleOptions.isEmpty else {
            let blockingAssessment = assessments
                .map(\.1)
                .min { lhs, rhs in
                    (lhs.requiredCapacityBytes ?? .max) < (rhs.requiredCapacityBytes ?? .max)
                } ?? compressionStorageAssessment(for: videoAttachment.path, option: nil)
            logStorageAssessment(blockingAssessment, context: "openCompressionOptions")
            log("compression options blocked because temporary disk space is insufficient")
            showInsufficientDiskSpaceAlert(
                requiredCapacityBytes: blockingAssessment.requiredCapacityBytes,
                availableCapacityBytes: blockingAssessment.availableCapacityBytes
            )
            return
        }

        log(
            "showing compression options availableOptions=\(feasibleOptions.map(\.id).joined(separator: ",")) videoInfoLoaded=\(videoInfo != nil)"
        )
        isShowingCompressionOptions = true
    }

    @MainActor
    private func startCompression(using option: VideoCompressionJob.Option) {
        guard !isCompressing else {
            log("ignoring compression request because a compression task is already active")
            return
        }

        let assessment = compressionStorageAssessment(for: videoAttachment.path, option: option)
        logStorageAssessment(assessment, context: "startCompression")
        guard assessment.decision != .blocked else {
            isShowingCompressionOptions = false
            log("compression blocked before starting export")
            showInsufficientDiskSpaceAlert(
                requiredCapacityBytes: assessment.requiredCapacityBytes,
                availableCapacityBytes: assessment.availableCapacityBytes
            )
            return
        }

        isShowingCompressionOptions = false
        isCompressing = true
        compressionProgress = 0
        compressionStartedAt = nil
        compressionFramesPerSecond = nil
        lastLoggedCompressionProgressStep = -1
        viewModel.clearVideoCompressionSummary()
        log(
            "compression requested option={\(option.debugDescription)} sourcePath=\(videoAttachment.path.path) sourceSizeBytes=\(formatBytes(fileSizeBytes(for: videoAttachment.path)))"
        )

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
                    log("creating temporary backup for sourcePath=\(sourceURL.path)")
                    backupURL = try await Task.detached {
                        try VideoInfoRow.makeCompressionBackup(for: sourceURL)
                    }.value
                    log("temporary backup created backupPath=\(backupURL?.path ?? "nil")")
                }
                try Task.checkCancellation()
                activeExportSession = export.session
                let startedAt = Date()
                compressionStartedAt = startedAt
                log(
                    "starting export outputPath=\(export.outputURL.path) outputFileType=\(export.session.outputFileType?.rawValue ?? "nil") backupPath=\(backupURL?.path ?? "nil")"
                )
                startCompressionProgressTimer(for: export.session)

                try await VideoCompressionJob.export(export.session)

                guard !Task.isCancelled else {
                    log("compression task was cancelled after export completed; cleaning up temporary files")
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
                log(
                    "compression succeeded newAttachmentName=\(newAttachment.name) compressedPath=\(newAttachment.path.path) originalSizeBytes=\(formatBytes(originalSizeBytes)) compressedSizeBytes=\(formatBytes(compressedSizeBytes)) elapsedSeconds=\(String(format: "%.3f", elapsedTime)) averageFPS=\(formatFramesPerSecond(averageFramesPerSecond)) backupRetained=\(backupURL != nil)"
                )
                export.cleanupTemporaryFiles()
                resetCompressionState()
            } catch is CancellationError {
                log(
                    "compression cancelled sourcePath=\(sourceURL.path) backupPath=\(backupURL?.path ?? "nil") temporaryOutputPath=\(preparedExport?.outputURL.path ?? "nil")"
                )
                if let backupURL {
                    cleanupCompressionBackup(at: backupURL)
                }
                preparedExport?.cleanupTemporaryFiles()
                resetCompressionState()
            } catch {
                log(
                    "compression failed sourcePath=\(sourceURL.path) backupPath=\(backupURL?.path ?? "nil") temporaryOutputPath=\(preparedExport?.outputURL.path ?? "nil") error=\(describeError(error))"
                )
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
        log("starting compression progress timer outputPath=\(session.outputURL?.path ?? "nil")")
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
        guard activeExportSession != nil || compressionTask != nil else {
            return
        }
        log(
            "cancel requested progress=\(String(format: "%.3f", compressionProgress)) outputPath=\(activeExportSession?.outputURL?.path ?? "nil")"
        )
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
        lastLoggedCompressionProgressStep = -1
        compressionTask = nil
    }

    @MainActor
    private func revertToOriginal() {
        guard let backup = viewModel.matchingVideoCompressionBackup(for: videoAttachment) else {
            log("revert requested but no backup is available")
            return
        }

        do {
            log("reverting to original backupPath=\(backup.originalVideoURL.path)")
            _ = try videoAttachment.draft.replaceVideoAttachment(
                videoAttachment,
                withVideoAt: backup.originalVideoURL,
                compressionPreset: nil
            )
            viewModel.clearVideoCompressionSummary()
            viewModel.clearVideoCompressionBackup()
            log("revert to original succeeded")
        } catch {
            log("revert to original failed error=\(describeError(error))")
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
            logCompressionProgressIfNeeded(progress)
            return
        }

        let elapsed = Date().timeIntervalSince(compressionStartedAt)
        guard elapsed >= 0.25 else {
            return
        }

        compressionFramesPerSecond = (progress * totalFrames) / elapsed
        logCompressionProgressIfNeeded(progress)
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
                ForEach(presentableCompressionOptions) { option in
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

    private func compressionStorageAssessment(
        for sourceURL: URL,
        option: VideoCompressionJob.Option?
    ) -> CompressionStorageAssessment {
        let videoSizeBytes = fileSizeBytes(for: sourceURL)
        let requiredCapacityBytes =
            option?.estimatedMultipassTemporaryCapacityBytes(
                durationSeconds: videoInfo?.durationSecondsValue,
                sourceFileSizeBytes: videoSizeBytes
            )
            ?? videoSizeBytes?.multipliedReportingOverflow(by: 2).partialValue
        let requiredCapacityWithBackupBytes: Int64?
        if let requiredCapacityBytes, let videoSizeBytes {
            let sum = requiredCapacityBytes.addingReportingOverflow(videoSizeBytes)
            requiredCapacityWithBackupBytes = sum.overflow ? Int64.max : sum.partialValue
        } else {
            requiredCapacityWithBackupBytes = nil
        }

        guard let availableCapacityBytes = temporaryDirectoryAvailableCapacityBytes() else {
            return CompressionStorageAssessment(
                decision: .compressWithoutBackup,
                videoSizeBytes: videoSizeBytes,
                requiredCapacityBytes: requiredCapacityBytes,
                requiredCapacityWithBackupBytes: requiredCapacityWithBackupBytes,
                availableCapacityBytes: nil
            )
        }

        if let requiredCapacityBytes, availableCapacityBytes < requiredCapacityBytes {
            return CompressionStorageAssessment(
                decision: .blocked,
                videoSizeBytes: videoSizeBytes,
                requiredCapacityBytes: requiredCapacityBytes,
                requiredCapacityWithBackupBytes: requiredCapacityWithBackupBytes,
                availableCapacityBytes: availableCapacityBytes
            )
        }

        if let requiredCapacityWithBackupBytes,
           availableCapacityBytes >= requiredCapacityWithBackupBytes {
            return CompressionStorageAssessment(
                decision: .compressWithBackup,
                videoSizeBytes: videoSizeBytes,
                requiredCapacityBytes: requiredCapacityBytes,
                requiredCapacityWithBackupBytes: requiredCapacityWithBackupBytes,
                availableCapacityBytes: availableCapacityBytes
            )
        }

        return CompressionStorageAssessment(
            decision: .compressWithoutBackup,
            videoSizeBytes: videoSizeBytes,
            requiredCapacityBytes: requiredCapacityBytes,
            requiredCapacityWithBackupBytes: requiredCapacityWithBackupBytes,
            availableCapacityBytes: availableCapacityBytes
        )
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

    nonisolated private static func makeCompressionBackup(for sourceURL: URL) throws -> URL {
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
        VideoLogger.log(
            "[VideoInfoRow] created compression backup sourcePath=\(sourceURL.path) backupPath=\(backupURL.path)"
        )
        return backupURL
    }

    private func cleanupCompressionBackup(at backupURL: URL) {
        let directoryURL = backupURL.deletingLastPathComponent()
        do {
            try FileManager.default.removeItem(at: directoryURL)
            log("removed temporary backup directory path=\(directoryURL.path)")
        } catch {
            log("failed to remove temporary backup directory path=\(directoryURL.path) error=\(describeError(error))")
        }
    }

    private func showInsufficientDiskSpaceAlert(
        requiredCapacityBytes: Int64?,
        availableCapacityBytes: Int64?
    ) {
        let message: String
        if let requiredCapacityBytes, let availableCapacityBytes {
            message = "Planet needs at least \(formattedByteCount(requiredCapacityBytes)) of free temporary disk space to compress this video. Only \(formattedByteCount(availableCapacityBytes)) is currently available."
        } else {
            message = "Planet needs more free temporary disk space to compress this video."
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
            log("loadVideoInfo cancelled before metadata could be applied")
            return
        }

        videoInfo = info
        log("loaded video metadata \(describeVideoInfo(info))")
    }

    private func log(_ message: String) {
        VideoLogger.log(
            "[VideoInfoRow] draftID=\(videoAttachment.draft.id.uuidString) attachmentName=\(videoAttachment.name) path=\(videoAttachment.path.path) \(message)"
        )
    }

    private func logStorageAssessment(
        _ assessment: CompressionStorageAssessment,
        context: String
    ) {
        log(
            "\(context) decision=\(describeStorageDecision(assessment.decision)) videoSizeBytes=\(formatBytes(assessment.videoSizeBytes)) requiredCapacityBytes=\(formatBytes(assessment.requiredCapacityBytes)) requiredCapacityWithBackupBytes=\(formatBytes(assessment.requiredCapacityWithBackupBytes)) availableCapacityBytes=\(formatBytes(assessment.availableCapacityBytes))"
        )
    }

    private func logCompressionProgressIfNeeded(_ progress: Double) {
        let boundedProgress = min(max(progress, 0), 1)
        let progressStep = Int((boundedProgress * 100).rounded(.down) / 5) * 5
        guard
            progressStep > lastLoggedCompressionProgressStep
                || (boundedProgress >= 1 && lastLoggedCompressionProgressStep < 100)
        else {
            return
        }

        lastLoggedCompressionProgressStep = progressStep
        log(
            "compression progress percent=\(progressStep) rawProgress=\(String(format: "%.3f", boundedProgress)) currentFPS=\(formatFramesPerSecond(compressionFramesPerSecond))"
        )
    }

    private func describeStorageDecision(_ decision: CompressionStorageDecision) -> String {
        switch decision {
        case .blocked:
            return "blocked"
        case .compressWithoutBackup:
            return "compressWithoutBackup"
        case .compressWithBackup:
            return "compressWithBackup"
        }
    }

    private func formatBytes(_ value: Int64?) -> String {
        guard let value else {
            return "nil"
        }
        return "\(value)"
    }

    private func formatFramesPerSecond(_ value: Double?) -> String {
        guard let value, value.isFinite else {
            return "nil"
        }
        return String(format: "%.3f", value)
    }

    private func describeError(_ error: Error) -> String {
        let nsError = error as NSError
        return "domain=\(nsError.domain) code=\(nsError.code) description=\(nsError.localizedDescription)"
    }

    private func describeVideoInfo(_ info: VideoAttachmentInfo) -> String {
        [
            "duration=\(info.duration)",
            "resolution=\(info.resolution)",
            "codec=\(info.codec)",
            "colorSpace=\(info.colorSpace)",
            "bitrate=\(info.bitrate)",
            "frameRate=\(info.frameRate)",
            "fileSize=\(info.fileSize)",
            "pixelWidth=\(info.pixelWidth.map(String.init) ?? "nil")",
            "pixelHeight=\(info.pixelHeight.map(String.init) ?? "nil")",
            "containsHDR=\(info.containsHDR)",
            "availableOptions=\(availableCompressionOptions.map(\.id).joined(separator: ","))",
        ]
        .joined(separator: " ")
    }
}
