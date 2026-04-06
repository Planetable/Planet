import SwiftUI

struct ChatInputField: View {
    @Binding var text: String
    let fontSize: CGFloat
    let isDisabled: Bool
    var focusOnAppear: Bool = false

    private let contentInset: CGFloat = 10
    private let placeholderTopInset: CGFloat = 12

    var body: some View {
        if #available(macOS 13.0, *) {
            FocusableChatInput(
                text: $text,
                fontSize: fontSize,
                isDisabled: isDisabled,
                focusOnAppear: focusOnAppear,
                contentInset: contentInset,
                placeholderTopInset: placeholderTopInset
            )
        } else {
            chatInputContent
        }
    }

    private var chatInputContent: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .font(.system(size: fontSize))
                .lineSpacing(5)
                .padding(.horizontal, contentInset)
                .padding(.vertical, contentInset)
                .frame(height: 96)
                .disabled(isDisabled)

            if text.isEmpty {
                Text("Ask about this article…")
                    .font(.system(size: fontSize))
                    .foregroundStyle(.secondary)
                    .padding(.leading, contentInset * 1.8)
                    .padding(.top, placeholderTopInset * 0.8)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.textBackgroundColor))
    }
}

@available(macOS 13.0, *)
private struct FocusableChatInput: View {
    @Binding var text: String
    let fontSize: CGFloat
    let isDisabled: Bool
    let focusOnAppear: Bool
    let contentInset: CGFloat
    let placeholderTopInset: CGFloat

    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .font(.system(size: fontSize))
                .lineSpacing(5)
                .padding(.horizontal, contentInset)
                .padding(.vertical, contentInset)
                .frame(height: 96)
                .disabled(isDisabled)
                .focused($isFocused)

            if text.isEmpty {
                Text("Ask about this article…")
                    .font(.system(size: fontSize))
                    .foregroundStyle(.secondary)
                    .padding(.leading, contentInset * 1.8)
                    .padding(.top, placeholderTopInset * 0.8)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.textBackgroundColor))
        .onAppear {
            if focusOnAppear {
                DispatchQueue.main.async {
                    isFocused = true
                }
            }
        }
    }
}
