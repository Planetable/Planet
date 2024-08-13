//
//  PlanetAPILogView.swift
//  Planet
//

import SwiftUI
import AppKit


private struct AttributedConsoleView: NSViewRepresentable {
    @ObservedObject var viewModel: PlanetAPILogViewModel

    init() {
        _viewModel = ObservedObject(wrappedValue: PlanetAPILogViewModel.shared)
    }

    func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .textBackgroundColor
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        return textView
    }

    func updateNSView(_ nsView: NSTextView, context: Context) {
        let attributedText = NSMutableAttributedString()

        for (index, log) in self.viewModel.logs.enumerated() {
            let logText = "\(index + 1). \(log)\n"
            let attributedLog = NSMutableAttributedString(string: logText)

            // Highlight status codes based on patterns
            if let statusCodeRange = log.range(of: "\\b[2][0-9]{2}\\b", options: .regularExpression) {
                let nsRange = NSRange(statusCodeRange, in: log)
                attributedLog.addAttribute(.foregroundColor, value: NSColor.green, range: nsRange)
            }
            if let statusCodeRange = log.range(of: "\\b[5][0-9]{2}\\b", options: .regularExpression) {
                let nsRange = NSRange(statusCodeRange, in: log)
                attributedLog.addAttribute(.foregroundColor, value: NSColor.red, range: nsRange)
            }

            attributedText.append(attributedLog)
        }

        nsView.textStorage?.setAttributedString(attributedText)
    }
}


struct PlanetAPILogView: View {
    var body: some View {
        VStack {
            Text("Vapor Server Logs")
                .font(.headline)
            AttributedConsoleView()
                .padding()
        }
        .frame(width: 480, height: 320)
        .padding()
    }
}


#Preview {
    PlanetAPILogView()
}
