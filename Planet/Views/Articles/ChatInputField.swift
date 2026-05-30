import SwiftUI

struct ChatInputField: View {
    @Binding var text: String
    let fontSize: CGFloat
    let isDisabled: Bool
    var focusOnAppear: Bool = false
    var placeholder: String = L10n("Ask about this article...")
    var onSend: () -> Void = {}

    var body: some View {
        ChatInputTextView(
            text: $text,
            fontSize: fontSize,
            isDisabled: isDisabled,
            focusOnAppear: focusOnAppear,
            placeholder: placeholder,
            onSend: onSend
        )
        .frame(height: 96)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.textBackgroundColor))
    }
}

private struct ChatInputTextView: NSViewRepresentable {
    @Binding var text: String
    let fontSize: CGFloat
    let isDisabled: Bool
    let focusOnAppear: Bool
    let placeholder: String
    let onSend: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> ChatInputTextViewContainer {
        let container = ChatInputTextViewContainer(
            text: text,
            fontSize: fontSize,
            isDisabled: isDisabled,
            placeholder: placeholder
        )
        container.textView.delegate = context.coordinator
        container.textView.onSend = context.coordinator.send
        return container
    }

    func updateNSView(_ nsView: ChatInputTextViewContainer, context: Context) {
        context.coordinator.parent = self
        nsView.update(
            text: text,
            fontSize: fontSize,
            isDisabled: isDisabled,
            placeholder: placeholder,
            focusOnAppear: focusOnAppear
        )
        nsView.textView.onSend = context.coordinator.send
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ChatInputTextView

        init(_ parent: ChatInputTextView) {
            self.parent = parent
        }

        func textDidBeginEditing(_ notification: Notification) {
            updateText(from: notification)
        }

        func textDidChange(_ notification: Notification) {
            updateText(from: notification)
        }

        func textDidEndEditing(_ notification: Notification) {
            updateText(from: notification, allowsMarkedText: true)
        }

        func send() {
            parent.onSend()
        }

        private func updateText(from notification: Notification, allowsMarkedText: Bool = false) {
            guard let textView = notification.object as? NSTextView else { return }
            guard allowsMarkedText || !textView.hasMarkedText() else { return }
            parent.text = textView.string
        }
    }
}

private final class ChatInputTextViewContainer: NSView {
    let textView: ChatInputEditorTextView

    private let scrollView = NSScrollView()
    private let placeholderLabel = ChatInputPlaceholderLabel(labelWithString: "")
    private var didFocusOnAppear = false
    private var shouldFocusOnAppear = false

    init(text: String, fontSize: CGFloat, isDisabled: Bool, placeholder: String) {
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(size: .zero)
        textContainer.widthTracksTextView = true
        textContainer.containerSize = NSSize(width: 1, height: CGFloat.greatestFiniteMagnitude)
        layoutManager.addTextContainer(textContainer)

        textView = ChatInputEditorTextView(frame: .zero, textContainer: textContainer)
        textView.string = text

        super.init(frame: .zero)

        setupScrollView()
        setupPlaceholderLabel()
        setupTextView(fontSize: fontSize, isDisabled: isDisabled, placeholder: placeholder)
    }

    required init?(coder: NSCoder) {
        fatalError("ChatInputTextViewContainer: required init?(coder:) not implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        focusIfNeeded()
    }

    func update(text: String, fontSize: CGFloat, isDisabled: Bool, placeholder: String, focusOnAppear: Bool) {
        shouldFocusOnAppear = focusOnAppear
        setupTextView(fontSize: fontSize, isDisabled: isDisabled, placeholder: placeholder)

        if !textView.hasMarkedText(), textView.string != text {
            textView.string = text
            let insertionPoint = (text as NSString).length
            textView.setSelectedRange(NSRange(location: insertionPoint, length: 0))
        }

        updatePlaceholderVisibility()
        focusIfNeeded()
    }

    private func setupScrollView() {
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
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

    private func setupPlaceholderLabel() {
        placeholderLabel.textColor = .secondaryLabelColor
        placeholderLabel.backgroundColor = .clear
        placeholderLabel.isBezeled = false
        placeholderLabel.isEditable = false
        placeholderLabel.isSelectable = false
        placeholderLabel.lineBreakMode = .byTruncatingTail
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(placeholderLabel)
        NSLayoutConstraint.activate([
            placeholderLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            placeholderLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -18),
            placeholderLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10)
        ])
    }

    private func setupTextView(fontSize: CGFloat, isDisabled: Bool, placeholder: String) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 5

        textView.onTextStateChanged = { [weak self] in
            self?.updatePlaceholderVisibility()
        }
        textView.autoresizingMask = .width
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.font = .systemFont(ofSize: fontSize)
        textView.defaultParagraphStyle = paragraphStyle
        textView.typingAttributes[.paragraphStyle] = paragraphStyle
        textView.importsGraphics = false
        textView.isEditable = !isDisabled
        textView.isHorizontallyResizable = false
        textView.isRichText = false
        textView.isSelectable = true
        textView.isVerticallyResizable = true
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.minSize = NSSize(width: 0, height: scrollView.contentSize.height)
        textView.textColor = .labelColor
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.usesFontPanel = false
        textView.allowsUndo = true
        textView.setAccessibilityLabel(placeholder)

        placeholderLabel.stringValue = placeholder
        placeholderLabel.font = .systemFont(ofSize: fontSize)
        updatePlaceholderVisibility()
    }

    private func focusIfNeeded() {
        guard shouldFocusOnAppear, !didFocusOnAppear else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, let window else { return }
            if window.makeFirstResponder(textView) {
                didFocusOnAppear = true
            }
        }
    }

    private func updatePlaceholderVisibility() {
        placeholderLabel.isHidden = !textView.string.isEmpty || textView.hasMarkedText()
    }
}

private final class ChatInputEditorTextView: NSTextView {
    var onSend: (() -> Void)?
    var onTextStateChanged: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        guard isReturnKey(event), !hasMarkedText() else {
            super.keyDown(with: event)
            return
        }

        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])

        if modifiers.isEmpty {
            onSend?()
            return
        }

        if modifiers.contains(.command), !modifiers.contains(.option), !modifiers.contains(.control) {
            insertNewline(nil)
            return
        }

        super.keyDown(with: event)
    }

    override func didChangeText() {
        super.didChangeText()
        onTextStateChanged?()
    }

    override func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        super.setMarkedText(string, selectedRange: selectedRange, replacementRange: replacementRange)
        onTextStateChanged?()
    }

    override func unmarkText() {
        super.unmarkText()
        onTextStateChanged?()
    }

    private func isReturnKey(_ event: NSEvent) -> Bool {
        event.keyCode == 36 || event.keyCode == 76
    }
}

private final class ChatInputPlaceholderLabel: NSTextField {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
