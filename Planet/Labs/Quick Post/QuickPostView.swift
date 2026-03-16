//
//  QuickPostView.swift
//  Planet
//
//  Created by Xin Liu on 4/23/24.
//

import SwiftUI

struct QuickPostView: View {
    @StateObject private var viewModel: QuickPostViewModel
    @Environment(\.dismiss) private var dismiss
    init() {
        _viewModel = StateObject(wrappedValue: QuickPostViewModel.shared)
    }

    private var textAreaHeight: CGFloat {
        let font = NSFont(name: "Menlo", size: 14.0) ?? NSFont.systemFont(ofSize: 14.0)
        let lineHeight = ceil(font.ascender - font.descender + font.leading) + 4 // 4 = lineSpacing
        let insets: CGFloat = 8 // textContainerInset.height * 2
        let padding: CGFloat = 20 // SwiftUI top + bottom padding
        let minHeight = lineHeight * 5 + insets + padding
        let maxHeight = lineHeight * 12 + insets + padding
        let needed = viewModel.textContentHeight + padding
        return max(minHeight, min(maxHeight, needed))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Upper: Avatar | Text Entry
            HStack {
                VStack {
                    if let planet = KeyboardShortcutHelper.shared.activeMyPlanet {
                        planet.avatarView(size: 40)
                            .help(planet.name)
                    }
                    Spacer()
                }
                .frame(width: 40)
                .padding(.top, 10)
                .padding(.bottom, 10)
                .padding(.leading, 10)
                .padding(.trailing, 0)

                QuickPostTextView(
                    text: $viewModel.content,
                    viewModel: viewModel,
                    font: NSFont(name: "Menlo", size: 14.0)
                )
                    .padding(.top, 10)
                    .padding(.bottom, 10)
                    .padding(.leading, 0)
                    .padding(.trailing, 10)
                    .frame(height: textAreaHeight)
            }
            .background(Color(NSColor.textBackgroundColor))

            if viewModel.fileURLs.count > 0 {
                Divider()
                mediaTray()
            }

            if let audioURL = viewModel.audioURL {
                Divider()
                AudioPlayer(url: audioURL, title: audioURL.lastPathComponent)
            }

            Divider()

            HStack {
                Button {
                    do {
                        viewModel.allowedContentTypes = [.image, .heic, .heif]
                        viewModel.allowMultipleSelection = true
                        try attach(.image)
                    }
                    catch {
                        debugPrint("failed to add image to Quick Post: \(error)")
                    }
                } label: {
                    Image(systemName: "photo")
                }
                Button {
                    do {
                        viewModel.allowedContentTypes = [.movie]
                        viewModel.allowMultipleSelection = false
                        try attach(.video)
                    }
                    catch {
                        debugPrint("failed to add movie to Quick Post: \(error)")
                    }
                } label: {
                    if #available(macOS 14.0, *) {
                        Image(systemName: "movieclapper")
                    } else {
                        Image(systemName: "film")
                    }
                }
                Button {
                    do {
                        viewModel.allowedContentTypes = [.mp3, .mpeg4Audio, .wav]
                        viewModel.allowMultipleSelection = false
                        try attach(.audio)
                    }
                    catch {
                        debugPrint("failed to add audio to Quick Post: \(error)")
                    }
                } label: {
                    Image(systemName: "waveform")
                }
                Spacer()
                Button(role: .cancel) {
                    if viewModel.hasContent {
                        viewModel.showDiscardAlert = true
                    } else {
                        viewModel.cleanup()
                        dismiss()
                    }
                } label: {
                    Text("Cancel")
                        .frame(minWidth: 50)
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle)

                Button {
                    // Save content as a new MyArticleModel
                    do {
                        try saveContent()
                    }
                    catch {
                        debugPrint("Failed to save quick post")
                    }
                    dismiss()
                } label: {
                    Text("Post")
                    .frame(minWidth: 50)
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle)
            }.padding(10)
                .background(Color(NSColor.windowBackgroundColor))
        }.frame(width: 500, height: sheetHeight())
        .alert("Discard Post?", isPresented: $viewModel.showDiscardAlert) {
            Button("Discard", role: .destructive) {
                viewModel.cleanup()
                dismiss()
            }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("Your post will be lost if you discard it.")
        }
    }

    private func sheetHeight() -> CGFloat {
        if viewModel.fileURLs.count > 0 {
            if let _ = viewModel.audioURL {
                return textAreaHeight + 175
            }
            return textAreaHeight + 150
        }
        return textAreaHeight + 40
    }

    @ViewBuilder
    private func mediaTray() -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                ForEach(viewModel.fileURLs, id: \.self) { url in
                    mediaItem(for: url)
                }
            }
        }
        .frame(height: 110)
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.03))
    }

    @ViewBuilder
    private func mediaItem(for url: URL) -> some View {
        VStack(spacing: 0) {
            Image(nsImage: url.asNSImage)
                .interpolation(.high)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                .frame(width: 100, height: 80)
            Text(url.lastPathComponent)
                .font(.caption)
                .lineLimit(1)
                .frame(width: 100, height: 20)
                .truncationMode(.tail)
        }
        .padding(5)
        .background(Color.secondary.opacity(0.05))
        .onTapGesture {
            // Insert media reference at cursor position
            let _ = url.lastPathComponent
            let mediaReference = url.htmlCode

            // Get current cursor position
            let currentContent = viewModel.content
            if let textView = NSApp.keyWindow?.firstResponder as? NSTextView {
                let selectedRange = textView.selectedRange()
                let prefix = String(currentContent.prefix(selectedRange.location))
                let suffix = String(currentContent.suffix(from: currentContent.index(currentContent.startIndex, offsetBy: selectedRange.location)))
                viewModel.content = prefix + mediaReference + suffix
            }
        }
        .contextMenu {
            Button {
                viewModel.removeFile(url)
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }

    private func extractTitle(from content: String) -> String {
        let content = content.trim()
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            if line.hasPrefix("# ") {
                return line.replacingOccurrences(of: "# ", with: "")
            }
        }
        return ""
    }

    private func extractContent(from content: String) -> String {
        let content = content.trim()
        let lines = content.components(separatedBy: .newlines)
        var result = ""
        var i = 0
        for line in lines {
            if i == 0 {
                if line.hasPrefix("# ") {
                    i += 1
                    continue
                }
                else {
                    result += "\(line)\n"
                }
            }
            else {
                result += "\(line)\n"
            }
            i += 1
        }
        return result.trim()
    }

    private func attach(_ type: AttachmentType = .file) throws {
        let panel = NSOpenPanel()
        panel.message = "Add Attachments"
        panel.prompt = "Add"
        panel.allowedContentTypes = viewModel.allowedContentTypes
        panel.allowsMultipleSelection = viewModel.allowMultipleSelection
        panel.canChooseDirectories = false
        panel.showsHiddenFiles = false
        let response = panel.runModal()
        guard response == .OK, panel.urls.count > 0 else { return }
        try viewModel.addFilesFromOpenPanel(panel.urls, type: type)
    }

    private func saveContent() throws {
        defer {
            viewModel.cleanup()
        }
        // Save content as a new MyArticleModel
        guard let planet = KeyboardShortcutHelper.shared.activeMyPlanet else { return }
        let date = Date()
        let content = viewModel.content.trim()
        let article: MyArticleModel = try MyArticleModel.compose(
            link: nil,
            date: date,
            title: extractTitle(from: content),
            content: extractContent(from: content),
            summary: nil,
            planet: planet
        )
        if viewModel.fileURLs.count > 0 {
            var attachments: [String] = []
            for url in viewModel.fileURLs {
                // Copy the file to MyArticleModel's publicBasePath
                let fileName = url.lastPathComponent
                let targetURL = article.publicBasePath.appendingPathComponent(fileName)
                try FileManager.default.copyItem(at: url, to: targetURL)
                attachments.append(fileName)
            }
            article.attachments = attachments
            if viewModel.audioURL != nil {
                article.audioFilename = viewModel.audioURL?.lastPathComponent
            }
            if viewModel.videoURL != nil {
                article.videoFilename = viewModel.videoURL?.lastPathComponent
            }
        } else {
            // No attachments
            article.attachments = []
        }
        // TODO: Support tags in Quick Post
        article.tags = [:]
        var articles = planet.articles
        articles?.append(article)
        articles?.sort(by: { MyArticleModel.reorder(a: $0, b: $1) })
        planet.articles = articles

        do {
            try article.save()
            try article.savePublic()
            try planet.copyTemplateAssets()
            planet.updated = Date()
            try planet.save()

            Task(priority: .userInitiated) {
                try await planet.savePublic()
                try await planet.publish()
                Task(priority: .background) {
                    await article.prewarm()
                }
            }

            Task { @MainActor in
                PlanetStore.shared.selectedView = .myPlanet(planet)
                PlanetStore.shared.refreshSelectedArticles()
                // wrap it to delay the state change
                if planet.templateName == "Croptop" {
                    Task { @MainActor in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            // Croptop needs a delay here when it loads from the local gateway
                            if PlanetStore.shared.selectedArticle == article {
                                NotificationCenter.default.post(name: .loadArticle, object: nil)
                            }
                            else {
                                PlanetStore.shared.selectedArticle = article
                            }
                            Task(priority: .userInitiated) {
                                NotificationCenter.default.post(
                                    name: .scrollToArticle,
                                    object: article
                                )
                            }
                        }
                    }
                }
                else {
                    Task { @MainActor in
                        if PlanetStore.shared.selectedArticle == article {
                            NotificationCenter.default.post(name: .loadArticle, object: nil)
                        }
                        else {
                            PlanetStore.shared.selectedArticle = article
                        }
                        Task(priority: .userInitiated) {
                            NotificationCenter.default.post(name: .scrollToArticle, object: article)
                        }
                    }
                }
            }
        }
        catch {
            debugPrint("Failed to save quick post")
        }
    }
}

