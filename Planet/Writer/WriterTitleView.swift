//
//  WriterTitleView.swift
//  Planet
//
//  Created by Kai on 1/5/23.
//

import SwiftUI
import WrappingHStack

struct WriterTitleView: View {
    @State private var updatingTags: Bool = false
    @State private var updatingDate: Bool = false
    @State private var initDate: Date = Date()
    @State private var newTag: String = ""
    @State private var dateIsManuallySet: Bool = false

    var availableTags: [String: Int] = [:]
    @Binding var tags: [String: String]
    @Binding var date: Date
    @Binding var title: String
    @Binding var attachments: [Attachment]
    var handleTitlePaste: (NSPasteboard) -> Bool = { _ in false }

    var body: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .leading) {
                WriterTitleEditor(
                    text: $title,
                    font: NSFont(name: "Menlo", size: 15),
                    importAttachments: handleTitlePaste
                )
                .accessibilityLabel("Title")

                if title.isEmpty {
                    Text("Title")
                        .font(.custom("Menlo", size: 15.0))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 8)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: 34, alignment: .leading)
            .padding(.horizontal, 10)

            Spacer(minLength: 8)

            Text("\(date.simpleDateDescription())")
                .foregroundColor(dateIsManuallySet ? .primary : .secondary)
                .fontWeight(dateIsManuallySet ? .semibold : .regular)
                .background(Color(NSColor.textBackgroundColor))

            Spacer(minLength: 8)

            Button {
                updatingDate.toggle()
            } label: {
                Image(systemName: "calendar.badge.clock")
            }
            .buttonStyle(.plain)
            .padding(.trailing, 16)
            .popover(isPresented: $updatingDate) {
                VStack(spacing: 10) {
                    Spacer()

                    HStack {
                        HStack {
                            Text("Date")
                            Spacer()
                        }
                        .frame(width: 40)
                        Spacer()
                        DatePicker("", selection: $date, displayedComponents: [.date])
                            .datePickerStyle(CompactDatePickerStyle())
                    }
                    .padding(.horizontal, 16)

                    HStack {
                        HStack {
                            Text("Time")
                            Spacer()
                        }
                        .frame(width: 40)
                        Spacer()
                        DatePicker("", selection: $date, displayedComponents: [.hourAndMinute])
                            .datePickerStyle(CompactDatePickerStyle())
                    }
                    .padding(.horizontal, 16)

                    Divider()

                    HStack(spacing: 10) {
                        Button {
                            date = Date()
                        } label: {
                            Text("Now")
                        }
                        Spacer()
                        Button {
                            updatingDate = false
                            dateIsManuallySet = false
                            date = initDate
                        } label: {
                            Text("Revert to Initial")
                        }
                        Button {
                            updatingDate = false
                            // Reset seconds value to zero if set date manually.
                            date = eliminateDateSeconds(fromDate: date)
                        } label: {
                            Text("Set")
                        }
                    }
                    .padding(.horizontal, 16)

                    if (attachments.count > 0) {
                        Divider()

                        HStack {
                            Button {
                                if let attachment = attachments.first {
                                    // Try get creation date from EXIF
                                    if let exifDate = attachment.exifDate {
                                        date = exifDate
                                        dateIsManuallySet = true
                                        return
                                    }
                                    // Get modified date from the file of the first attachment
                                    let fileURL = attachment.path
                                    let fileAttributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
                                    debugPrint("File attributes: \(String(describing: fileAttributes))")
                                    if let creationDate = fileAttributes?[.creationDate] as? Date {
                                        date = creationDate
                                        dateIsManuallySet = true
                                    } else if let modificationDate = fileAttributes?[.modificationDate] as? Date {
                                        date = modificationDate
                                        dateIsManuallySet = true
                                    }
                                }
                            } label: {
                                Text("Set date from attachment")
                            }
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 0)
                .frame(width: 280, height: attachments.count > 0 ? 164 : 124)
            }

            Button {
                updatingTags.toggle()
            } label: {
                Image(systemName: "tag")
                if tags.count > 0 {
                    Text("\(tags.count)")
                        .font(.system(size: 12, weight: .regular, design: .default))
                        .foregroundColor(.secondary)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(4)
                }
            }
            .buttonStyle(.plain)
            .padding(.trailing, 16)
            .popover(isPresented: $updatingTags) {
                tagsView()
            }
        }
        .background(Color(NSColor.textBackgroundColor))
        .task {
            initDate = date
        }
    }

    private func eliminateDateSeconds(fromDate d: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: d)
        return calendar.date(from: dateComponents) ?? d
    }

    private func addTag() {
        let aTag = newTag.trim()
        let normalizedTag = aTag.normalizedTag()
        if normalizedTag.count > 0 {
            if tags.keys.contains(aTag) {
                // tag already exists
                return
            }
            tags[normalizedTag] = aTag
            newTag = ""
        }
    }

    @ViewBuilder
    private func tagsView() -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                HStack {
                    Text("Tags")
                }
                // Tag capsules
                WrappingHStack(
                    tags.values.sorted(),
                    id: \.self,
                    alignment: .leading,
                    spacing: .constant(2),
                    lineSpacing: 4
                ) { tag in
                    TagView(tag: tag)
                        .onTapGesture {
                            tags.removeValue(forKey: tag.normalizedTag())
                        }
                }
            }
            .padding(10)
            .background(Color(NSColor.textBackgroundColor))

            Divider()

            HStack(spacing: 10) {
                HStack {
                    Text("Add a Tag")
                    Spacer()
                }

                TextField("", text: $newTag)
                    .onSubmit {
                        addTag()
                    }
                    .disableAutocorrection(true)
                    .textFieldStyle(.roundedBorder)

                Button {
                    addTag()
                } label: {
                    Text("Add")
                }
            }
            .padding(10)

            if availableTags.count > 0 {
                Divider()

                VStack(spacing: 10) {
                    HStack {
                        Text("Previously Used Tags")
                            .font(.system(size: 11, weight: .regular, design: .default))
                        .foregroundColor(.secondary)
                    }

                    // Tag capsules
                    WrappingHStack(
                        availableTags.keys.sorted(),
                        id: \.self,
                        alignment: .leading,
                        spacing: .constant(2),
                        lineSpacing: 4
                    ) { tag in
                        TagCountView(tag: tag, count: availableTags[tag] ?? 0)
                            .onTapGesture {
                                let normalizedTag = tag.normalizedTag()
                                tags[normalizedTag] = tag
                            }
                    }
                }
                .padding(10)
                .background(Color(NSColor.textBackgroundColor))
            }
        }
        .frame(width: tagsViewWidth(tagsCount: availableTags.count))
    }

    private func tagsViewWidth(tagsCount: Int) -> CGFloat {
        if (tagsCount > 30) {
            return 380
        } else {
            return 280
        }
    }
}

