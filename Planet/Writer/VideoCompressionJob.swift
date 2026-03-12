@preconcurrency import AVFoundation
import Foundation

private struct ExportSessionReference: @unchecked Sendable {
    let session: AVAssetExportSession
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
        let asset = AVURLAsset(url: sourceURL)
        guard let session = AVAssetExportSession(asset: asset, presetName: option.exportPresetName) else {
            throw CompressionError.exportSessionUnavailable
        }

        let outputFileType = try preferredOutputFileType(for: session)
        let outputURL = try makeOutputURL(for: outputFileType)
        session.outputURL = outputURL
        session.outputFileType = outputFileType
        session.shouldOptimizeForNetworkUse = true
        session.videoComposition = try await makeVideoComposition(for: asset)

        return PreparedExport(session: session, outputURL: outputURL)
    }

    static func export(_ session: AVAssetExportSession) async throws {
        let reference = ExportSessionReference(session: session)
        try await withCheckedThrowingContinuation { continuation in
            reference.session.exportAsynchronously {
                switch reference.session.status {
                case .completed:
                    continuation.resume()
                case .cancelled:
                    continuation.resume(throwing: CancellationError())
                case .failed:
                    continuation.resume(
                        throwing: reference.session.error
                        ?? CompressionError.exportFailed(nil)
                    )
                default:
                    continuation.resume(
                        throwing: reference.session.error
                        ?? CompressionError.exportFailed(nil)
                    )
                }
            }
        }
    }

    private func makeVideoComposition(for asset: AVAsset) async throws -> AVMutableVideoComposition {
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw CompressionError.invalidVideoTrack
        }

        let formatDescriptions = try await videoTrack.load(.formatDescriptions)
        let sourceColorProperties = SourceColorProperties(
            track: videoTrack,
            formatDescriptions: formatDescriptions
        )
        if sourceColorProperties.containsHDR && !option.usesHEVC {
            throw CompressionError.hdrRequiresHEVC
        }

        let duration = try await asset.load(.duration)
        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let sourceBounds = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
        let sourceSize = CGSize(width: abs(sourceBounds.width), height: abs(sourceBounds.height))
        guard sourceSize.width > 0, sourceSize.height > 0 else {
            throw CompressionError.invalidVideoTrack
        }

        let renderSize = option.renderSize(for: sourceSize)
        let frameRate = (try? await videoTrack.load(.nominalFrameRate)) ?? 0

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(
            value: 1,
            timescale: max(1, Int32(frameRate.rounded()))
        )
        sourceColorProperties.apply(to: videoComposition)

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        layerInstruction.setTransform(
            scaledTransform(
                naturalSize: naturalSize,
                preferredTransform: preferredTransform,
                renderSize: renderSize
            ),
            at: .zero
        )

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]
        return videoComposition
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

        if let outputFileType = preferredTypes.first(where: session.supportedFileTypes.contains) {
            return outputFileType
        }
        if let outputFileType = session.supportedFileTypes.first {
            return outputFileType
        }
        throw CompressionError.outputFileTypeUnavailable
    }

    private func makeOutputURL(for fileType: AVFileType) throws -> URL {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )

        let fileName = sourceURL.deletingPathExtension().lastPathComponent
        return temporaryDirectory
            .appendingPathComponent(fileName, isDirectory: false)
            .appendingPathExtension(fileExtension(for: fileType))
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
