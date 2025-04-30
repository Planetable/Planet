import SwiftUI
import UniformTypeIdentifiers
import WebKit

enum LeftView {
    case markdown
    case prompt
}

enum RightView {
    case preview
    case llmOutput
}

struct WriterView: View {
    @ObservedObject var draft: DraftModel
    @ObservedObject var viewModel: WriterViewModel
    @FocusState var focusTitle: Bool
    let dragAndDrop: WriterDragAndDrop

    @State private var videoPlayerHeight: CGFloat = 0
    @State private var audioPlayerHeight: CGFloat = 0
    @State private var showTabs: Bool = false
    @State private var leftView: LeftView = .markdown
    @State private var rightView: RightView = .preview

    init(draft: DraftModel, viewModel: WriterViewModel) {
        self.draft = draft
        self.viewModel = viewModel
        dragAndDrop = WriterDragAndDrop(draft: draft)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let videoAttachment = draft.attachments.first(where: { $0.type == .video }) {
                WriterVideoView(videoAttachment: videoAttachment)
                    .onAppear {
                        self.videoPlayerHeight = 270
                    }
                    .onDisappear {
                        self.videoPlayerHeight = 0
                    }
            }
            if let audioAttachment = draft.attachments.first(where: { $0.type == .audio }) {
                WriterAudioView(audioAttachment: audioAttachment)
                    .onAppear {
                        self.audioPlayerHeight = 34
                    }
                    .onDisappear {
                        self.audioPlayerHeight = 0
                    }
            }

            WriterTitleView(
                availableTags: draft.planet.getAllAvailableTags(),
                tags: $draft.tags,
                date: $draft.date,
                title: $draft.title,
                focusTitle: _focusTitle,
                attachments: $draft.attachments
            )

            Divider()

            GeometryReader { geometry in
                HSplitView {
                    VStack(spacing: 0) {
                        if (showTabs) {
                            tabsLeft()
                        }
                        switch leftView {
                            case .markdown:
                                WriterTextView(draft: draft, text: $draft.content)
                                .frame(minWidth: geometry.size.width / 2, minHeight: 300)
                            case .prompt:
                                Text("Prompt Edit View")
                                .frame(minWidth: geometry.size.width / 2, maxHeight: .infinity)
                        }
                    }
                    VStack(spacing: 0) {
                        if (showTabs) {
                            tabsRight()
                        }
                        switch rightView {
                            case .preview:
                                WriterWebView(draft: draft)
                                .background(Color(NSColor.textBackgroundColor))
                                .frame(minWidth: geometry.size.width / 2, minHeight: 300)
                            case .llmOutput:
                                Text("LLM Output View")
                                .frame(minWidth: geometry.size.width / 2, maxHeight: .infinity)
                        }
                    }
                }
                .frame(minWidth: 640, minHeight: 300)
            }

            mediaTray()
        }
        .frame(minWidth: 640, minHeight: 520 + videoPlayerHeight + audioPlayerHeight)
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
        .onReceive(NotificationCenter.default.publisher(for: WriterViewModel.choosingAttachment), perform: { _ in
            do {
                try addAttachmentsAction()
            } catch {
                debugPrint("failed to add attachment: \(error)")
            }
        })
        .confirmationDialog(
            Text("Do you want to save your changes as a draft?"),
            isPresented: $viewModel.isShowingDiscardConfirmation
        ) {
            Button {
                viewModel.madeDiscardChoice = true
                try? draft.save()
                Task { @MainActor in
                    WriterStore.shared.closeWriterWindow(byDraftID: self.draft.id)
                }
            } label: {
                Text("Save Draft")
            }
            Button(role: .destructive) {
                viewModel.madeDiscardChoice = true
                try? draft.delete()
                Task { @MainActor in
                    WriterStore.shared.closeWriterWindow(byDraftID: self.draft.id)
                }
            } label: {
                Text("Delete Draft")
            }
        }
    }

    @ViewBuilder
    private func tabsLeft() -> some View {
        VStack(spacing: 0) {
            HStack {
                HStack {
                    HStack {
                        Text("Markdown")
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 6)
                    .background(leftView == .markdown ? Color(NSColor.textBackgroundColor) : Color.clear)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        leftView = .markdown
                    }

                    HStack {
                        Text("Prompt")
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 6)
                    .background(leftView == .prompt ? Color(NSColor.textBackgroundColor) : Color.clear)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        leftView = .prompt
                    }
                }
            }
            Divider()
        }
    }

    @ViewBuilder
    private func tabsRight() -> some View {
        VStack(spacing: 0) {
            HStack {
                HStack {
                    HStack {
                        Text("Preview")
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 6)
                    .background(rightView == .preview ? Color(NSColor.textBackgroundColor) : Color.clear)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        rightView = .preview
                    }

                    HStack {
                        Text("LLM Output")
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 6)
                    .background(rightView == .llmOutput ? Color(NSColor.textBackgroundColor) : Color.clear)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        rightView = .llmOutput
                    }
                }
            }
            Divider()
        }
    }

    @ViewBuilder
    private func mediaTray() -> some View {
        if viewModel.isMediaTrayOpen {
            Divider()
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(
                        draft.attachments.filter {
                            $0.type == .image || $0.type == .audio || $0.type == .file
                        },
                        id: \.name
                    ) { attachment in
                        AttachmentThumbnailView(attachment: attachment)
                            .overlay(
                                VStack {
                                    Spacer()
                                    Text("Hero Image")
                                        .foregroundColor(.white)
                                        .font(.system(size: 8))
                                        .padding(.vertical, 1)
                                        .padding(.horizontal, 3)
                                        .background(Color.black.opacity(0.5))
                                        .cornerRadius(4)
                                        .opacity(
                                            attachment.type == .image
                                                && attachment.name == draft.heroImage ? 1 : 0
                                        )
                                }
                            )
                            .help(attachment.name)
                            .contextMenu {
                                if attachment.type == .image {
                                    if attachment.name != draft.heroImage {
                                        Button {
                                            draft.heroImage = attachment.name
                                        } label: {
                                            Text("Set as Hero Image")
                                        }
                                    }
                                    else {
                                        Button {
                                            draft.heroImage = nil
                                        } label: {
                                            Text("Unset Hero Image")
                                        }
                                    }
                                    Divider()
                                }
                                Button {
                                    if let markdown = attachment.markdown {
                                        NotificationCenter.default.post(
                                            name: .writerNotification(
                                                .removeText,
                                                for: attachment.draft
                                            ),
                                            object: markdown
                                        )
                                    }
                                    attachment.draft.deleteAttachment(name: attachment.name)
                                } label: {
                                    Text("Remove")
                                }
                            }
                    }
                }
            }
            .frame(height: 80)
            .frame(maxWidth: .infinity)
            .background(Color.secondary.opacity(0.03))
            .onDrop(of: [.fileURL], delegate: dragAndDrop)
        }
    }

    private func addAttachmentsAction() throws {
        let panel = NSOpenPanel()
        panel.message = "Choose Attachments"
        panel.prompt = "Choose"
        panel.allowsMultipleSelection = viewModel.allowMultipleSelection
        panel.allowedContentTypes = viewModel.allowedContentTypes
        panel.canChooseDirectories = false
        panel.showsHiddenFiles = false
        let response = panel.runModal()
        guard response == .OK, panel.urls.count > 0 else { return }
        let urls = panel.urls
        if viewModel.attachmentType == .image {
            viewModel.isMediaTrayOpen = true
        }
        try urls.forEach { url in
            _ = try draft.addAttachment(path: url, type: viewModel.attachmentType)
        }
        try draft.renderPreview()
        try draft.save()
    }
}
