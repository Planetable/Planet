import SwiftUI

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
        nsView.text = text
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

    func removeTargetText(text: String) {
        let text = textView.string.replacingOccurrences(of: text, with: "")
        textView.string = text
        // replacing string does not sync with draft content
        draft.content = text
    }
}

class WriterEditorTextView: NSTextView {
    @ObservedObject var draft: DraftModel

    init(draft: DraftModel, frame: NSRect, textContainer: NSTextContainer) {
        self.draft = draft
        super.init(frame: frame, textContainer: textContainer)
        self.isAutomaticQuoteSubstitutionEnabled = false
        self.isAutomaticDashSubstitutionEnabled = false
        self.isAutomaticTextReplacementEnabled = false
        self.enabledTextCheckingTypes = 0
        self.registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        fatalError("WriterEditorTextView: required init?(coder: NSCoder) not implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }

    override var readablePasteboardTypes: [NSPasteboard.PasteboardType] {
        [.string]
    }

    override var acceptableDragTypes: [NSPasteboard.PasteboardType] {
        [.fileURL]
    }

    override func wantsPeriodicDraggingUpdates() -> Bool {
        return false
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return true
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if sender.draggingPasteboard.types?.contains(.fileURL) == true {
            return .copy
        }
        return []
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        if sender.draggingPasteboard.types?.contains(.fileURL) == true {
            return .copy
        }
        return []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        super.draggingExited(sender)
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        super.draggingEnded(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        var processedURLs: [URL] = []
        if let pasteboardObjects = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], pasteboardObjects.count > 0 {
            processedURLs = pasteboardObjects
        } else if let pasteBoardItems = sender.draggingPasteboard.pasteboardItems {
            processedURLs = pasteBoardItems
                .compactMap { $0.propertyList(forType: .fileURL) as? String }
                .map { URL(fileURLWithPath: $0).standardized }
        } else {
            return false
        }
        if processedURLs.count > 0 {
            processedURLs.forEach { url in
                if let attachment = try? draft.addAttachment(path: url, type: AttachmentType.from(url)),
                   let markdown = attachment.markdown {
                    NotificationCenter.default.post(
                        name: .writerNotification(.insertText, for: attachment.draft),
                        object: markdown
                    )
                }
            }
            try? draft.save()
        }
        return true
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        super.concludeDragOperation(sender)
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
}
