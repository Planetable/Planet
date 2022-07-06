import SwiftUI
import AVKit

struct WriterVideoView: View {
    @ObservedObject var viewModel: WriterViewModel

    var body: some View {
        if let videoPath = viewModel.videoPath {
            HStack {
                VideoPlayer(player: AVPlayer(url: videoPath))
                    .frame(height: 400)
            }
            Divider()
        }
    }
}
