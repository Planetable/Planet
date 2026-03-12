@preconcurrency import AVFoundation
import SwiftUI

private struct CompressionProgressSessionReference: @unchecked Sendable {
    let session: AVAssetExportSession
}

struct VideoInfoRow: View {
    @ObservedObject var videoAttachment: Attachment
    let removeAction: () -> Void

    @State private var videoInfo: VideoAttachmentInfo?
    @State private var compressionProgress: Double = 0
    @State private var compressionTask: Task<Void, Never>?
    @State private var compressionProgressTimer: Timer?
    @State private var activeExportSession: AVAssetExportSession?
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
                    Button("Compress", systemImage: "rectangle.compress.vertical") {
                        isShowingCompressionOptions = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(compressButtonDisabled)
                    .help(
                        videoAttachment.videoCompressionPreset != nil
                            ? "This video has already been compressed."
                            : "Compress this video."
                    )

                    Button("Remove Video", systemImage: "trash", role: .destructive, action: removeAction)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(isCompressing)
                }
            }

            if isCompressing {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: compressionProgress, total: 1)
                        .progressViewStyle(.linear)
                    HStack {
                        Text("Compressing video... \(Int((compressionProgress * 100).rounded()))%")
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
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
        .task(id: videoAttachment.created) {
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

    private var compressButtonDisabled: Bool {
        isCompressing
            || videoAttachment.videoCompressionPreset != nil
            || videoInfo == nil
            || availableCompressionOptions.isEmpty
    }

    @MainActor
    private func startCompression(using option: VideoCompressionJob.Option) {
        guard !isCompressing else {
            return
        }

        isShowingCompressionOptions = false
        isCompressing = true
        compressionProgress = 0

        compressionTask = Task { @MainActor in
            var preparedExport: VideoCompressionJob.PreparedExport?

            do {
                let job = VideoCompressionJob(sourceURL: videoAttachment.path, option: option)
                let export = try await job.prepareExport()
                preparedExport = export
                try Task.checkCancellation()
                activeExportSession = export.session
                startCompressionProgressTimer(for: export.session)

                try await VideoCompressionJob.export(export.session)

                guard !Task.isCancelled else {
                    export.cleanupTemporaryFiles()
                    resetCompressionState()
                    return
                }

                compressionProgress = 1

                _ = try videoAttachment.draft.replaceVideoAttachment(
                    videoAttachment,
                    withCompressedVideoAt: export.outputURL,
                    compressionPreset: option.id
                )
                export.cleanupTemporaryFiles()
                resetCompressionState()
            } catch is CancellationError {
                preparedExport?.cleanupTemporaryFiles()
                resetCompressionState()
            } catch {
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
            compressionProgress = min(max(Double(reference.session.progress), 0), 1)
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
        compressionTask = nil
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
