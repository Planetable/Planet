import SwiftUI
import AVKit

struct WriterVideoView: View {
    @State var videoPath: URL

    var body: some View {
        HStack {
            VideoPlayer(player: AVPlayer(url: videoPath))
                .frame(minHeight: 270, maxHeight: 360)
                .aspectRatio(16 / 9, contentMode: .fit)
        }
        Divider()
    }
}