struct WriterTitleEditor: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont?
    var importAttachments: (NSPasteboard) -> Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> WriterTitleEditorContainer {
        let container = WriterTitleEditorContainer(
            text: text,
            font: font,
            importAttachments: importAttachments
        )
        container.delegate = context.coordinator
        return container
    }

    func updateNSView(_ nsView: WriterTitleEditorContainer, context: Context) {
        nsView.updateText(text)
        nsView.updatePasteHandler(importAttachments)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: WriterTitleEditor

        init(_ parent: WriterTitleEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? WriterTitleEditorTextView else {
                return
            }
            guard !textView.hasMarkedText() else { return }
            parent.text = textView.string
        }
    }
}

final class WriterTitleEditorContainer: NSView {
    private let font: NSFont?
    private var text: String
    private var importAttachments: (NSPasteboard) -> Bool

    private lazy var scrollView: NSScrollView = {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()

    private lazy var textView: WriterTitleEditorTextView = {
        let contentSize = scrollView.contentSize
        let textStorage = NSTextStorage()

        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(
            containerSize: NSSize(width: CGFloat.greatestFiniteMagnitude, height: contentSize.height)
        )
        textContainer.widthTracksTextView = false
        textContainer.heightTracksTextView = true
        textContainer.lineBreakMode = .byClipping
        layoutManager.addTextContainer(textContainer)

        let textView = WriterTitleEditorTextView(frame: .zero, textContainer: textContainer)
        textView.importAttachments = importAttachments
        textView.autoresizingMask = [.height]
        textView.textContainerInset = NSSize(width: 0, height: 8)
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.font = font
        textView.string = text
        textView.isEditable = true
        textView.isSelectable = true
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = false
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: contentSize.height)
        textView.minSize = NSSize(width: 0, height: contentSize.height)
        textView.textColor = .labelColor
        textView.insertionPointColor = .labelColor
        textView.isRichText = false
        textView.usesFontPanel = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.enabledTextCheckingTypes = 0
        return textView
    }()

