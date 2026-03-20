import SwiftUI
import UniformTypeIdentifiers

@MainActor
enum WriterPasteboardImporter {
    private struct ImportedAttachmentFile {
        let url: URL
        let attachmentType: AttachmentType
        let isTemporary: Bool
    }

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

    private static let supportedFilePasteboardTypes: [(type: NSPasteboard.PasteboardType, fileExtension: String)] = [
        (NSPasteboard.PasteboardType(UTType.pdf.identifier), "pdf")
    ]

    static var readablePasteboardTypes: [NSPasteboard.PasteboardType] {
        [.fileURL, NSPasteboard.PasteboardType(UTType.image.identifier)]
            + supportedImagePasteboardTypes.map(\.type)
            + supportedVideoPasteboardTypes.map(\.type)
            + supportedAudioPasteboardTypes.map(\.type)
            + supportedFilePasteboardTypes.map(\.type)
    }

    static func canImport(returnType: NSPasteboard.PasteboardType?) -> Bool {
        guard let returnType else { return true }
        return readablePasteboardTypes.contains(returnType)
    }

    static func importAttachments(
        from pasteboard: NSPasteboard,
        into draft: DraftModel,
        insertMarkdown: (String) -> Void,
        synchronizeContent: (() -> Void)? = nil
    ) throws -> Bool {
        let importedAttachments = try importedAttachmentFiles(from: pasteboard)
        guard !importedAttachments.isEmpty else {
            return false
        }

        defer {
            cleanupTemporaryFiles(importedAttachments)
        }

        try insertImportedAttachments(importedAttachments, into: draft, insertMarkdown: insertMarkdown)
        synchronizeContent?()
        try draft.save()
        try draft.renderPreview()
        return true
    }

    private static func insertImportedAttachments(
        _ importedAttachments: [ImportedAttachmentFile],
        into draft: DraftModel,
        insertMarkdown: (String) -> Void
    ) throws {
        guard resolveExclusiveAttachmentReplacement(
            in: importedAttachments,
            draft: draft,
            attachmentType: .video
        ) else {
            return
        }
        guard resolveExclusiveAttachmentReplacement(
            in: importedAttachments,
            draft: draft,
            attachmentType: .audio
        ) else {
            return
        }

        for exclusiveType in [AttachmentType.video, .audio] {
            if importedAttachments.contains(where: { $0.attachmentType == exclusiveType }),
               let existingAttachment = draft.attachments.first(where: { $0.type == exclusiveType }) {
                draft.deleteAttachment(name: existingAttachment.name)
            }
        }

        for importedAttachment in importedAttachments {
            let attachment = try draft.addAttachment(
                path: importedAttachment.url,
                type: importedAttachment.attachmentType
            )
            if let markdown = attachment.markdown {
                insertMarkdown(markdown)
            }
        }
    }

    private static func importedAttachmentFiles(from pasteboard: NSPasteboard) throws -> [ImportedAttachmentFile] {
        var attachments: [ImportedAttachmentFile] = []

        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for fileURL in fileURLs {
                guard let attachmentType = supportedAttachmentType(for: fileURL) else {
                    continue
                }
                attachments.append(
                    try makeTemporaryAttachmentFile(from: fileURL, attachmentType: attachmentType)
                )
            }
        }

        if let items = pasteboard.pasteboardItems {
            for item in items where !item.types.contains(.fileURL) {
                if let importedAttachment = try makeTemporaryAttachmentFile(from: item) {
                    attachments.append(importedAttachment)
                }
            }
        } else if attachments.isEmpty,
                  let fallbackAttachment = try makeTemporaryAttachmentFile(from: pasteboard) {
            attachments.append(fallbackAttachment)
        }

