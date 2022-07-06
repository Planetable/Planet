import SwiftUI
import AVKit

struct WriterVideoView: View {
    @State var videoPath: URL

    var body: some View {
        HStack {
            VideoPlayer(player: AVPlayer(url: videoPath))
                .frame(height: 400)
        }
        Divider()
    }
}
