//
//  PlanetWriterTextView.swift
//  Planet
//
//  Created by Kai on 3/29/22.
//

import SwiftUI


struct PlanetWriterTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var selectedRanges: [NSValue]

    var writerID: UUID
    var font: NSFont? = .monospacedSystemFont(ofSize: 14, weight: .regular)

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> PlanetWriterCustomTextView {
        let textView = PlanetWriterCustomTextView(text: text, writerID: writerID, font: font)
        textView.delegate = context.coordinator
        setupNotifications(forTextView: textView)
        return textView
    }

    func updateNSView(_ nsView: PlanetWriterCustomTextView, context: Context) {
        nsView.text = text
    }

    private func setupNotifications(forTextView textView: PlanetWriterCustomTextView) {
        NotificationCenter.default.addObserver(forName: Notification.Name.notification(notification: .clearText, forID: writerID), object: nil, queue: .main) { n in
            textView.clearText()
        }
        NotificationCenter.default.addObserver(forName: Notification.Name.notification(notification: .insertText, forID: writerID), object: nil, queue: .main) { n in
            guard let t = n.object as? String else { return }
            textView.insertTextAtCursor(text: t)
        }
        NotificationCenter.default.addObserver(forName: Notification.Name.notification(notification: .removeText, forID: writerID), object: nil, queue: .main) { n in
            guard let t = n.object as? String else { return }
            textView.removeTargetText(text: t)
        }
        NotificationCenter.default.addObserver(forName: Notification.Name.notification(notification: .moveCursorFront, forID: writerID), object: nil, queue: .main) { n in
            textView.moveCursorFront()
        }
        NotificationCenter.default.addObserver(forName: Notification.Name.notification(notification: .moveCursorEnd, forID: writerID), object: nil, queue: .main) { n in
            textView.moveCursorEnd()
        }
    }
}


extension PlanetWriterTextView {
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: PlanetWriterTextView
        var selectedRanges: [NSValue] = []

        init(_ parent: PlanetWriterTextView) {
            self.parent = parent
        }

        func textDidBeginEditing(_ notification: Notification) {
            guard let textView = notification.object as? PlanetWriterEditorTextView else {
                return
            }
            self.parent.text = textView.string
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? PlanetWriterEditorTextView else {
                return
            }
            self.parent.text = textView.string
            self.parent.selectedRanges = textView.selectedRanges
            self.selectedRanges = textView.selectedRanges
        }

        func textDidEndEditing(_ notification: Notification) {
            guard let textView = notification.object as? PlanetWriterEditorTextView else {
                return
            }
            self.parent.text = textView.string
        }

    }
}


class PlanetWriterCustomTextView: NSView {
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

    private lazy var textView: PlanetWriterEditorTextView = {
        let contentSize = scrollView.contentSize
        let textStorage = NSTextStorage()

        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(containerSize: scrollView.frame.size)
        textContainer.widthTracksTextView = true
        textContainer.containerSize = NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude)

        layoutManager.addTextContainer(textContainer)

        let t = PlanetWriterEditorTextView(frame: .zero, textContainer: textContainer)
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

    private var font: NSFont?

    private var lastOffset: Float = 0

    weak var delegate: NSTextViewDelegate?

    var text: String {
        didSet {
        }
    }

    var selectedRanges: [NSValue] = [] {
        didSet {
        }
    }

    init(text: String, writerID: UUID, font: NSFont?) {
        self.font = font
        self.text = text
        super.init(frame: .zero)
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            guard let scroller = self.scrollView.verticalScroller, self.lastOffset != scroller.floatValue else { return }
            let scrollNotification = Notification.Name.notification(notification: .scrollPage, forID: writerID)
            NotificationCenter.default.post(name: scrollNotification, object: NSNumber(value: scroller.floatValue))
            debugPrint("scrolling page to \(scroller.floatValue), writer: \(writerID)")
            self.lastOffset = scroller.floatValue
        }
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    // MARK: -
    override func viewWillDraw() {
        super.viewWillDraw()
        setupScrollViewConstraints()
        setupTextView()
    }

    func setupScrollViewConstraints() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor)
        ])
    }

    func setupTextView() {
        scrollView.documentView = textView
    }

    // MARK: - Text Operations
    func clearText() {
        textView.selectedRanges = [NSValue(range: NSRange(location: 0, length: 0))]
        textView.string = ""
    }

    func insertTextAtCursor(text: String) {
        var range = textView.selectedRanges.first?.rangeValue ?? NSRange(location: 0, length: 0)
        range.length = 0
        textView.insertText(text, replacementRange: range)
    }

    func removeTargetText(text: String) {
        textView.string = textView.string.replacingOccurrences(of: text, with: "")
    }

    func moveCursorFront() {
        let range = NSRange(location: 0, length: 0)
        textView.selectedRanges = [NSValue(range: range)]
    }

    func moveCursorEnd() {
        let range = NSRange(location: textView.string.count, length: 0)
        textView.selectedRanges = [NSValue(range: range)]
    }
}
