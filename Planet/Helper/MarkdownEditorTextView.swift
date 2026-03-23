import AppKit

class MarkdownEditorTextView: NSTextView {
    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        enabledTextCheckingTypes = 0
    }

    required init?(coder: NSCoder) {
        fatalError("MarkdownEditorTextView: required init?(coder:) not implemented")
    }

    // MARK: - List autocomplete on Enter

    override func insertNewline(_ sender: Any?) {
        let result = MarkdownListAutocomplete.evaluateBeforeNewline(
            text: self.string,
            cursorUTF16Offset: self.selectedRange().location
        )
        switch result {
        case .removeEmptyMarker(let range):
            insertText("\n", replacementRange: range)
        case .insertPrefix(let prefix, _):
            insertText("\n" + prefix, replacementRange: self.selectedRange())
        case .none:
            super.insertNewline(sender)
        }
    }
}
