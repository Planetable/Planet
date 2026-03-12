import SwiftUI
import UniformTypeIdentifiers

private struct WriterPastedAttachmentFile {
    let url: URL
    let attachmentType: AttachmentType
    let isTemporary: Bool
}

struct WriterTextView: NSViewRepresentable {
    @ObservedObject var draft: DraftModel
    @Binding var text: String
    @State var selectedRanges: [NSValue] = []

    // var font: NSFont? = .monospacedSystemFont(ofSize: 14, weight: .regular)
    // Use 14pt Menlo font as default font
    var font: NSFont? = NSFont(name: "Menlo", size: 14)

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> WriterCustomTextView {
        let textView = WriterCustomTextView(draft: draft, text: text, font: font)
        textView.delegate = context.coordinator
        NotificationCenter.default.addObserver(
            forName: .writerNotification(.insertText, for: draft),
            object: nil,
            queue: .main
        ) { notification in
            guard let text = notification.object as? String else { return }
            textView.insertTextAtCursor(text: text)
        }
        NotificationCenter.default.addObserver(
            forName: .writerNotification(.removeText, for: draft),
            object: nil,
            queue: .main
        ) { notification in
            guard let text = notification.object as? String else { return }
            textView.removeTargetText(text: text)
        }
        return textView
    }

    func updateNSView(_ nsView: WriterCustomTextView, context: Context) {
        nsView.updateText(text, preferredSelectedRanges: context.coordinator.selectedRanges)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: WriterTextView
        var selectedRanges: [NSValue] = []

        init(_ parent: WriterTextView) {
            self.parent = parent
        }

        func textDidBeginEditing(_ notification: Notification) {
            guard let textView = notification.object as? WriterEditorTextView else {
                return
            }
            parent.text = textView.string
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? WriterEditorTextView else {
                return
            }
            parent.text = textView.string
            parent.selectedRanges = textView.selectedRanges
            selectedRanges = textView.selectedRanges
        }

        func textDidEndEditing(_ notification: Notification) {
            guard let textView = notification.object as? WriterEditorTextView else {
                return
            }
            let textString = textView.string
            DispatchQueue.main.async {
                self.parent.text = textString
            }
        }
    }
}

class WriterCustomTextView: NSView {
    private lazy var scrollView: NSScrollView = {
        let s = NSScrollView()
        s.drawsBackground = true
        s.borderType = .noBorder
        s.hasVerticalScroller = true
        s.hasHorizontalRuler = false
        s.autoresizingMask = [.width, .height]
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private lazy var textView: WriterEditorTextView = {
        let contentSize = scrollView.contentSize
        let textStorage = NSTextStorage()

        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(containerSize: scrollView.frame.size)
        textContainer.widthTracksTextView = true
        textContainer.containerSize = NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude)

        layoutManager.addTextContainer(textContainer)

        let t = WriterEditorTextView(draft: draft, frame: .zero, textContainer: textContainer)
        t.autoresizingMask = .width
        t.textContainerInset = NSSize(width: 10, height: 10)
        t.backgroundColor = NSColor.clear
        t.delegate = self.delegate
        t.drawsBackground = true
        t.font = self.font
        t.string = self.text
        t.isEditable = true
        t.isHorizontallyResizable = false
        t.isVerticallyResizable = true
        t.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        t.minSize = NSSize(width: 0, height: contentSize.height)
        t.textColor = NSColor.labelColor
        t.isRichText = false
        t.usesFontPanel = false
        t.allowsUndo = true
        return t
    }()

    @ObservedObject var draft: DraftModel
    private var font: NSFont?
    unowned var delegate: NSTextViewDelegate?
    var text: String
    var selectedRanges: [NSValue] = []

    init(draft: DraftModel, text: String, font: NSFont?) {
        self.draft = draft
        self.font = font
        self.text = text
        super.init(frame: .zero)
        self.scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: nil, queue: .main) { [weak self] n in
            guard let scroller = self?.scrollView.verticalScroller else { return }
            if let currentScrollerOffset = self?.draft.scrollerOffset, currentScrollerOffset != scroller.floatValue {
                Task { @MainActor in
                    self?.draft.scrollerOffset = scroller.floatValue
                }
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("WriterCustomTextView: required init?(coder: NSCoder) not implemented")
    }

    override func viewWillDraw() {
        super.viewWillDraw()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor)
        ])
        scrollView.documentView = textView
    }

    func insertTextAtCursor(text: String) {
        var range = textView.selectedRanges.first?.rangeValue ?? NSRange(location: 0, length: 0)
        range.length = 0
        textView.insertText(text, replacementRange: range)
    }

    func updateText(_ text: String, preferredSelectedRanges: [NSValue]) {
        self.text = text
        guard textView.string != text else {
            return
        }

        let targetRanges = preferredSelectedRanges.compactMap { value -> NSValue? in
            let range = value.rangeValue
            guard range.location != NSNotFound,
                range.location + range.length <= (text as NSString).length
            else {
                return nil
            }
            return value
        }

        textView.string = text
        if targetRanges.isEmpty {
            let end = (text as NSString).length
            textView.setSelectedRange(NSRange(location: end, length: 0))
        } else {
            textView.selectedRanges = targetRanges
        }
    }

    func removeTargetText(text: String) {
        let text = textView.string.replacingOccurrences(of: text, with: "")
        textView.string = text
        // replacing string does not sync with draft content
        draft.content = text
    }
}

