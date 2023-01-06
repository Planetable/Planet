//
//  CLTextFieldView.swift
//  CodeLauncher
//
//  Created by Kai on 7/20/22.
//

import SwiftUI


private struct CLTextFieldBaseView: NSViewRepresentable {

    class Coordinator: NSObject, NSControlTextEditingDelegate, NSTextFieldDelegate {
        var parent: CLTextFieldBaseView

        init(_ parent: CLTextFieldBaseView) {
            self.parent = parent
        }

        // MARK: - NSControlTextEditingDelegate

        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            parent.text = textField.stringValue
        }

        func controlTextDidBeginEditing(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            parent.text = textField.stringValue
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            parent.text = textField.stringValue
        }

        // MARK: - NSTextFieldDelegate

        func textField(_ textField: NSTextField, textView: NSTextView, shouldSelectCandidateAt index: Int) -> Bool {
            return true
        }

        func textField(_ textField: NSTextField, textView: NSTextView, candidatesForSelectedRange selectedRange: NSRange) -> [Any]? {
            return nil
        }

        func textField(_ textField: NSTextField, textView: NSTextView, candidates: [NSTextCheckingResult], forSelectedRange selectedRange: NSRange) -> [NSTextCheckingResult] {
            return []
        }
    }

    @Binding var text: String
    var placeholder: String = ""
    var colorScheme: ColorScheme = .light

    func makeNSView(context: Context) -> some NSView {
        let textField = NSTextField()
        textField.delegate = context.coordinator
        textField.stringValue = text
        textField.placeholderString = placeholder
        textField.font = .systemFont(ofSize: 15)
        textField.wantsLayer = true
        textField.isBordered = false
        textField.drawsBackground = false
        textField.bezelStyle = .roundedBezel
        return textField
    }

    func updateNSView(_ nsView: NSViewType, context: Context) {
        if let textField = nsView as? NSTextField {
            textField.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
}


struct CLTextFieldView: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var text: String
    var placeholder: String = ""

    var body: some View {
        CLTextFieldBaseView(text: $text, placeholder: placeholder, colorScheme: colorScheme)
    }
}


struct CLTextFieldView_Previews: PreviewProvider {
    static var previews: some View {
        CLTextFieldView(text: .constant(""))
    }
}
