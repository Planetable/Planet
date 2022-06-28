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
    @State var lastRender = Date()
    @FocusState var focusTitle: Bool
    var videoPath: URL? {
        if let attachment = draft.attachments.first(where: { $0.type == .video }) {
            if let newArticleDraft = draft as? NewArticleDraftModel {
                return newArticleDraft.getAttachmentPath(name: attachment.name)
            } else
            if let editArticleDraft = draft as? EditArticleDraftModel {
                return editArticleDraft.getAttachmentPath(name: attachment.name)
            }
        }
        return nil
    }
    let dragAndDrop: WriterDragAndDrop

    init(draft: DraftModel, viewModel: WriterViewModel) {
        self.draft = draft
        dragAndDrop = WriterDragAndDrop(draft: draft)
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(spacing: 0) {
            if let videoPath = videoPath {
                HStack {
                    VideoPlayer(player: AVPlayer(url: videoPath))
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
                        NotificationCenter.default.post(name: .writerNotification(.reloadPage, for: draft), object: nil)
                    }
                WriterPreview(draft: draft, lastRender: lastRender)
            }

            if viewModel.isMediaTrayOpen {
                Divider()
                ScrollView(.horizontal) {
                    HStack(spacing: 0) {
                        ForEach(draft.attachments, id: \.name) { attachment in
                            DraftImageThumbnailView(draft: draft, attachment: attachment)
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
                try? save()
            }
            .onChange(of: draft.content) { _ in
                try? save()
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
                    if let newArticleDraft = draft as? NewArticleDraftModel {
                        urls.forEach { url in
                            try? newArticleDraft.addAttachment(path: url, type: viewModel.attachmentType)
                        }
                    } else
                    if let editArticleDraft = draft as? EditArticleDraftModel {
                        urls.forEach { url in
                            try? editArticleDraft.addAttachment(path: url, type: viewModel.attachmentType)
                        }
                    }
                    try? save()
                }
            }
            .onDrop(of: [.fileURL], delegate: dragAndDrop)
    }

    func save() throws {
        if let newArticleDraft = draft as? NewArticleDraftModel {
            try newArticleDraft.save()
        } else
        if let editArticleDraft = draft as? EditArticleDraftModel {
            try editArticleDraft.save()
        }
    }
}
