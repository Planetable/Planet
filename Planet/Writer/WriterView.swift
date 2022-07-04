import SwiftUI
import AVKit
import Stencil
import PathKit
import WebKit
import Ink
import UniformTypeIdentifiers

struct WriterView: View {
    @ObservedObject var draft: DraftModel
    @ObservedObject var viewModel: WriterViewModel
    @FocusState var focusTitle: Bool
    let dragAndDrop: WriterDragAndDrop

    init(draft: DraftModel, viewModel: WriterViewModel) {
        self.draft = draft
        dragAndDrop = WriterDragAndDrop(draft: draft)
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.hasVideo, let aVideoPath = viewModel.videoPath {
                HStack {
                    VideoPlayer(player: AVPlayer(url: aVideoPath))
                        .frame(height: 400)
                }
                Divider()
            }
            TextField("Title", text: $draft.title)
                .frame(height: 34, alignment: .leading)
                .padding(.bottom, 2)
                .padding(.horizontal, 16)
                .font(.system(size: 15, weight: .regular, design: .default))
                .background(Color(NSColor.textBackgroundColor))
                .textFieldStyle(PlainTextFieldStyle())
                .focused($focusTitle)

            Divider()

            HSplitView {
                WriterTextView(draft: draft, text: $draft.content)
                    .frame(minWidth: 320, minHeight: 400)
                    .onChange(of: draft.content) { _ in
                        try? WriterStore.shared.renderPreview(for: draft)
                        NotificationCenter.default.post(
                            name: .writerNotification(.loadPreview, for: draft),
                            object: nil
                        )
                    }
                WriterPreview(draft: draft)
            }

            if viewModel.isMediaTrayOpen {
                Divider()
                ScrollView(.horizontal) {
                    HStack(spacing: 0) {
                        ForEach(draft.attachments, id: \.name) { attachment in
                            if attachment.status != .deleted {
                                AttachmentThumbnailView(attachment: attachment)
                            }
                        }
                    }
                }
                    .frame(height: 80)
                    .frame(maxWidth: .infinity)
                    .background(Color.secondary.opacity(0.03))
            }
        }
            .frame(minWidth: 640)
            .onChange(of: draft.title) { _ in
                try? draft.save()
            }
            .onChange(of: draft.content) { _ in
                try? draft.save()
            }
            .onChange(of: draft.attachments) { _ in
                if let attachment = draft.attachments.first(where: { $0.type == .video }) {
                    viewModel.hasVideo = true
                    viewModel.videoPath = attachment.path
                }
            }
            .onAppear {
                if !draft.attachments.isEmpty {
                    viewModel.isMediaTrayOpen = true
                }
                Task { @MainActor in
                    // workaround: wrap in a task to delay focusing the title a little
                    focusTitle = true
                }
            }
            .fileImporter(
                isPresented: $viewModel.isChoosingAttachment,
                allowedContentTypes: viewModel.allowedContentTypes,
                allowsMultipleSelection: viewModel.allowMultipleSelection
            ) { result in
                if let urls = try? result.get() {
                    viewModel.isMediaTrayOpen = true
                    urls.forEach { url in
                        try? draft.addAttachment(path: url, type: viewModel.attachmentType)
                    }
                    try? draft.save()
                }
            }
            .onDrop(of: [.fileURL], delegate: dragAndDrop)
    }
}
