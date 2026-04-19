@preconcurrency import AVFoundation
import Foundation

private struct ExportSessionReference: @unchecked Sendable {
    let session: AVAssetExportSession
}

private func videoCompressionFileSizeBytes(at url: URL) -> Int64? {
    guard let fileSize = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
        return nil
    }
    return Int64(fileSize)
}

private func videoCompressionFormatBytes(_ value: Int64?) -> String {
    guard let value else {
        return "nil"
    }
    return "\(value)"
}

private func videoCompressionFormatSeconds(_ time: CMTime) -> String {
    let seconds = CMTimeGetSeconds(time)
    guard seconds.isFinite else {
        return "indefinite"
    }
    return String(format: "%.3f", seconds)
}

private func videoCompressionFormatSize(_ size: CGSize) -> String {
    String(format: "%.0fx%.0f", size.width, size.height)
}

private func videoCompressionFormatTransform(_ transform: CGAffineTransform) -> String {
    String(
        format: "[a=%.3f,b=%.3f,c=%.3f,d=%.3f,tx=%.3f,ty=%.3f]",
        transform.a,
        transform.b,
        transform.c,
        transform.d,
        transform.tx,
        transform.ty
    )
}

private func videoCompressionFormatFileType(_ fileType: AVFileType?) -> String {
    fileType?.rawValue ?? "nil"
}

private func videoCompressionFormatString(_ value: String?) -> String {
    value ?? "nil"
}

private func videoCompressionFormatBitrate(_ value: Double?) -> String {
    guard let value, value > 0 else {
        return "nil"
    }
    if value >= 1_000_000 {
        return String(format: "%.3fMbps", value / 1_000_000)
    }
    if value >= 1_000 {
        return String(format: "%.1fKbps", value / 1_000)
    }
    return String(format: "%.0fbps", value)
}

private func videoCompressionFormatBitrate(_ value: Int64?) -> String {
    guard let value else {
        return "nil"
    }
    return videoCompressionFormatBitrate(Double(value))
}

private func videoCompressionDescribeError(_ error: Error) -> String {
    let nsError = error as NSError
    return "domain=\(nsError.domain) code=\(nsError.code) description=\(nsError.localizedDescription)"
}

struct VideoCompressionJob {
    private struct SourceColorProperties {
        let colorPrimaries: String?
        let colorTransferFunction: String?
        let colorYCbCrMatrix: String?
        let containsHDR: Bool

        init(track: AVAssetTrack, formatDescriptions: [CMFormatDescription]) {
            let extensions: NSDictionary? = formatDescriptions.first.flatMap { formatDescription in
                guard let rawExtensions = CMFormatDescriptionGetExtensions(formatDescription) else {
                    return nil
                }
                return rawExtensions as NSDictionary
            }

            colorPrimaries =
                extensions?[kCMFormatDescriptionExtension_ColorPrimaries as String] as? String
            colorTransferFunction =
                extensions?[kCMFormatDescriptionExtension_TransferFunction as String] as? String
            colorYCbCrMatrix =
                extensions?[kCMFormatDescriptionExtension_YCbCrMatrix as String] as? String
            containsHDR =
                track.hasMediaCharacteristic(.containsHDRVideo)
                || colorTransferFunction == AVVideoTransferFunction_SMPTE_ST_2084_PQ
                || colorTransferFunction == AVVideoTransferFunction_ITU_R_2100_HLG
        }

        func apply(to videoComposition: AVMutableVideoComposition) {
            videoComposition.colorPrimaries = colorPrimaries
            videoComposition.colorTransferFunction = colorTransferFunction
            videoComposition.colorYCbCrMatrix = colorYCbCrMatrix
        }

        var debugDescription: String {
            "containsHDR=\(containsHDR) colorPrimaries=\(videoCompressionFormatString(colorPrimaries)) colorTransferFunction=\(videoCompressionFormatString(colorTransferFunction)) colorYCbCrMatrix=\(videoCompressionFormatString(colorYCbCrMatrix))"
        }
    }

    enum Option: String, CaseIterable, Identifiable {
        case h264FitInside1080p
        case h264FitInside720p
        case h264FitInside480p
        case h265FitInside1080p
        case h265FitInside720p
        case h265FitInside480p

        var id: String {
            rawValue
        }

