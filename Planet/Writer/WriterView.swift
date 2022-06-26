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
    @State var isShowingEmptyTitleAlert = false
    @State var selectedRanges: [NSValue] = []
    @FocusState var focusTitle: Bool
    var videoPath: URL? {
        if let attachment = draft.attachments.first { $0.type == .video } {
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
                WriterTextView(draft: draft, text: $draft.content, selectedRanges: $selectedRanges)
                    .frame(minWidth: 200, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)
                    .onChange(of: draft.content) { newValue in
                        do {
                            try WriterStore.shared.renderPreview(for: draft)
                        } catch {
                            PlanetStore.shared.alert(title: "Failed to render preview")
                        }
                        // TODO: refresh
                    }
                if let newArticleDraft = draft as? NewArticleDraftModel {
                    WriterPreview(url: newArticleDraft.previewPath)
                        .frame(minWidth: 320, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)
                } else
                if let editArticleDraft = draft as? EditArticleDraftModel {
                    WriterPreview(url: editArticleDraft.previewPath)
                        .frame(minWidth: 320, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)
                }
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
                // TODO: notifications???
            .onAppear {
                if !draft.attachments.isEmpty {
                    viewModel.isMediaTrayOpen = true
                }
                Task { @MainActor in
                    // workaround: wrap in a task to delay focus the title a little
                    focusTitle = true
                }
            }
            .alert("This article has no title. Please enter the title before clicking send.", isPresented: $isShowingEmptyTitleAlert) {
                Button("OK", role: .cancel) { }
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
                            try? newArticleDraft.save()
                        }
                    } else
                    if let editArticleDraft = draft as? EditArticleDraftModel {
                        urls.forEach { url in
                            try? editArticleDraft.addAttachment(path: url, type: viewModel.attachmentType)
                            try? editArticleDraft.save()
                        }
                    }
                }
            }
            .onDrop(of: [.fileURL], delegate: dragAndDrop)
    }
}

class WriterViewModel: ObservableObject {
    static let imageTypes: [UTType] = [.png, .jpeg, .tiff]
    static let videoTypes: [UTType] = [.mpeg4Movie, .quickTimeMovie]

    @Published var attachmentType: AttachmentType = .file
    @Published var isChoosingAttachment = false
    @Published var allowedContentTypes = imageTypes
    @Published var allowMultipleSelection = false
    @Published var isMediaTrayOpen = false
}
