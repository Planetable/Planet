import SwiftUI

struct DraftImageThumbnailView: View {
    @ObservedObject var draft: DraftModel
    @State var attachmentImage: NSImage?
    @State var attachment: Attachment

    @State private var isShowingPlusIcon = false

    var body: some View {
        ZStack {
            if let image = attachmentImage,
               let resizedImage = image.resizeSquare(maxLength: 60) {
                Image(nsImage: resizedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(.vertical, 4)
                    .frame(width: 60, height: 60, alignment: .center)
            }

            VStack {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18, alignment: .center)
                        .opacity(isShowingPlusIcon ? 1.0 : 0.0)
                }
            }
                .padding(4)
                .onTapGesture {
                    // TODO: missing insert file, need a way to get current selection
                }

            VStack {
                HStack {
                    Spacer()
                    Image(systemName: "xmark.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 12, height: 12, alignment: .center)
                        .opacity(isShowingPlusIcon ? 1.0 : 0.0)
                        .onTapGesture {
                            // TODO: delete attachment in draft
                        }
                }
                Spacer()
            }
                .padding(.leading, 0)
                .padding(.top, 2)
                .padding(.trailing, -8)
        }
            .frame(width: 60, height: 60, alignment: .center)
            .padding(.leading, 12)
            .padding(.trailing, 8)
            .onHover { isHovering in
                withAnimation {
                    isShowingPlusIcon = isHovering
                }
            }
            .onAppear {
                if let newArticleDraft = draft as? NewArticleDraftModel,
                   let path = newArticleDraft.getAttachmentPath(name: attachment.name) {
                    attachmentImage = NSImage(contentsOf: path)
                } else
                if let editArticleDraft = draft as? EditArticleDraftModel,
                   let path = editArticleDraft.getAttachmentPath(name: attachment.name) {
                    attachmentImage = NSImage(contentsOf: path)
                }
            }
    }
}