class WriterEditorTextView: NSTextView {
    @ObservedObject var draft: DraftModel

    private static let supportedImagePasteboardTypes: [(type: NSPasteboard.PasteboardType, fileExtension: String)] = [
        (NSPasteboard.PasteboardType(UTType.png.identifier), "png"),
        (NSPasteboard.PasteboardType(UTType.jpeg.identifier), "jpg"),
        (NSPasteboard.PasteboardType(UTType.gif.identifier), "gif"),
        (NSPasteboard.PasteboardType(UTType.tiff.identifier), "tiff"),
        (NSPasteboard.PasteboardType("public.heic"), "heic"),
        (NSPasteboard.PasteboardType("public.heif"), "heif"),
        (NSPasteboard.PasteboardType("public.webp"), "webp")
    ]
    private static let supportedVideoPasteboardTypes: [(type: NSPasteboard.PasteboardType, fileExtension: String)] = [
        (NSPasteboard.PasteboardType(UTType.mpeg4Movie.identifier), "mp4"),
        (NSPasteboard.PasteboardType(UTType.quickTimeMovie.identifier), "mov"),
        (NSPasteboard.PasteboardType(UTType.movie.identifier), "mov")
    ]
    private static let supportedAudioPasteboardTypes: [(type: NSPasteboard.PasteboardType, fileExtension: String)] = [
        (NSPasteboard.PasteboardType(UTType.mp3.identifier), "mp3"),
        (NSPasteboard.PasteboardType(UTType.mpeg4Audio.identifier), "m4a"),
        (NSPasteboard.PasteboardType(UTType.wav.identifier), "wav"),
        (NSPasteboard.PasteboardType(UTType.audio.identifier), "m4a")
    ]

    var processedURLs: [URL] = []

    init(draft: DraftModel, frame: NSRect, textContainer: NSTextContainer) {
        self.draft = draft
        super.init(frame: frame, textContainer: textContainer)
        self.isAutomaticQuoteSubstitutionEnabled = false
        self.isAutomaticDashSubstitutionEnabled = false
        self.isAutomaticTextReplacementEnabled = false
        self.enabledTextCheckingTypes = 0
    }

    required init?(coder: NSCoder) {
        fatalError("WriterEditorTextView: required init?(coder: NSCoder) not implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }

    override var readablePasteboardTypes: [NSPasteboard.PasteboardType] {
        [.string, .fileURL, NSPasteboard.PasteboardType(UTType.image.identifier)]
            + Self.supportedImagePasteboardTypes.map { $0.type }
            + Self.supportedVideoPasteboardTypes.map { $0.type }
            + Self.supportedAudioPasteboardTypes.map { $0.type }
    }

    override var acceptableDragTypes: [NSPasteboard.PasteboardType] {
        [.fileURL]
    }

    override func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general
        do {
            let pastedAttachments = try pastedAttachmentFiles(from: pasteboard)
            if !pastedAttachments.isEmpty {
                defer {
                    cleanupTemporaryFiles(pastedAttachments)
                }
                try insertPastedAttachments(pastedAttachments)
                return
            }
        } catch {
            debugPrint("failed to paste media into Writer: \(error)")
            return
        }
        if pasteboard.availableType(from: [.string]) != nil {
            super.paste(sender)
        }
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return true
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        if let pasteboardObjects = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], pasteboardObjects.count > 0 {
            processedURLs = pasteboardObjects
        } else if let pasteBoardItems = sender.draggingPasteboard.pasteboardItems {
            processedURLs = pasteBoardItems
                .compactMap { $0.propertyList(forType: .fileURL) as? String }
                .map { URL(fileURLWithPath: $0).standardized }
        }
        return .copy
    }