struct QuickPostTextView: NSViewRepresentable {
    @Binding var text: String
    @ObservedObject var viewModel: QuickPostViewModel
    var font: NSFont? = NSFont(name: "Menlo", size: 14)

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> QuickPostTextEditorContainer {
        let textView = QuickPostTextEditorContainer(text: text, viewModel: viewModel, font: font)
        textView.delegate = context.coordinator
        return textView
    }

    func updateNSView(_ nsView: QuickPostTextEditorContainer, context: Context) {
        nsView.updateText(text)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: QuickPostTextView

        init(_ parent: QuickPostTextView) {
            self.parent = parent
        }

        func textDidBeginEditing(_ notification: Notification) {
            guard let textView = notification.object as? QuickPostEditorTextView else {
                return
            }
            // Skip binding update during IME composition to avoid destroying marked text
            guard !textView.hasMarkedText() else { return }
            parent.text = textView.string
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? QuickPostEditorTextView else {
                return
            }
            // During IME composition (marked text), only update content height
            // but do NOT push text back to the binding — that triggers updateNSView
            // which calls textView.string = text, destroying the composing session
            if textView.hasMarkedText() {
                updateContentHeight(textView)
                return
            }
            parent.text = textView.string
            updateContentHeight(textView)
        }

        private func updateContentHeight(_ textView: NSTextView) {
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return }
            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            parent.viewModel.textContentHeight = usedRect.height + textView.textContainerInset.height * 2
        }

