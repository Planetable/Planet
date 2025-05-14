//
//  WriterPromptTextView.swift
//  Planet
//
//  Created by Kai on 5/14/25.
//

import SwiftUI
import AppKit


struct WriterPromptTextView: NSViewRepresentable {
    @Binding var text: String

    var inset: CGFloat = 16

    // MARK: - NSViewRepresentable

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        textView.font = NSFont(name: "Menlo", size: 14)
        textView.isRichText = false
        textView.isHorizontallyResizable = false
        textView.textContainerInset = NSSize(width: inset, height: inset)
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! NSTextView
        if textView.string != text {
            textView.string = text
        }
        textView.textContainerInset = NSSize(width: inset, height: inset)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: WriterPromptTextView

        init(_ parent: WriterPromptTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
        }
    }
}