    override func concludeDragOperation(_ sender: (any NSDraggingInfo)?) {
        super.concludeDragOperation(sender)
        guard processedURLs.count > 0 else { return }
        let droppedURLs = processedURLs
        processedURLs = []
        Task { @MainActor in
            await WriterDragAndDrop.handleDroppedFiles(
                droppedURLs,
                for: draft,
                insertAttachmentMarkdown: true
            )
        }
    }

    // MARK: - Process enter / return key event

    override func keyDown(with event: NSEvent) {
        super.keyDown(with: event)
        switch event.keyCode {
            case 36, 76:
                do {
                    try processEnterOrReturnEvent()
                } catch {
                    debugPrint("failed to process enter / return event: \(error)")
                }
            default:
                break
        }
    }

    private func processEnterOrReturnEvent() throws {
        let selectedRange = self.selectedRange()
        let location = selectedRange.location - 1
        let content = NSString(string: self.string)
        let start = getLocationOfFirstNewline(fromString: content, beforeLocation: UInt(location))
        let end = UInt(location)
        let range = NSRange(location: Int(start), length: Int(end - start))
        let line = NSString(string: content.substring(with: range))
        let regex = try NSRegularExpression(pattern: "^(\\s*)((?:(?:\\*|\\+|-|)\\s+)?)((?:\\d+\\.\\s+)?)(\\S)?", options: .anchorsMatchLines)
        guard let result: NSTextCheckingResult = regex.firstMatch(in: line as String, range: NSRange(location: 0, length: line.length)) else { return }
        let indent = NSString(string: line.substring(with: result.range(at: 1)))
        let prefix = getPrefix(result: result, line: line, start: start, indent: indent, selectedRange: selectedRange, range: range)
        guard prefix != "" else { return }
        var targetRange = selectedRange
        targetRange.length = 0
        var extendedContent = NSString(format: "%@%@ ", indent, prefix)
        extendedContent = getExtendedContent(line: line, indent: indent, prefix: prefix, extendedContent: extendedContent, range: range)
        self.insertText(extendedContent, replacementRange: targetRange)
    }

    private func getLocationOfFirstNewline(fromString string: NSString, beforeLocation loc: UInt) -> UInt {
        var location: UInt = loc
        if location > string.length {
            location = UInt(string.length)
        }
        var start: UInt = 0
        string.getLineStart(&start, end: nil, contentsEnd: nil, for: NSRange(location: Int(location), length: 0))
        return start
    }

    private func getPrefix(result: NSTextCheckingResult, line: NSString, start: UInt, indent: NSString, selectedRange: NSRange, range: NSRange) -> NSString {
        var prefix: NSString = NSString(string: "")
        let isUnordered = result.range(at: 2).length != 0
        let isOrdered = result.range(at: 3).length != 0
        let isPreviousLineEmpty = result.range(at: 4).length == 0
        if isPreviousLineEmpty {
            var replaceRange = NSRange(location: NSNotFound, length: 0)
            if isUnordered {
                replaceRange = result.range(at: 2)
            } else if isOrdered {
                replaceRange = result.range(at: 3)
            }
            if replaceRange.length > 0 {
                replaceRange.location += Int(start)
                if indent != "" {
                    // keep sublevel indent after return.
                    var targetRange = selectedRange
                    targetRange.length = 0
                    self.insertText(indent, replacementRange: targetRange)
                }
                self.shouldChangeText(in: range, replacementString: nil)
                self.replaceCharacters(in: range, with: "")
            }
        } else if isUnordered {
            var theRange = result.range(at: 2)
            theRange.length -= 1
            prefix = NSString(string: line.substring(with: theRange))
        } else if isOrdered {
            var theRange = result.range(at: 3)
            theRange.length -= 1
            let capturedIndex = NSString(string: line.substring(with: theRange)).integerValue
            prefix = NSString(format: "%ld.", capturedIndex + 1)
        }
        return prefix
    }

