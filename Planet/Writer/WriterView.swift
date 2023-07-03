import SwiftUI
import WebKit
import UniformTypeIdentifiers

struct WriterView: View {
    @ObservedObject var draft: DraftModel
    @ObservedObject var viewModel: WriterViewModel
    @FocusState var focusTitle: Bool
    let dragAndDrop: WriterDragAndDrop
    
    @State private var videoPlayerHeight: CGFloat = 0
    @State private var audioPlayerHeight: CGFloat = 0

    init(draft: DraftModel, viewModel: WriterViewModel) {
        self.draft = draft
        self.viewModel = viewModel
        dragAndDrop = WriterDragAndDrop(draft: draft)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let videoAttachment = draft.attachments.first(where: {$0.type == .video}) {
                WriterVideoView(videoAttachment: videoAttachment)
                    .onAppear {
                        self.videoPlayerHeight = 270
                    }
                    .onDisappear {
                        self.videoPlayerHeight = 0
                    }
            }
            if let audioAttachment = draft.attachments.first(where: {$0.type == .audio}) {
                WriterAudioView(audioAttachment: audioAttachment)
                    .onAppear {
                        self.audioPlayerHeight = 34
                    }
                    .onDisappear {
                        self.audioPlayerHeight = 0
                    }
            }

            WriterTitleView(date: $draft.date, title: $draft.title, focusTitle: _focusTitle)

            Divider()

            GeometryReader { geometry in
                HSplitView {
                    WriterTextView(draft: draft, text: $draft.content)
                        .frame(minWidth: geometry.size.width / 2, minHeight: 300)
                    WriterWebView(draft: draft)
                        .background(Color(NSColor.textBackgroundColor))
                        .frame(minWidth: geometry.size.width / 2, minHeight: 300)
                }
                .frame(minWidth: 640, minHeight: 300)
            }

            if viewModel.isMediaTrayOpen {
                Divider()
                ScrollView(.horizontal) {
                    HStack(spacing: 0) {
                        ForEach(
                            draft.attachments.filter { $0.type == .image || $0.type == .audio || $0.type == .file },
                            id: \.name
                        ) { attachment in
                            AttachmentThumbnailView(attachment: attachment)
                        }
                    }
                }
                .frame(height: 80)
                .frame(maxWidth: .infinity)
                .background(Color.secondary.opacity(0.03))
                .onDrop(of: [.fileURL], delegate: dragAndDrop)
            }
        }
        .frame(minWidth: 640, minHeight: 440 + videoPlayerHeight + audioPlayerHeight)
            .alert(
                "This article has no title. Please enter the title before clicking send.",
                isPresented: $viewModel.isShowingEmptyTitleAlert
            ) {
                Button("OK", role: .cancel) { }
            }
            .onChange(of: draft.date) { _ in
                try? draft.save()
            }
            .onChange(of: draft.title) { _ in
                try? draft.save()
            }
            .onChange(of: draft.content) { _ in
                try? draft.save()
                try? draft.renderPreview()
            }
            .onChange(of: draft.attachments) { _ in
                if draft.attachments.contains(where: { $0.type == .image || $0.type == .file }) {
                    viewModel.isMediaTrayOpen = true
                }
                try? draft.renderPreview()
            }
            .onAppear {
                if draft.attachments.contains(where: { $0.type == .image || $0.type == .file }) {
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
                    if viewModel.attachmentType == .image {
                        viewModel.isMediaTrayOpen = true
                    }
                    urls.forEach { url in
                        _ = try? draft.addAttachment(path: url, type: viewModel.attachmentType)
                    }
                    try? draft.renderPreview()
                    try? draft.save()
                }
            }
            .confirmationDialog(
                Text("Do you want to save your changes as a draft?"),
                isPresented: $viewModel.isShowingDiscardConfirmation
            ) {
                Button {
                    viewModel.madeDiscardChoice = true
                    try? draft.save()
                    NotificationCenter.default.post(
                        name: .writerNotification(.close, for: draft),
                        object: nil
                    )
                } label: {
                    Text("Save Draft")
                }
                Button(role: .destructive) {
                    viewModel.madeDiscardChoice = true
                    try? draft.delete()
                    NotificationCenter.default.post(
                        name: .writerNotification(.close, for: draft),
                        object: nil
                    )
                } label: {
                    Text("Delete Draft")
                }
            }
    }
}
