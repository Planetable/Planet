import SwiftUI

struct ChatInputField: View {
    @Binding var text: String
    let fontSize: CGFloat
    let isDisabled: Bool

    private let contentInset: CGFloat = 10
    private let placeholderTopInset: CGFloat = 12

    var body: some View {
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
