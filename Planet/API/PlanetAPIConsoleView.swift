//
//  PlanetAPIConsoleView.swift
//  Planet
//

import SwiftUI
import AppKit


private struct AttributedConsoleView: NSViewRepresentable {
    @ObservedObject var viewModel: PlanetAPIConsoleViewModel
    
    init() {
        _viewModel = ObservedObject(wrappedValue: PlanetAPIConsoleViewModel.shared)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 16, height: 16)
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.lineBreakMode = .byWordWrapping
        
        
        scrollView.documentView = textView
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        let attributedText = NSMutableAttributedString()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
        for log in viewModel.logs {
            let timestampString = dateFormatter.string(from: log.timestamp)
            let logText = "\(timestampString) \(log.statusCode) \(log.requestURL)\n"
            let attributedLog = NSMutableAttributedString(string: logText)
            
            // Set base color for both light and dark theme
            attributedLog.addAttribute(.foregroundColor, value: NSColor.textColor, range: NSRange(location: 0, length: attributedLog.length))
            
            // Set base font
            attributedLog.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular), range: NSRange(location: 0, length: attributedLog.length))
            
            // Match timestamp
            let timestampRange = NSRange(location: 0, length: timestampString.count)
            attributedLog.addAttribute(.foregroundColor, value: NSColor.placeholderTextColor, range: timestampRange)
            
            // Match status code
            let regexPattern = "\\b(\\d{3})\\b"
            let regex = try! NSRegularExpression(pattern: regexPattern, options: [])
            let matches = regex.matches(in: logText, options: [], range: NSRange(location: timestampString.count + 1, length: logText.utf16.count - timestampString.count - 1))
            for match in matches {
                if match.numberOfRanges > 0 {
                    let statusCodeRange = match.range(at: 1)
                    let statusCodeString = (logText as NSString).substring(with: statusCodeRange)
                    if let statusCode = Int(statusCodeString) {
                        var color: NSColor
                        switch statusCode {
                            case 200..<300:
                                color = .green
                            case 400..<500:
                                color = .orange
                            case 500..<600:
                                color = .red
                            default:
                                color = .textColor
                        }
                        attributedLog.addAttribute(.foregroundColor, value: color, range: statusCodeRange)
                        attributedLog.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 12, weight: .bold), range: statusCodeRange)
                    }
                }
            }
            
            // Match request method
            if let methodRange = logText.range(of: log.requestURL.split(separator: " ").first ?? "") {
                let nsRange = NSRange(methodRange, in: logText)
                attributedLog.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold), range: nsRange)
            }

            attributedText.append(attributedLog)
        }
        textView.textStorage?.setAttributedString(attributedText)
        textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
    }
}

struct PlanetAPIConsoleView: View {
    var body: some View {
        AttributedConsoleView()
            .frame(width: 480, height: 320)
    }
}
