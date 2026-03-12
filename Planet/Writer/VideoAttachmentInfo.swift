import AVFoundation
import Foundation

struct VideoAttachmentInfo {
    let duration: String
    let resolution: String
    let codec: String
    let bitrate: String
    let frameRate: String
    let fileSize: String

    static func load(from url: URL) async -> Self {
        let asset = AVURLAsset(url: url)
        let durationSeconds = await durationSeconds(for: asset)
        let videoTrack = await firstVideoTrack(for: asset)
        let fileSizeBytes = fileSizeBytes(for: url)
        let resolutionText = await resolution(for: videoTrack)
        let trackBitrate = await trackBitrate(for: videoTrack)
        let trackFrameRate = await trackFrameRate(for: videoTrack)
        let durationText: String = formattedDuration(durationSeconds)
        let codecText: String = await codecName(for: videoTrack) ?? "Unknown"
        let bitrateText: String = formattedBitrate(
            trackBitrate: trackBitrate,
            fileSizeBytes: fileSizeBytes,
            durationSeconds: durationSeconds
        )
        let frameRateText: String = formattedFrameRate(trackFrameRate)
        let fileSizeText: String = formattedFileSize(fileSizeBytes)

        return VideoAttachmentInfo(
            duration: durationText,
            resolution: resolutionText,
            codec: codecText,
            bitrate: bitrateText,
            frameRate: frameRateText,
            fileSize: fileSizeText
        )
    }

    private static func durationSeconds(for asset: AVAsset) async -> Double? {
        guard let duration = try? await asset.load(.duration) else {
            return nil
        }

        let seconds = CMTimeGetSeconds(duration)
        guard seconds.isFinite, seconds > 0 else {
            return nil
        }
        return seconds
    }

    private static func firstVideoTrack(for asset: AVAsset) async -> AVAssetTrack? {
        try? await asset.loadTracks(withMediaType: .video).first
    }

    private static func fileSizeBytes(for url: URL) -> Int64? {
        guard let fileSize = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
            return nil
        }
        return Int64(fileSize)
    }

    private static func resolution(for track: AVAssetTrack?) async -> String {
        guard let track,
              let naturalSize = try? await track.load(.naturalSize)
        else {
            return "Unknown"
        }

        let preferredTransform = (try? await track.load(.preferredTransform)) ?? .identity
        let transformedSize = naturalSize.applying(preferredTransform)
        let width = Int(abs(transformedSize.width).rounded())
        let height = Int(abs(transformedSize.height).rounded())
        guard width > 0, height > 0 else {
            return "Unknown"
        }

        return "\(width)x\(height)"
    }

    private static func formattedDuration(_ durationSeconds: Double?) -> String {
        guard let durationSeconds else {
            return "Unknown"
        }

        let totalSeconds = Int(durationSeconds.rounded())
        if totalSeconds >= 3600 {
            let hours = totalSeconds / 3600
            let minutes = (totalSeconds % 3600) / 60
            let seconds = totalSeconds % 60
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            let minutes = totalSeconds / 60
            let seconds = totalSeconds % 60
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    private static func trackBitrate(for track: AVAssetTrack?) async -> Double? {
        guard let track,
              let bitrate = try? await track.load(.estimatedDataRate),
              bitrate > 0
        else {
            return nil
        }

        return Double(bitrate)
    }

    private static func trackFrameRate(for track: AVAssetTrack?) async -> Float? {
        guard let track,
              let frameRate = try? await track.load(.nominalFrameRate),
              frameRate > 0
        else {
            return nil
        }

        return frameRate
    }

    private static func codecName(for track: AVAssetTrack?) async -> String? {
        guard let track,
              let formatDescriptions = try? await track.load(.formatDescriptions),
              let firstFormatDescription = formatDescriptions.first
        else {
            return nil
        }

        let mediaSubType = CMFormatDescriptionGetMediaSubType(firstFormatDescription)
        let fourCC = fourCCString(mediaSubType)

        switch fourCC {
        case "av01":
            return "AV1"
        case "avc1":
            return "H.264"
        case "hev1", "hvc1":
            return "HEVC"
        case "jpeg":
            return "JPEG"
        case "mp4v":
            return "MPEG-4"
        case "vp09":
            return "VP9"
        case "ap4h":
            return "ProRes 4444"
        case "ap4x":
            return "ProRes 4444 XQ"
        case "apch":
            return "ProRes 422 HQ"
        case "apcn":
            return "ProRes 422"
        case "apco":
            return "ProRes 422 Proxy"
        case "apcs":
            return "ProRes 422 LT"
        default:
            return fourCC.isEmpty ? nil : fourCC.uppercased()
        }
    }

    private static func formattedBitrate(
        trackBitrate: Double?,
        fileSizeBytes: Int64?,
        durationSeconds: Double?
    ) -> String {
        let bitsPerSecond =
            trackBitrate.flatMap { $0 > 0 ? $0 : nil }
            ?? averageBitrate(fileSizeBytes: fileSizeBytes, durationSeconds: durationSeconds)

        guard let bitsPerSecond else {
            return "Unknown"
        }

        if bitsPerSecond >= 1_000_000_000 {
            return String(format: "%.2f Gbps", bitsPerSecond / 1_000_000_000)
        } else if bitsPerSecond >= 1_000_000 {
            return String(format: "%.1f Mbps", bitsPerSecond / 1_000_000)
        } else if bitsPerSecond >= 1_000 {
            return String(format: "%.0f Kbps", bitsPerSecond / 1_000)
        } else {
            return "\(Int(bitsPerSecond.rounded())) bps"
        }
    }

    private static func averageBitrate(
        fileSizeBytes: Int64?,
        durationSeconds: Double?
    ) -> Double? {
        guard
            let fileSizeBytes,
            let durationSeconds,
            durationSeconds > 0
        else {
            return nil
        }

        return Double(fileSizeBytes * 8) / durationSeconds
    }

    private static func formattedFrameRate(_ frameRate: Float?) -> String {
        guard let frameRate, frameRate > 0 else {
            return "Unknown"
        }

        let roundedFrameRate = frameRate.rounded()
        if abs(frameRate - roundedFrameRate) < 0.05 {
            return String(format: "%.0f fps", roundedFrameRate)
        } else {
            return String(format: "%.2f fps", frameRate)
        }
    }

    private static func formattedFileSize(_ fileSizeBytes: Int64?) -> String {
        guard let fileSizeBytes else {
            return "Unknown"
        }

        return ByteCountFormatter.string(fromByteCount: fileSizeBytes, countStyle: .file)
    }

    private static func fourCCString(_ value: FourCharCode) -> String {
        let bytes: [UInt8] = [
            UInt8(truncatingIfNeeded: value >> 24),
            UInt8(truncatingIfNeeded: value >> 16),
            UInt8(truncatingIfNeeded: value >> 8),
            UInt8(truncatingIfNeeded: value),
        ]

        return String(bytes: bytes, encoding: .ascii)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