    private func getExtendedContent(line: NSString, indent: NSString, prefix: NSString, extendedContent: NSString, range: NSRange) -> NSString {
        var extendedContent = extendedContent
        // Improvements for todo item in unordered list:
        // "- [ ] "
        // "- [x] "
        // "- [X] "
        if line.hasPrefix("- [ ] ") || line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ") {
            if line.length == "- [ ] ".count {
                extendedContent = NSString(format: "")
                self.replaceCharacters(in: range, with: "")
            } else {
                extendedContent = NSString(format: "%@%@ [ ] ", indent, prefix)
            }
        }
        return extendedContent
    }

    private func insertPastedAttachments(_ pastedAttachments: [WriterPastedAttachmentFile]) throws {
        guard resolveExclusiveAttachmentReplacement(in: pastedAttachments, attachmentType: .video) else {
            return
        }
        guard resolveExclusiveAttachmentReplacement(in: pastedAttachments, attachmentType: .audio) else {
            return
        }

        for exclusiveType in [AttachmentType.video, .audio] {
            if pastedAttachments.contains(where: { $0.attachmentType == exclusiveType }),
               let existingAttachment = draft.attachments.first(where: { $0.type == exclusiveType })
            {
                draft.deleteAttachment(name: existingAttachment.name)
            }
        }

        for pastedAttachment in pastedAttachments {
            let attachment = try draft.addAttachment(
                path: pastedAttachment.url,
                type: pastedAttachment.attachmentType
            )
            if let markdown = attachment.markdown {
                var range = selectedRange()
                range.length = 0
                insertText(markdown, replacementRange: range)
            }
        }
        draft.content = string
        try draft.save()
        try draft.renderPreview()
    }

    private func pastedAttachmentFiles(from pasteboard: NSPasteboard) throws -> [WriterPastedAttachmentFile] {
        var attachments: [WriterPastedAttachmentFile] = []

        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for fileURL in fileURLs {
                guard let attachmentType = supportedAttachmentType(for: fileURL) else {
                    continue
                }
                attachments.append(try makeTemporaryAttachmentFile(from: fileURL, attachmentType: attachmentType))
            }
        }

        if let items = pasteboard.pasteboardItems {
            for item in items where !item.types.contains(.fileURL) {
                if let pastedAttachment = try makeTemporaryAttachmentFile(from: item) {
                    attachments.append(pastedAttachment)
                }
            }
        } else if attachments.isEmpty, let fallbackAttachment = try makeTemporaryAttachmentFile(from: pasteboard) {
            attachments.append(fallbackAttachment)
        }

        return attachments
    }

    private func supportedAttachmentType(for url: URL) -> AttachmentType? {
        guard url.isFileURL else { return nil }
        if let fileType = UTType(filenameExtension: url.pathExtension.lowercased()) {
            if fileType.conforms(to: .image) {
                return .image
            }
            if fileType.conforms(to: .movie) || fileType.conforms(to: .video) {
                return .video
            }
            if fileType.conforms(to: .audio) {
                return .audio
            }
        }
        let attachmentType = AttachmentType.from(url)
        switch attachmentType {
        case .image, .video, .audio:
            return attachmentType
        default:
            return nil
        }
    }

    private func makeTemporaryAttachmentFile(from pasteboard: NSPasteboard) throws -> WriterPastedAttachmentFile? {
        for supportedType in Self.supportedImagePasteboardTypes {
            if let data = pasteboard.data(forType: supportedType.type) {
                return try makeTemporaryAttachmentFile(
                    from: data,
                    attachmentType: .image,
                    fileExtension: supportedType.fileExtension
                )
            }
        }
        if let data = pasteboard.data(forType: NSPasteboard.PasteboardType(UTType.image.identifier)) {
            return try makeTemporaryPNGImageFile(from: data)
        }
        for supportedType in Self.supportedVideoPasteboardTypes {
            if let data = pasteboard.data(forType: supportedType.type) {
                return try makeTemporaryAttachmentFile(
                    from: data,
                    attachmentType: .video,
                    fileExtension: supportedType.fileExtension
                )
            }
        }
        for supportedType in Self.supportedAudioPasteboardTypes {
            if let data = pasteboard.data(forType: supportedType.type) {
                return try makeTemporaryAttachmentFile(
                    from: data,
                    attachmentType: .audio,
                    fileExtension: supportedType.fileExtension
                )
            }
        }
        return nil
    }

    private func makeTemporaryAttachmentFile(from pasteboardItem: NSPasteboardItem) throws -> WriterPastedAttachmentFile? {
        for supportedType in Self.supportedImagePasteboardTypes {
            if let data = pasteboardItem.data(forType: supportedType.type) {
                return try makeTemporaryAttachmentFile(
                    from: data,
                    attachmentType: .image,
                    fileExtension: supportedType.fileExtension
                )
            }
        }
        if let data = pasteboardItem.data(forType: NSPasteboard.PasteboardType(UTType.image.identifier)) {
            return try makeTemporaryPNGImageFile(from: data)
        }
        for supportedType in Self.supportedVideoPasteboardTypes {
            if let data = pasteboardItem.data(forType: supportedType.type) {
                return try makeTemporaryAttachmentFile(
                    from: data,
                    attachmentType: .video,
                    fileExtension: supportedType.fileExtension
                )
            }
        }
        for supportedType in Self.supportedAudioPasteboardTypes {
            if let data = pasteboardItem.data(forType: supportedType.type) {
                return try makeTemporaryAttachmentFile(
                    from: data,
                    attachmentType: .audio,
                    fileExtension: supportedType.fileExtension
                )
            }
        }
        return nil
    }

    private func makeTemporaryAttachmentFile(
        from sourceURL: URL,
        attachmentType: AttachmentType
    ) throws -> WriterPastedAttachmentFile {
        let typeIdentifier = try? sourceURL.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier
        let fileExtension = resolvedFileExtension(
            preferred: sourceURL.pathExtension,
            typeIdentifier: typeIdentifier,
            attachmentType: attachmentType
        )
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)
        let accessedSecurityScope = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessedSecurityScope {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }
        try FileManager.default.copyItem(at: sourceURL, to: temporaryURL)
        return WriterPastedAttachmentFile(
            url: temporaryURL,
            attachmentType: attachmentType,
            isTemporary: true
        )
    }

    private func makeTemporaryAttachmentFile(
        from data: Data,
        attachmentType: AttachmentType,
        fileExtension: String
    ) throws -> WriterPastedAttachmentFile {
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)
        try data.write(to: temporaryURL, options: .atomic)
        return WriterPastedAttachmentFile(
            url: temporaryURL,
            attachmentType: attachmentType,
            isTemporary: true
        )
    }

    private func makeTemporaryPNGImageFile(from data: Data) throws -> WriterPastedAttachmentFile? {
        guard let image = NSImage(data: data), let pngData = image.PNGData else {
            return nil
        }
        return try makeTemporaryAttachmentFile(
            from: pngData,
            attachmentType: .image,
            fileExtension: "png"
        )
    }

    private func resolvedFileExtension(
        preferred: String,
        typeIdentifier: String?,
        attachmentType: AttachmentType
    ) -> String {
        if !preferred.isEmpty {
            return preferred.lowercased()
        }
        if let typeIdentifier,
           let matchedType = supportedPasteboardTypes(for: attachmentType).first(where: { $0.type.rawValue == typeIdentifier }) {
            return matchedType.fileExtension
        }
        switch attachmentType {
        case .video:
            return "mov"
        case .audio:
            return "m4a"
        default:
            return "png"
        }
    }

    private func supportedPasteboardTypes(
        for attachmentType: AttachmentType
    ) -> [(type: NSPasteboard.PasteboardType, fileExtension: String)] {
        switch attachmentType {
        case .image:
            return Self.supportedImagePasteboardTypes
        case .video:
            return Self.supportedVideoPasteboardTypes
        case .audio:
            return Self.supportedAudioPasteboardTypes
        default:
            return []
        }
    }

    private func resolveExclusiveAttachmentReplacement(
        in pastedAttachments: [WriterPastedAttachmentFile],
        attachmentType: AttachmentType
    ) -> Bool {
        let newAttachments = pastedAttachments.filter { $0.attachmentType == attachmentType }
        guard !newAttachments.isEmpty else { return true }
        if newAttachments.count > 1 {
            presentPasteAlert(
                title: "Failed to Paste \(attachmentDisplayName(for: attachmentType))",
                message: "Writer only supports one \(attachmentDisplayName(for: attachmentType).lowercased()) attachment. Paste a single \(attachmentDisplayName(for: attachmentType).lowercased()) at a time."
            )
            return false
        }
        guard let existingAttachment = draft.attachments.first(where: { $0.type == attachmentType }) else {
            return true
        }
        return confirmExclusiveAttachmentReplacement(
            attachmentType: attachmentType,
            existingAttachmentName: existingAttachment.name
        )
    }

    private func confirmExclusiveAttachmentReplacement(
        attachmentType: AttachmentType,
        existingAttachmentName: String
    ) -> Bool {
        let alert = NSAlert()
        let attachmentName = attachmentDisplayName(for: attachmentType)
        alert.messageText = "Replace Existing \(attachmentName)?"
        alert.informativeText =
            "This article already has a \(attachmentName.lowercased()) attachment (\(existingAttachmentName)). Replace it with the pasted \(attachmentName.lowercased())?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Replace")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func attachmentDisplayName(for attachmentType: AttachmentType) -> String {
        switch attachmentType {
        case .video:
            return "Video"
        case .audio:
            return "Audio"
        default:
            return "Attachment"
        }
    }

    private func presentPasteAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func cleanupTemporaryFiles(_ pastedAttachments: [WriterPastedAttachmentFile]) {
        for pastedAttachment in pastedAttachments where pastedAttachment.isTemporary {
            try? FileManager.default.removeItem(at: pastedAttachment.url)
        }
    }
}