        var title: String {
            switch self {
            case .h264FitInside1080p:
                return "H264: Fit inside 1080P"
            case .h264FitInside720p:
                return "H264: Fit inside 720P"
            case .h264FitInside480p:
                return "H264: Fit inside 480P"
            case .h265FitInside1080p:
                return "HEVC: Fit inside 1080P"
            case .h265FitInside720p:
                return "HEVC: Fit inside 720P"
            case .h265FitInside480p:
                return "HEVC: Fit inside 480P"
            }
        }

        func isAvailable(forWidth width: Int, height: Int) -> Bool {
            let sourceEdges = [max(width, height), min(width, height)]
            let targetEdges = [
                Int(max(landscapeBoundingSize.width, landscapeBoundingSize.height)),
                Int(min(landscapeBoundingSize.width, landscapeBoundingSize.height)),
            ]
            return !(sourceEdges[0] < targetEdges[0] && sourceEdges[1] < targetEdges[1])
        }

        fileprivate var exportPresetName: String {
            usesHEVC ? AVAssetExportPresetHEVCHighestQuality : AVAssetExportPresetHighestQuality
        }

        fileprivate var targetVideoBitrate: Int64 {
            switch self {
            case .h264FitInside1080p, .h265FitInside1080p:
                return 7_000_000
            case .h264FitInside720p, .h265FitInside720p:
                return 4_000_000
            case .h264FitInside480p, .h265FitInside480p:
                return 2_000_000
            }
        }

        private static let containerOverheadMultiplier = 1.03
        private static let conservativeAudioBitrateBudget: Int64 = 192_000

        fileprivate var landscapeBoundingSize: CGSize {
            switch self {
            case .h264FitInside1080p, .h265FitInside1080p:
                return CGSize(width: 1920, height: 1080)
            case .h264FitInside720p, .h265FitInside720p:
                return CGSize(width: 1280, height: 720)
            case .h264FitInside480p, .h265FitInside480p:
                return CGSize(width: 640, height: 480)
            }
        }

        var usesHEVC: Bool {
            switch self {
            case .h265FitInside1080p, .h265FitInside720p, .h265FitInside480p:
                return true
            default:
                return false
            }
        }

        fileprivate func renderSize(for sourceSize: CGSize) -> CGSize {
            let boundingSize: CGSize = sourceSize.width >= sourceSize.height
                ? landscapeBoundingSize
                : CGSize(
                    width: landscapeBoundingSize.height,
                    height: landscapeBoundingSize.width
                )
            let scale = min(
                1,
                min(
                    boundingSize.width / sourceSize.width,
                    boundingSize.height / sourceSize.height
                )
            )
            return CGSize(
                width: evenDimension(sourceSize.width * scale),
                height: evenDimension(sourceSize.height * scale)
            )
        }

        private func evenDimension(_ value: CGFloat) -> CGFloat {
            let roundedDown = floor(value / 2) * 2
            return max(2, roundedDown)
        }

        fileprivate func audioBitrateBudget(sourceAudioBitrate: Double?) -> Int64 {
            let fallbackAudioBitrate: Int64 = 128_000
            guard let sourceAudioBitrate, sourceAudioBitrate > 0 else {
                return fallbackAudioBitrate
            }

            let rounded = Int64(sourceAudioBitrate.rounded())
            return min(max(rounded, 96_000), 192_000)
        }

        fileprivate func fileLengthLimit(
            duration: CMTime,
            sourceAudioBitrate: Double?
        ) -> Int64? {
            let durationSeconds = CMTimeGetSeconds(duration)
            guard durationSeconds.isFinite, durationSeconds > 0 else {
                return nil
            }

            let totalBitrate = targetVideoBitrate + audioBitrateBudget(
                sourceAudioBitrate: sourceAudioBitrate
            )
            return Int64(
                ceil(durationSeconds * Double(totalBitrate) / 8 * Self.containerOverheadMultiplier)
            )
        }

        func estimatedMultipassTemporaryCapacityBytes(
            durationSeconds: Double?,
            sourceFileSizeBytes: Int64?
        ) -> Int64? {
            let outputBudgetBytes = estimatedOutputBudgetBytes(durationSeconds: durationSeconds)
            let exportUnitBytes = [sourceFileSizeBytes, outputBudgetBytes]
                .compactMap { $0 }
                .max()

            guard let exportUnitBytes, exportUnitBytes > 0 else {
                return nil
            }

            let doubled = exportUnitBytes.multipliedReportingOverflow(by: 2)
            return doubled.overflow ? Int64.max : doubled.partialValue
        }