    weak var delegate: NSTextViewDelegate?

    init(
        text: String,
        font: NSFont?,
        importAttachments: @escaping (NSPasteboard) -> Bool
    ) {
        self.text = text
        self.font = font
        self.importAttachments = importAttachments
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("WriterTitleEditorContainer: required init?(coder:) not implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            window.makeFirstResponder(self.textView)
            let end = (self.textView.string as NSString).length
            self.textView.setSelectedRange(NSRange(location: end, length: 0))
        }
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
        guard !textView.hasMarkedText() else { return }
        guard textView.string != text else { return }

        let selection = textView.selectedRange()
        let cursorLocation = min(selection.location, (text as NSString).length)
        textView.string = text
        textView.setSelectedRange(NSRange(location: cursorLocation, length: 0))
    }

    func updatePasteHandler(_ importAttachments: @escaping (NSPasteboard) -> Bool) {
        self.importAttachments = importAttachments
        textView.importAttachments = importAttachments
    }

}

final class WriterTitleEditorTextView: NSTextView {
    var importAttachments: (NSPasteboard) -> Bool = { _ in false }

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

    override func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general
        if importAttachments(pasteboard) {
            return
        }
        super.paste(sender)
    }

    override func readSelection(from pboard: NSPasteboard) -> Bool {
        if importAttachments(pboard) {
            return true
        }
        return super.readSelection(from: pboard)
    }

    override func readSelection(
        from pboard: NSPasteboard,
        type: NSPasteboard.PasteboardType
    ) -> Bool {
        if WriterPasteboardImporter.canImport(returnType: type), importAttachments(pboard) {
            return true
        }
        return super.readSelection(from: pboard, type: type)
    }

    override func insertText(_ string: Any, replacementRange: NSRange) {
        guard let string = string as? String else {
            super.insertText(string, replacementRange: replacementRange)
            return
        }

        let sanitized = string
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
        super.insertText(sanitized, replacementRange: replacementRange)
    }

    override func insertTab(_ sender: Any?) {
        guard let contentView = window?.contentView else { return }
        if let editorTextView = Self.findSubview(ofType: WriterEditorTextView.self, in: contentView) {
            window?.makeFirstResponder(editorTextView)
        }
    }

    private static func findSubview<T: NSView>(ofType type: T.Type, in view: NSView) -> T? {
        if let match = view as? T { return match }
        for subview in view.subviews {
            if let found = findSubview(ofType: type, in: subview) { return found }
        }
        return nil
    }

    override func insertNewline(_ sender: Any?) {
        insertTab(sender)
    }

    override func insertLineBreak(_ sender: Any?) {
        insertTab(sender)
    }
}

struct WriterTitleView_Previews: PreviewProvider {
    static var previews: some View {
        WriterTitleView(availableTags: [:], tags: .constant([:]), date: .constant(Date()), title: .constant(""), attachments: .constant([]), handleTitlePaste: { _ in false })
    }
}
