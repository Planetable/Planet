import SwiftUI
import WebKit
import UniformTypeIdentifiers

struct WriterView: View {
    @ObservedObject var draft: DraftModel
    @ObservedObject var viewModel: WriterViewModel
    @FocusState var focusTitle: Bool
    let dragAndDrop: WriterDragAndDrop

    init(draft: DraftModel, viewModel: WriterViewModel) {
        self.draft = draft
        self.viewModel = viewModel
        dragAndDrop = WriterDragAndDrop(draft: draft)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let videoPath = viewModel.videoPath {
                WriterVideoView(videoPath: videoPath)
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
                        try? draft.renderPreview()
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
                            AttachmentThumbnailView(attachment: attachment)
                        }
                    }
                }
                    .frame(height: 80)
                    .frame(maxWidth: .infinity)
                    .background(Color.secondary.opacity(0.03))
            }
        }
            .frame(minWidth: 640)
            .alert(
                "This article has no title. Please enter the title before clicking send.",
                isPresented: $viewModel.isShowingEmptyTitleAlert
            ) {
                Button("OK", role: .cancel) { }
            }
            .onChange(of: draft.title) { _ in
                try? draft.save()
            }
            .onChange(of: draft.content) { _ in
                try? draft.save()
            }
            .onChange(of: draft.attachments) { _ in
                if let attachment = draft.attachments.first(where: { $0.type == .video }) {
                    viewModel.videoPath = attachment.path
                } else {
                    viewModel.videoPath = nil
                }
                if !draft.attachments.isEmpty {
                    viewModel.isMediaTrayOpen = true
                }
            }
            .onAppear {
                if let attachment = draft.attachments.first(where: { $0.type == .video }) {
                    viewModel.videoPath = attachment.path
                } else {
                    viewModel.videoPath = nil
                }
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
                        _ = try? draft.addAttachment(path: url, type: viewModel.attachmentType)
                    }
                    try? draft.save()
                }
            }
            .onDrop(of: [.fileURL], delegate: dragAndDrop)
    }
}
