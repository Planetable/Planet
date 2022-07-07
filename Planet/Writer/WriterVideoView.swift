import SwiftUI
import AVKit

struct WriterVideoView: View {
    @ObservedObject var videoAttachment: Attachment

    var body: some View {
        HStack {
            VideoPlayer(player: AVPlayer(url: videoAttachment.path))
                .frame(height: 360)
        }
        Divider()
    }
}
