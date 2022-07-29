import SwiftUI
import AVKit

struct WriterVideoView: View {
    @ObservedObject var videoAttachment: Attachment

    var body: some View {
        HStack {
            VideoPlayer(player: AVPlayer(url: videoAttachment.path))
                .frame(height: 270)
        }
            .contextMenu {
                Button {
                    try? videoAttachment.draft.deleteAttachment(name: videoAttachment.name)
                } label: {
                    Text("Delete Video")
                }
            }
        Divider()
    }
}