        return attachments
    }

    private static func supportedAttachmentType(for url: URL) -> AttachmentType? {
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
            if fileType.conforms(to: .pdf) {
                return .file
            }
        }

        let attachmentType = AttachmentType.from(url)
        switch attachmentType {
        case .image, .video, .audio:
            return attachmentType
        case .file:
            return url.pathExtension.lowercased() == "pdf" ? .file : nil
        }
    }

    private static func makeTemporaryAttachmentFile(
        from pasteboard: NSPasteboard
    ) throws -> ImportedAttachmentFile? {
        for supportedType in supportedImagePasteboardTypes {
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
        for supportedType in supportedVideoPasteboardTypes {
            if let data = pasteboard.data(forType: supportedType.type) {
                return try makeTemporaryAttachmentFile(
                    from: data,
                    attachmentType: .video,
                    fileExtension: supportedType.fileExtension
                )
            }
        }
        for supportedType in supportedAudioPasteboardTypes {
            if let data = pasteboard.data(forType: supportedType.type) {
                return try makeTemporaryAttachmentFile(
                    from: data,
                    attachmentType: .audio,
                    fileExtension: supportedType.fileExtension
                )
            }
        }
        for supportedType in supportedFilePasteboardTypes {
            if let data = pasteboard.data(forType: supportedType.type) {
                return try makeTemporaryAttachmentFile(
                    from: data,
                    attachmentType: .file,
                    fileExtension: supportedType.fileExtension
                )
            }
        }
        return nil
    }

    private static func makeTemporaryAttachmentFile(
        from pasteboardItem: NSPasteboardItem
    ) throws -> ImportedAttachmentFile? {
        for supportedType in supportedImagePasteboardTypes {
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
        for supportedType in supportedVideoPasteboardTypes {
            if let data = pasteboardItem.data(forType: supportedType.type) {
                return try makeTemporaryAttachmentFile(
                    from: data,
                    attachmentType: .video,
                    fileExtension: supportedType.fileExtension
                )
            }
        }
        for supportedType in supportedAudioPasteboardTypes {
            if let data = pasteboardItem.data(forType: supportedType.type) {
                return try makeTemporaryAttachmentFile(
                    from: data,
                    attachmentType: .audio,
                    fileExtension: supportedType.fileExtension
                )
            }
        }
        for supportedType in supportedFilePasteboardTypes {
            if let data = pasteboardItem.data(forType: supportedType.type) {
                return try makeTemporaryAttachmentFile(
                    from: data,
                    attachmentType: .file,
                    fileExtension: supportedType.fileExtension
                )
            }
        }
        return nil
    }

    private static func makeTemporaryAttachmentFile(
        from sourceURL: URL,
        attachmentType: AttachmentType
    ) throws -> ImportedAttachmentFile {
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
        return ImportedAttachmentFile(
            url: temporaryURL,
            attachmentType: attachmentType,
            isTemporary: true
        )
    }

    private static func makeTemporaryAttachmentFile(
        from data: Data,
        attachmentType: AttachmentType,
        fileExtension: String
    ) throws -> ImportedAttachmentFile {
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)
        try data.write(to: temporaryURL, options: .atomic)
        return ImportedAttachmentFile(
            url: temporaryURL,
            attachmentType: attachmentType,
            isTemporary: true
        )
    }

    private static func makeTemporaryPNGImageFile(
        from data: Data
    ) throws -> ImportedAttachmentFile? {
        guard let image = NSImage(data: data), let pngData = image.PNGData else {
            return nil
        }
        return try makeTemporaryAttachmentFile(
            from: pngData,
            attachmentType: .image,
            fileExtension: "png"
        )
    }

    private static func resolvedFileExtension(
        preferred: String,
        typeIdentifier: String?,
        attachmentType: AttachmentType
    ) -> String {
        if !preferred.isEmpty {
            return preferred.lowercased()
        }
        if let typeIdentifier,
           let matchedType = supportedPasteboardTypes(for: attachmentType)
               .first(where: { $0.type.rawValue == typeIdentifier }) {
            return matchedType.fileExtension
        }

        switch attachmentType {
        case .video:
            return "mov"
        case .audio:
            return "m4a"
        case .file:
            return "pdf"
        default:
            return "png"
        }
    }

    private static func supportedPasteboardTypes(
        for attachmentType: AttachmentType
    ) -> [(type: NSPasteboard.PasteboardType, fileExtension: String)] {
        switch attachmentType {
        case .image:
            return supportedImagePasteboardTypes
        case .video:
            return supportedVideoPasteboardTypes
        case .audio:
            return supportedAudioPasteboardTypes
        case .file:
            return supportedFilePasteboardTypes
        }
    }

    private static func resolveExclusiveAttachmentReplacement(
        in importedAttachments: [ImportedAttachmentFile],
        draft: DraftModel,
        attachmentType: AttachmentType
    ) -> Bool {
        let newAttachments = importedAttachments.filter { $0.attachmentType == attachmentType }
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

    private static func confirmExclusiveAttachmentReplacement(
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

    private static func attachmentDisplayName(for attachmentType: AttachmentType) -> String {
        switch attachmentType {
        case .video:
            return "Video"
        case .audio:
            return "Audio"
        case .file:
            return "Document"
        default:
            return "Attachment"
        }
    }

    private static func presentPasteAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private static func cleanupTemporaryFiles(_ importedAttachments: [ImportedAttachmentFile]) {
        for importedAttachment in importedAttachments where importedAttachment.isTemporary {
            try? FileManager.default.removeItem(at: importedAttachment.url)
        }
    }
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
            queue: nil
        ) { notification in
            guard let text = notification.object as? String else { return }
            textView.insertTextAtCursor(text: text)
        }
        NotificationCenter.default.addObserver(
            forName: .writerNotification(.removeText, for: draft),
            object: nil,
            queue: nil
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
    private let monoFont: NSFont

    var processedURLs: [URL] = []

    init(draft: DraftModel, frame: NSRect, textContainer: NSTextContainer) {
        self.draft = draft
        self.monoFont = NSFont(name: "Menlo", size: 14) ?? .monospacedSystemFont(ofSize: 14, weight: .regular)
        super.init(frame: frame, textContainer: textContainer)
        self.isAutomaticQuoteSubstitutionEnabled = false
        self.isAutomaticDashSubstitutionEnabled = false
        self.isAutomaticTextReplacementEnabled = false
        self.enabledTextCheckingTypes = 0
    }

    required init?(coder: NSCoder) {
        fatalError("WriterEditorTextView: required init?(coder: NSCoder) not implemented")
    }

    // Always enforce the mono font in typingAttributes so that all inserted
    // text (typing, IME, paste, programmatic) uses the correct font.
    override var typingAttributes: [NSAttributedString.Key: Any] {
        get {
            var attrs = super.typingAttributes
            attrs[.font] = monoFont
            return attrs
        }
        set {
            var attrs = newValue
            attrs[.font] = monoFont
            super.typingAttributes = attrs
        }
    }

    override func insertBacktab(_ sender: Any?) {
        guard let contentView = window?.contentView else { return }
        if let titleTextView = Self.findSubview(ofType: WriterTitleEditorTextView.self, in: contentView) {
            window?.makeFirstResponder(titleTextView)
        }
    }

    private static func findSubview<T: NSView>(ofType type: T.Type, in view: NSView) -> T? {
        if let match = view as? T { return match }
        for subview in view.subviews {
            if let found = findSubview(ofType: type, in: subview) { return found }
        }
        return nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }

    override func validRequestor(
        forSendType sendType: NSPasteboard.PasteboardType?,
        returnType: NSPasteboard.PasteboardType?
    ) -> Any? {
        if sendType == nil, WriterPasteboardImporter.canImport(returnType: returnType) {
            return self
        }
        return super.validRequestor(forSendType: sendType, returnType: returnType)
    }

    override var readablePasteboardTypes: [NSPasteboard.PasteboardType] {
        [.string] + WriterPasteboardImporter.readablePasteboardTypes
    }

    override var acceptableDragTypes: [NSPasteboard.PasteboardType] {
        [.fileURL]
    }

    override func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general
        do {
            if try importAttachments(from: pasteboard) {
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

    override func readSelection(from pboard: NSPasteboard) -> Bool {
        do {
            if try importAttachments(from: pboard) {
                return true
            }
        } catch {
            debugPrint("failed to read pasted selection into Writer: \(error)")
        }
        return super.readSelection(from: pboard)
    }

    override func readSelection(
        from pboard: NSPasteboard,
        type: NSPasteboard.PasteboardType
    ) -> Bool {
        do {
            if WriterPasteboardImporter.canImport(returnType: type),
               try importAttachments(from: pboard) {
                return true
            }
        } catch {
            debugPrint("failed to read pasted selection type into Writer: \(error)")
        }
        return super.readSelection(from: pboard, type: type)
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

    private func importAttachments(from pasteboard: NSPasteboard) throws -> Bool {
        try WriterPasteboardImporter.importAttachments(
            from: pasteboard,
            into: draft,
            insertMarkdown: { [weak self] markdown in
                guard let self else { return }
                var range = self.selectedRange()
                range.length = 0
                self.insertText(markdown, replacementRange: range)
            },
            synchronizeContent: { [weak self] in
                guard let self else { return }
                self.draft.content = self.string
            }
        )
    }

    // MARK: - List autocomplete on Enter

    override func insertNewline(_ sender: Any?) {
        let result = MarkdownListAutocomplete.evaluateBeforeNewline(
            text: self.string,
            cursorUTF16Offset: self.selectedRange().location
        )
        switch result {
        case .removeEmptyMarker(let range):
            insertText("", replacementRange: range)
        case .insertPrefix(let prefix, _):
            insertText("\n" + prefix, replacementRange: self.selectedRange())
        case .none:
            super.insertNewline(sender)
        }
    }
}
