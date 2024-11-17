import AVFoundation
import SwiftUI

struct AudioPlayer: View {
    @State var url: URL
    @State var title: String
    @State var isPlaying = false

    let player: AVPlayer

    init(url: URL, title: String, isPlaying: Bool = false) {
        _url = State(initialValue: url)
        _title = State(initialValue: title)
        _isPlaying = State(initialValue: isPlaying)
        player = AVPlayer(url: url)
        if isPlaying {
            player.play()
        }
    }

    var body: some View {
        HStack {
            Button {
                let current = player.currentTime()
                let target = current.seconds - 10
                player.seek(to: CMTime(seconds: target, preferredTimescale: current.timescale))
            } label: {
                Image(systemName: "gobackward.10")
            }
                .frame(width: 24, height: 24)
                .buttonStyle(.borderless)

            if isPlaying {
                Button {
                    player.pause()
                    isPlaying = false
                } label: {
                    Image(systemName: "pause.fill")
                }
                    .frame(width: 24, height: 24)
                    .buttonStyle(.borderless)
            } else {
                Button {
                    player.play()
                    isPlaying = true
                } label: {
                    Image(systemName: "play.fill")
                }
                    .frame(width: 24, height: 24)
                    .buttonStyle(.borderless)
            }

            Button {
                let current = player.currentTime()
                let target = current.seconds + 10
                player.seek(to: CMTime(seconds: target, preferredTimescale: current.timescale))
            } label: {
                Image(systemName: "goforward.10")
            }
                .frame(width: 24, height: 24)
                .buttonStyle(.borderless)

            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
        }.onDisappear {
            player.pause()
        }
    }
}
