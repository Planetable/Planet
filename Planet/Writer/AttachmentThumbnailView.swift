import SwiftUI

struct AttachmentThumbnailView: View {
    @ObservedObject var draft: DraftModel
    @State var attachmentImage: NSImage?
    @State var attachment: Attachment

    @State private var isShowingControl = false

    var body: some View {
        ZStack {
            if attachment.type == .image,
               let image = attachmentImage,
               let resizedImage = image.resizeSquare(maxLength: 60) {
                Image(nsImage: resizedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(.vertical, 4)
                    .frame(width: 60, height: 60, alignment: .center)
            }

            // TODO: when we have all types of thumbnails to show
            // switch attachment.type {
            // }

            if attachment.type == .image || attachment.type == .file {
                VStack {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 18, height: 18, alignment: .center)
                            .opacity(isShowingControl ? 1.0 : 0.0)
                    }
                }
                    .padding(4)
                    .onTapGesture {
                        if let attachmentMarkdown = getAttachmentMarkdown() {
                            NotificationCenter.default.post(
                                name: Notification.Name.writerNotification(.insertText, for: draft),
                                object: attachmentMarkdown
                            )
                        }
                    }
            }

            VStack {
                HStack {
                    Spacer()
                    Image(systemName: "xmark.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 12, height: 12, alignment: .center)
                        .opacity(isShowingControl ? 1.0 : 0.0)
                        .onTapGesture {
                            draft.deleteAttachment(name: attachment.name)
                        }
                }
                Spacer()
            }
                .padding(.leading, 0)
                .padding(.top, 2)
                .padding(.trailing, -10)
        }
            .frame(width: 60, height: 60, alignment: .center)
            .padding(.leading, 12)
            .padding(.trailing, 8)
            .onHover { isHovering in
                withAnimation {
                    isShowingControl = isHovering
                }
            }
            .onAppear {
                // TODO: respond to attachment changes under the same name
                if let path = attachment.path {
                    attachmentImage = NSImage(contentsOf: path)
                }
            }
    }

    func getAttachmentMarkdown() -> String? {
        switch attachment.type {
        case .image:
            return "![\(attachment.name)](\(attachment.name))"
        case .file:
            return "<a href=\"\(attachment.name)\">\(attachment.name)</a>"
        default:
            return nil
        }
    }
}
