import SwiftUI
import AVKit

struct WriterVideoView: View {
    @ObservedObject var videoAttachment: Attachment
    @State private var player: AVPlayer?

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if let player {
                    VideoPlayer(player: player)
                } else {
                    Rectangle()
                        .foregroundStyle(Color(NSColor.controlBackgroundColor))
                }
            }
            .frame(height: 270)
            VideoInfoRow(
                videoAttachment: videoAttachment,
                removeAction: deleteVideo
            )
        }
        .task(id: videoAttachment.created) {
            await loadPlayer()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
        .contextMenu {
            Button("Delete Video", role: .destructive, action: deleteVideo)
        }
        Divider()
    }

    private func deleteVideo() {
        videoAttachment.draft.deleteAttachment(name: videoAttachment.name)
    }

    @MainActor
    private func loadPlayer() async {
        let url = videoAttachment.path
        let loadedPlayer = await Task.detached(priority: .userInitiated) {
            AVPlayer(url: url)
        }.value

        guard !Task.isCancelled else {
            loadedPlayer.pause()
            return
        }

        player?.pause()
        player = loadedPlayer
    }
}