        private func estimatedOutputBudgetBytes(durationSeconds: Double?) -> Int64? {
            guard let durationSeconds, durationSeconds.isFinite, durationSeconds > 0 else {
                return nil
            }

            let totalBitrate = targetVideoBitrate + audioBitrateBudget(
                sourceAudioBitrate: Double(Self.conservativeAudioBitrateBudget)
            )
            return Int64(
                ceil(durationSeconds * Double(totalBitrate) / 8 * Self.containerOverheadMultiplier)
            )
        }

        var debugDescription: String {
            "id=\(id) title=\(title) preset=\(exportPresetName) usesHEVC=\(usesHEVC) boundingSize=\(videoCompressionFormatSize(landscapeBoundingSize)) targetVideoBitrate=\(videoCompressionFormatBitrate(targetVideoBitrate))"
        }
    }

    private struct PreparedVideoComposition {
        let composition: AVMutableVideoComposition
        let duration: CMTime
    }

    struct PreparedExport {
        let session: AVAssetExportSession
        let outputURL: URL

        func cleanupTemporaryFiles() {
            try? FileManager.default.removeItem(at: outputURL.deletingLastPathComponent())
        }
    }

    enum CompressionError: LocalizedError {
        case exportSessionUnavailable
        case invalidVideoTrack
        case hdrRequiresHEVC
        case outputFileTypeUnavailable
        case exportFailed(String?)

        var errorDescription: String? {
            switch self {
            case .exportSessionUnavailable:
                return "Planet could not create a video export session."
            case .invalidVideoTrack:
                return "Planet could not read the video track for this attachment."
            case .hdrRequiresHEVC:
                return "This video uses HDR. Choose an H265 preset to retain its color space."
            case .outputFileTypeUnavailable:
                return "Planet could not determine an output format for the compressed video."
            case .exportFailed(let message):
                return message ?? "Planet could not compress this video."
            }
        }
    }

    let sourceURL: URL
    let option: Option

    func prepareExport() async throws -> PreparedExport {
        VideoLogger.log(
            "[VideoCompressionJob] prepareExport start source=\(sourceURL.path) sourceSizeBytes=\(videoCompressionFormatBytes(videoCompressionFileSizeBytes(at: sourceURL))) option={\(option.debugDescription)}"
        )

        do {
            let asset = AVURLAsset(url: sourceURL)
            guard let session = AVAssetExportSession(asset: asset, presetName: option.exportPresetName) else {
                VideoLogger.log(
                    "[VideoCompressionJob] prepareExport could not create AVAssetExportSession source=\(sourceURL.path) preset=\(option.exportPresetName)"
                )
                throw CompressionError.exportSessionUnavailable
            }

            VideoLogger.log(
                "[VideoCompressionJob] export session created preset=\(option.exportPresetName) supportedFileTypes=\(session.supportedFileTypes.map(\.rawValue).joined(separator: ","))"
            )

            let outputFileType = try preferredOutputFileType(for: session)
            let outputURL = try makeOutputURL(for: outputFileType)
            session.outputURL = outputURL
            session.outputFileType = outputFileType
            session.shouldOptimizeForNetworkUse = true
            session.canPerformMultiplePassesOverSourceMediaData = true
            session.directoryForTemporaryFiles = FileManager.default.temporaryDirectory

            let preparedVideoComposition = try await makeVideoComposition(for: asset)
            session.videoComposition = preparedVideoComposition.composition

            let sourceAudioBitrate = await estimatedAudioBitrate(for: asset)
            let targetVideoBitrate = option.targetVideoBitrate
            let audioBitrateBudget = option.audioBitrateBudget(
                sourceAudioBitrate: sourceAudioBitrate
            )
            let fileLengthLimit = option.fileLengthLimit(
                duration: preparedVideoComposition.duration,
                sourceAudioBitrate: sourceAudioBitrate
            )
            if let fileLengthLimit {
                session.fileLengthLimit = fileLengthLimit
            }

            VideoLogger.log(
                "[VideoCompressionJob] configured bitrate budget targetVideoBitrate=\(videoCompressionFormatBitrate(targetVideoBitrate)) sourceAudioBitrate=\(videoCompressionFormatBitrate(sourceAudioBitrate)) audioBitrateBudget=\(videoCompressionFormatBitrate(audioBitrateBudget)) fileLengthLimitBytes=\(videoCompressionFormatBytes(fileLengthLimit)) multiplePasses=\(session.canPerformMultiplePassesOverSourceMediaData)"
            )

            VideoLogger.log(
                "[VideoCompressionJob] prepareExport ready outputURL=\(outputURL.path) outputFileType=\(outputFileType.rawValue) renderSize=\(videoCompressionFormatSize(session.videoComposition?.renderSize ?? .zero)) frameDurationSeconds=\(videoCompressionFormatSeconds(session.videoComposition?.frameDuration ?? .invalid)) optimizeForNetworkUse=\(session.shouldOptimizeForNetworkUse) fileLengthLimitBytes=\(videoCompressionFormatBytes(fileLengthLimit))"
            )

            return PreparedExport(session: session, outputURL: outputURL)
        } catch {
            VideoLogger.log(
                "[VideoCompressionJob] prepareExport failed source=\(sourceURL.path) option=\(option.id) error=\(videoCompressionDescribeError(error))"
            )
            throw error
        }
    }

