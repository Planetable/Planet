import SwiftUI

struct WriterAudioView: View {
    @ObservedObject var audioAttachment: Attachment

    var body: some View {
        HStack {
            AudioPlayer(url: audioAttachment.path, title: audioAttachment.name)
            Button {
                try? audioAttachment.draft.deleteAttachment(name: audioAttachment.name)
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.borderless)
            .frame(width: 24, height: 24)
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        
        Divider()
    }
}