        func textDidEndEditing(_ notification: Notification) {
            guard let textView = notification.object as? QuickPostEditorTextView else {
                return
            }
            parent.text = textView.string
        }
    }
}

final class QuickPostTextEditorContainer: NSView {
    private lazy var scrollView: NSScrollView = {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = true
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalRuler = false
        scrollView.autoresizingMask = [.width, .height]
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()

    private lazy var textView: QuickPostEditorTextView = {
        let contentSize = scrollView.contentSize
        let textStorage = NSTextStorage()

        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(containerSize: scrollView.frame.size)
        textContainer.widthTracksTextView = true
        textContainer.containerSize = NSSize(
            width: contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )

        layoutManager.addTextContainer(textContainer)

        let textView = QuickPostEditorTextView(
            viewModel: viewModel,
            frame: .zero,
            textContainer: textContainer
        )
        textView.autoresizingMask = .width
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.backgroundColor = NSColor.clear
        textView.drawsBackground = true
        textView.font = font
        textView.string = text
        textView.isEditable = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.minSize = NSSize(width: 0, height: contentSize.height)
        textView.textColor = NSColor.labelColor
        textView.isRichText = false
        textView.usesFontPanel = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.enabledTextCheckingTypes = 0

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        textView.defaultParagraphStyle = paragraphStyle
        textView.typingAttributes[.paragraphStyle] = paragraphStyle
        return textView
    }()

    private let viewModel: QuickPostViewModel
    private let font: NSFont?
    private var text: String
    unowned var delegate: NSTextViewDelegate?

    init(text: String, viewModel: QuickPostViewModel, font: NSFont?) {
        self.text = text
        self.viewModel = viewModel
        self.font = font
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("QuickPostTextEditorContainer: required init?(coder:) not implemented")
    }

    override func viewWillDraw() {
        super.viewWillDraw()
        guard scrollView.superview == nil else { return }
        addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor)
        ])
        textView.delegate = delegate
        scrollView.documentView = textView
    }

    func updateText(_ text: String) {
        self.text = text
        // Never overwrite the text view while the IME is composing (marked text active)
        // — doing so destroys the composing session and causes garbled input
        guard !textView.hasMarkedText() else { return }
        guard textView.string != text else { return }
        textView.string = text
        let end = (text as NSString).length
        textView.setSelectedRange(NSRange(location: end, length: 0))
        updateContentHeight()
    }

    private func updateContentHeight() {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }
        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)
        viewModel.textContentHeight = usedRect.height + textView.textContainerInset.height * 2
    }
}

final class QuickPostEditorTextView: NSTextView {
    @ObservedObject private var viewModel: QuickPostViewModel

    init(viewModel: QuickPostViewModel, frame: NSRect, textContainer: NSTextContainer?) {
        self.viewModel = viewModel
        super.init(frame: frame, textContainer: textContainer)
    }

    required init?(coder: NSCoder) {
        fatalError("QuickPostEditorTextView: required init?(coder:) not implemented")
    }

    override func paste(_ sender: Any?) {
        if viewModel.processMediaPasteIfAvailable() {
            return
        }
        super.paste(sender)
    }

    // MARK: - List autocomplete on Enter

    override func keyDown(with event: NSEvent) {
        super.keyDown(with: event)
        switch event.keyCode {
        case 36, 76: // Return, Enter
            let result = MarkdownListAutocomplete.evaluate(
                text: self.string, cursorUTF16Offset: self.selectedRange().location
            )
            MarkdownListAutocomplete.apply(result, to: self)
        default:
            break
        }
    }
}

#Preview {
    QuickPostView()
}