    static func export(_ session: AVAssetExportSession) async throws {
        VideoLogger.log(
            "[VideoCompressionJob] export start outputURL=\(session.outputURL?.path ?? "nil") outputFileType=\(videoCompressionFormatFileType(session.outputFileType)) progress=\(String(format: "%.3f", session.progress))"
        )
        let reference = ExportSessionReference(session: session)
        try await withCheckedThrowingContinuation { continuation in
            reference.session.exportAsynchronously {
                switch reference.session.status {
                case .completed:
                    VideoLogger.log(
                        "[VideoCompressionJob] export completed outputURL=\(reference.session.outputURL?.path ?? "nil") progress=\(String(format: "%.3f", reference.session.progress))"
                    )
                    continuation.resume()
                case .cancelled:
                    VideoLogger.log(
                        "[VideoCompressionJob] export cancelled outputURL=\(reference.session.outputURL?.path ?? "nil") progress=\(String(format: "%.3f", reference.session.progress))"
                    )
                    continuation.resume(throwing: CancellationError())
                case .failed:
                    VideoLogger.log(
                        "[VideoCompressionJob] export failed outputURL=\(reference.session.outputURL?.path ?? "nil") progress=\(String(format: "%.3f", reference.session.progress)) error=\(videoCompressionDescribeError(reference.session.error ?? CompressionError.exportFailed(nil)))"
                    )
                    continuation.resume(
                        throwing: reference.session.error
                        ?? CompressionError.exportFailed(nil)
                    )
                default:
                    VideoLogger.log(
                        "[VideoCompressionJob] export ended unexpectedly status=\(reference.session.status.rawValue) outputURL=\(reference.session.outputURL?.path ?? "nil") progress=\(String(format: "%.3f", reference.session.progress)) error=\(videoCompressionDescribeError(reference.session.error ?? CompressionError.exportFailed(nil)))"
                    )
                    continuation.resume(
                        throwing: reference.session.error
                        ?? CompressionError.exportFailed(nil)
                    )
                }
            }
        }
    }

    private func makeVideoComposition(for asset: AVAsset) async throws -> PreparedVideoComposition {
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            VideoLogger.log(
                "[VideoCompressionJob] asset has no readable video track source=\(sourceURL.path)"
            )
            throw CompressionError.invalidVideoTrack
        }

        let formatDescriptions = try await videoTrack.load(.formatDescriptions)
        let sourceColorProperties = SourceColorProperties(
            track: videoTrack,
            formatDescriptions: formatDescriptions
        )
        if sourceColorProperties.containsHDR && !option.usesHEVC {
            VideoLogger.log(
                "[VideoCompressionJob] rejecting non-HEVC preset for HDR source source=\(sourceURL.path) option=\(option.id)"
            )
            throw CompressionError.hdrRequiresHEVC
        }

        let duration = try await asset.load(.duration)
        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let sourceBounds = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
        let sourceSize = CGSize(width: abs(sourceBounds.width), height: abs(sourceBounds.height))
        guard sourceSize.width > 0, sourceSize.height > 0 else {
            VideoLogger.log(
                "[VideoCompressionJob] invalid transformed video size source=\(sourceURL.path) naturalSize=\(videoCompressionFormatSize(naturalSize)) preferredTransform=\(videoCompressionFormatTransform(preferredTransform))"
            )
            throw CompressionError.invalidVideoTrack
        }

        let renderSize = option.renderSize(for: sourceSize)
        let frameRate = (try? await videoTrack.load(.nominalFrameRate)) ?? 0

