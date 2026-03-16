import AppKit

/// Shared autocomplete logic for Markdown lists (ordered, unordered, and todo).
/// Used by both Writer and QuickPost after Enter inserts a newline.
enum MarkdownListAutocomplete {
    enum Result {
        /// Remove the empty list marker from the previous line.
        /// The NSRange covers the line's content (excluding its \n terminator).
        case removeEmptyMarker(utf16Range: NSRange)
        /// Insert a continuation prefix at the cursor position.
        case insertPrefix(String, atUTF16Offset: Int)
        /// No autocomplete action needed.
        case none
    }

    /// Evaluate what autocomplete action to take after Enter inserted a newline.
    ///
    /// Call this from `keyDown` **after** `super.keyDown` has already inserted
    /// the newline.  Pass the text view's current string and cursor position.
    ///
    /// - Parameters:
    ///   - text: The full text content (after the newline was inserted).
    ///   - cursorUTF16Offset: The cursor position in UTF-16 units (`selectedRange().location`).
    /// - Returns: The autocomplete action to apply via `insertText(_:replacementRange:)`.
    static func evaluate(text: String, cursorUTF16Offset: Int) -> Result {
        let ns = text as NSString
        let cursorPos = cursorUTF16Offset
        guard cursorPos > 0, ns.length > 0 else { return .none }

        // Find the start of the cursor's current line.
        // When cursor is at or past the end and text ends with \n,
        // the cursor is on a new (empty) line whose start == ns.length.
        var curLineStart: Int
        if cursorPos >= ns.length,
           ns.character(at: ns.length - 1) == unichar(0x0A) {
            curLineStart = ns.length
        } else if cursorPos < ns.length {
            curLineStart = 0
            ns.getLineStart(&curLineStart, end: nil, contentsEnd: nil,
                            for: NSRange(location: cursorPos, length: 0))
        } else {
            return .none
        }

        // The previous line ends just before curLineStart
        guard curLineStart > 0 else { return .none }

        // Find the start and content-end of the previous line
        var prevLineStart = 0
        var prevContentsEnd = 0
        ns.getLineStart(&prevLineStart, end: nil, contentsEnd: &prevContentsEnd,
                        for: NSRange(location: curLineStart - 1, length: 0))

        let prevLineRange = NSRange(location: prevLineStart, length: prevContentsEnd - prevLineStart)
        let previousLine = ns.substring(with: prevLineRange)
        let trimmedPrevious = previousLine.trimmingCharacters(in: .whitespaces)

        // Check if previous line is an empty list item
        let isEmptyNumberedItem = trimmedPrevious.range(of: #"^\d+\.$"#, options: .regularExpression) != nil
        if trimmedPrevious == "*" || trimmedPrevious == "+" || trimmedPrevious == "-"
            || trimmedPrevious == "- [ ]" || trimmedPrevious == "- [x]" || trimmedPrevious == "- [X]"
            || isEmptyNumberedItem {
            return .removeEmptyMarker(utf16Range: prevLineRange)
        }

        // List continuation: insert prefix at the cursor position
        if trimmedPrevious.hasPrefix("- [ ] ") || trimmedPrevious.hasPrefix("- [x] ") || trimmedPrevious.hasPrefix("- [X] ") {
            return .insertPrefix("- [ ] ", atUTF16Offset: cursorPos)
        }
        if trimmedPrevious.hasPrefix("* ") {
            return .insertPrefix("* ", atUTF16Offset: cursorPos)
        }
        if trimmedPrevious.hasPrefix("+ ") {
            return .insertPrefix("+ ", atUTF16Offset: cursorPos)
        }
        if trimmedPrevious.hasPrefix("- ") {
            return .insertPrefix("- ", atUTF16Offset: cursorPos)
        }
        if let match = trimmedPrevious.range(of: #"^(\d+)\. "#, options: .regularExpression) {
            let numberStr = trimmedPrevious[match].dropLast(2)
            if let number = Int(numberStr) {
                return .insertPrefix("\(number + 1). ", atUTF16Offset: cursorPos)
            }
        }

        return .none
    }

    /// Apply the result to an NSTextView via `insertText`.
    @MainActor
    static func apply(_ result: Result, to textView: NSTextView) {
        switch result {
        case .removeEmptyMarker(let utf16Range):
            textView.insertText("", replacementRange: utf16Range)
        case .insertPrefix(let prefix, let offset):
            textView.insertText(prefix, replacementRange: NSRange(location: offset, length: 0))
        case .none:
            break
        }
    }
}
