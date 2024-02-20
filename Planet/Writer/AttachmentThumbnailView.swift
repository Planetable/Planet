import SwiftUI

struct AttachmentThumbnailView: View {
    @ObservedObject var attachment: Attachment

    @State private var isShowingControl = false
    @State private var hoverWindow: NSWindow?

    var body: some View {
        ZStack {
            if let thumbnail = attachment.thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(.vertical, 4)
                    .frame(width: 64, height: 64, alignment: .center)
            }

            if attachment.type == .image || attachment.type == .file {
                ZStack {
                    Rectangle()
                        .foregroundColor(Color("SelectedFillColor"))
                        .cornerRadius(4)
                        .opacity(isShowingControl ? 0.4 : 0.0)
                    HStack {
                        Image(systemName: "plus")
                            .resizable()
                            .foregroundColor(Color.secondary)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24, alignment: .center)
                            .opacity(isShowingControl ? 1.0 : 0.0)
                    }
                }
                .padding(4)
                .onTapGesture {
                    insertAttachment()
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
                            deleteAttachment()
                        }
                }
                Spacer()
            }
            .padding(.leading, 0)
            .padding(.top, 2)
            .padding(.trailing, 0)
        }
        .frame(width: 60, height: 60, alignment: .center)
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .onHover { hovering in
            withAnimation {
                isShowingControl = hovering
            }
            guard attachment.type == .image else { return }
            previewAttachment(onHovering: hovering)
        }
    }

    func insertAttachment() {
        if let markdown = attachment.markdown {
            NotificationCenter.default.post(
                name: .writerNotification(.insertText, for: attachment.draft),
                object: markdown
            )
        }
    }

    func deleteAttachment() {
        if let markdown = attachment.markdown {
            NotificationCenter.default.post(
                name: .writerNotification(.removeText, for: attachment.draft),
                object: markdown
            )
        }
        attachment.draft.deleteAttachment(name: attachment.name)
    }

    func previewAttachment(onHovering hovering: Bool) {
        if hovering {
            let hoverView = Text("Hovering Image: \(attachment.name)")
                .frame(width: 200, height: 100)
                .background(Color.gray.opacity(0.5))

            let controller = NSHostingController(rootView: hoverView)
            let window = NSWindow(contentViewController: controller)
            window.styleMask = .borderless
            window.backgroundColor = NSColor.clear
            window.isOpaque = false
            window.hasShadow = false
            window.ignoresMouseEvents = true

            let mouseLocation = NSEvent.mouseLocation
            window.setFrameOrigin(NSPoint(x: mouseLocation.x + 100, y: mouseLocation.y))

            window.makeKeyAndOrderFront(nil)
            self.hoverWindow = window
        } else {
            self.hoverWindow?.close()
            self.hoverWindow = nil
        }
    }
}