        VideoLogger.log(
            "[VideoCompressionJob] source track details source=\(sourceURL.path) durationSeconds=\(videoCompressionFormatSeconds(duration)) naturalSize=\(videoCompressionFormatSize(naturalSize)) transformedSize=\(videoCompressionFormatSize(sourceSize)) nominalFrameRate=\(String(format: "%.3f", frameRate)) preferredTransform=\(videoCompressionFormatTransform(preferredTransform)) colorProperties={\(sourceColorProperties.debugDescription)} option=\(option.id)"
        )

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(
            value: 1,
            timescale: max(1, Int32(frameRate.rounded()))
        )
        sourceColorProperties.apply(to: videoComposition)

        let transform = scaledTransform(
            naturalSize: naturalSize,
            preferredTransform: preferredTransform,
            renderSize: renderSize
        )
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        layerInstruction.setTransform(
            transform,
            at: .zero
        )

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]
        VideoLogger.log(
            "[VideoCompressionJob] video composition prepared renderSize=\(videoCompressionFormatSize(renderSize)) frameDurationSeconds=\(videoCompressionFormatSeconds(videoComposition.frameDuration)) transform=\(videoCompressionFormatTransform(transform)) instructionDurationSeconds=\(videoCompressionFormatSeconds(duration))"
        )
        return PreparedVideoComposition(
            composition: videoComposition,
            duration: duration
        )
    }

    private func preferredOutputFileType(for session: AVAssetExportSession) throws -> AVFileType {
        let preferredTypes: [AVFileType]
        switch sourceURL.pathExtension.lowercased() {
        case "mp4":
            preferredTypes = [.mp4, .mov, .m4v]
        case "m4v":
            preferredTypes = [.m4v, .mp4, .mov]
        default:
            preferredTypes = [.mov, .mp4, .m4v]
        }

        VideoLogger.log(
            "[VideoCompressionJob] resolving output file type sourceExtension=\(sourceURL.pathExtension.lowercased()) preferredTypes=\(preferredTypes.map(\.rawValue).joined(separator: ",")) supportedFileTypes=\(session.supportedFileTypes.map(\.rawValue).joined(separator: ","))"
        )

        if let outputFileType = preferredTypes.first(where: session.supportedFileTypes.contains) {
            VideoLogger.log(
                "[VideoCompressionJob] selected output file type=\(outputFileType.rawValue)"
            )
            return outputFileType
        }
        if let outputFileType = session.supportedFileTypes.first {
            VideoLogger.log(
                "[VideoCompressionJob] selected fallback output file type=\(outputFileType.rawValue)"
            )
            return outputFileType
        }
        VideoLogger.log("[VideoCompressionJob] output file type unavailable")
        throw CompressionError.outputFileTypeUnavailable
    }

    private func makeOutputURL(for fileType: AVFileType) throws -> URL {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )

        let fileName = UUID().uuidString.lowercased()
        let outputURL = temporaryDirectory
            .appendingPathComponent(fileName, isDirectory: false)
            .appendingPathExtension(fileExtension(for: fileType))
        VideoLogger.log(
            "[VideoCompressionJob] created temporary export directory=\(temporaryDirectory.path) outputURL=\(outputURL.path)"
        )
        return outputURL
    }

    private func fileExtension(for fileType: AVFileType) -> String {
        switch fileType {
        case .mp4:
            return "mp4"
        case .m4v:
            return "m4v"
        default:
            return "mov"
        }
    }

    private func estimatedAudioBitrate(for asset: AVAsset) async -> Double? {
        guard let audioTrack = try? await asset.loadTracks(withMediaType: .audio).first,
              let estimatedDataRate = try? await audioTrack.load(.estimatedDataRate),
              estimatedDataRate > 0
        else {
            return nil
        }

        return Double(estimatedDataRate)
    }

    private func scaledTransform(
        naturalSize: CGSize,
        preferredTransform: CGAffineTransform,
        renderSize: CGSize
    ) -> CGAffineTransform {
        let transformedBounds = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
        let transformedSize = CGSize(
            width: abs(transformedBounds.width),
            height: abs(transformedBounds.height)
        )
        let scale = min(
            renderSize.width / transformedSize.width,
            renderSize.height / transformedSize.height
        )

        var transform = preferredTransform.concatenating(
            CGAffineTransform(scaleX: scale, y: scale)
        )
        let scaledBounds = CGRect(origin: .zero, size: naturalSize).applying(transform)
        transform = transform.concatenating(
            CGAffineTransform(
                translationX: ((renderSize.width - scaledBounds.width) / 2) - scaledBounds.minX,
                y: ((renderSize.height - scaledBounds.height) / 2) - scaledBounds.minY
            )
        )
        return transform
    }
}
