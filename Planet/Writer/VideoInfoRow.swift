import SwiftUI

struct VideoInfoRow: View {
    let videoURL: URL
    let removeAction: () -> Void

    @State private var videoInfo: VideoAttachmentInfo?

    var body: some View {
        HStack(spacing: 12) {
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

            Button("Remove Video", systemImage: "trash", role: .destructive, action: removeAction)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
        .task(id: videoURL) {
            await loadVideoInfo()
        }
    }

    private var videoDetails: [(title: String, value: String)] {
        guard let videoInfo else {
            return [
                ("Length", "Loading..."),
                ("Resolution", "Loading..."),
                ("Codec", "Loading..."),
                ("Bitrate", "Loading..."),
                ("Frame Rate", "Loading..."),
                ("File Size", "Loading..."),
            ]
        }

        return [
            ("Length", videoInfo.duration),
            ("Resolution", videoInfo.resolution),
            ("Codec", videoInfo.codec),
            ("Bitrate", videoInfo.bitrate),
            ("Frame Rate", videoInfo.frameRate),
            ("File Size", videoInfo.fileSize),
        ]
    }

    @MainActor
    private func loadVideoInfo() async {
        let info = await VideoAttachmentInfo.load(from: videoURL)

        guard !Task.isCancelled else {
            return
        }

        videoInfo = info
    }
}
