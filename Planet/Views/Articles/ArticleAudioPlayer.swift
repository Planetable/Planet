import SwiftUI

@MainActor class ArticleAudioPlayerViewModel: ObservableObject {
    static let shared = ArticleAudioPlayerViewModel()

    @Published var url: URL?
    @Published var title = ""
}

struct ArticleAudioPlayer: View {
    @ObservedObject var viewModel = ArticleAudioPlayerViewModel.shared

    var body: some View {
        if let url = viewModel.url {
            HStack {
                AudioPlayer(url: url, title: viewModel.title, isPlaying: true)
                Button {
                    viewModel.url = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                    .buttonStyle(.borderless)
                    .frame(width: 24, height: 24)
            }
                .frame(height: 34)
                .padding(.horizontal, 16)
        }
    }
}
