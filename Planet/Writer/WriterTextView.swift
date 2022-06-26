import SwiftUI

struct WriterTextView: NSViewRepresentable {
    @ObservedObject var draft: DraftModel
    @Binding var text: String
    @Binding var selectedRanges: [NSValue]

    var font: NSFont? = .monospacedSystemFont(ofSize: 14, weight: .regular)

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> WriterCustomTextView {
        let textView = WriterCustomTextView(draft: draft, text: text, font: font)
        textView.delegate = context.coordinator
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
            parent.text = textView.string
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
    private var lastOffset: Float = 0
    weak var delegate: NSTextViewDelegate?
    var text: String
    var selectedRanges: [NSValue] = []

    init(draft: DraftModel, text: String, font: NSFont?) {
        self.draft = draft
        self.font = font
        self.text = text
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError()
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
}

class WriterEditorTextView: NSTextView {
    @ObservedObject var draft: DraftModel
    var urls: [URL] = []

    init(draft: DraftModel, frame: NSRect, textContainer: NSTextContainer) {
        self.draft = draft
        super.init(frame: frame, textContainer: textContainer)
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
        [NSPasteboard.PasteboardType.fileURL]
    }

    // TODO: check multiple writer window drag and drop
    // we probably need to update currently `draggingEntered` window
    override func draggingEnded(_ sender: NSDraggingInfo) {
        guard urls.count > 0 else { return }
        do {
            if let newArticleDraft = draft as? NewArticleDraftModel {
                urls.forEach { url in
                    let type = WriterStore.shared.guessAttachmentType(path: url)
                    try? newArticleDraft.addAttachment(path: url, type: type)
                    try? newArticleDraft.save()
                }
            } else
            if let editArticleDraft = draft as? EditArticleDraftModel {
                urls.forEach { url in
                    let type = WriterStore.shared.guessAttachmentType(path: url)
                    try? editArticleDraft.addAttachment(path: url, type: type)
                    try? editArticleDraft.save()
                }
            } else {
                throw PlanetError.InternalError
            }
        } catch {
            // TODO: alert
        }
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        if let pasteBoardItems = sender.draggingPasteboard.pasteboardItems {
            urls = pasteBoardItems
                .compactMap { $0.propertyList(forType: .fileURL) as? String }
                .map { URL(fileURLWithPath: $0).standardizedFileURL }
        } else {
            urls = []
        }
        return .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        true
    }
}
