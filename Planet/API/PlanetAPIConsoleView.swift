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
        scrollView.drawsBackground = true
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalRuler = false
        scrollView.autoresizingMask = [.width, .height]
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        let textView = NSTextView()
        textView.autoresizingMask = .width
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.drawsBackground = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 480, height: 320)
        textView.textColor = NSColor.labelColor
        textView.allowsUndo = false
        textView.isEditable = false
        textView.isSelectable = true
        textView.textContainerInset = NSSize(width: 16, height: 10)
        textView.textContainer?.widthTracksTextView = true
        
        scrollView.documentView = textView
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        let attributedText = NSMutableAttributedString()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
        Task.detached(priority: .utility) {
            await viewModel.loadLogs()
            Task { @MainActor in
                for log in viewModel.logs {
                    let timestampString = dateFormatter.string(from: log.timestamp)
                    let logText: String = {
                        if log.originIP != "" {
                            return "\(timestampString) \(log.originIP) \(log.statusCode) \(log.requestURL)\n"
                        }
                        return "\(timestampString) \(log.statusCode) \(log.requestURL)\n"
                    }()
                    let attributedLog = NSMutableAttributedString(string: logText)
                    
                    // Set base color for both light and dark theme
                    attributedLog.addAttribute(.foregroundColor, value: NSColor.textColor, range: NSRange(location: 0, length: attributedLog.length))
                    
                    // Set base font
                    attributedLog.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: self.viewModel.baseFontSize, weight: .regular), range: NSRange(location: 0, length: attributedLog.length))
                    
                    // Match timestamp
                    let timestampRange = NSRange(location: 0, length: timestampString.count)
                    attributedLog.addAttribute(.foregroundColor, value: NSColor.placeholderTextColor, range: timestampRange)
                    
                    // Match IP address
                    let ipAddressPattern = "\\b((?:\\d{1,3}\\.){3}\\d{1,3}|(?:[a-fA-F0-9]{1,4}:){7}[a-fA-F0-9]{1,4})\\b"
                    let ipRegex = try! NSRegularExpression(pattern: ipAddressPattern, options: [])
                    let ipMatches = ipRegex.matches(in: logText, options: [], range: NSRange(location: timestampString.count + 1, length: logText.utf16.count - timestampString.count - 1))
                    var ipRange: NSRange?
                    if let ipMatch = ipMatches.first {
                        ipRange = ipMatch.range
                        attributedLog.addAttribute(.foregroundColor, value: NSColor.textColor, range: ipRange!)
                    }
                    
                    // Match status code
                    let regexPattern = "\\b(\\d{3})\\b"
                    let regex = try! NSRegularExpression(pattern: regexPattern, options: [])
                    let searchStart = (ipRange?.location ?? timestampString.count) + (ipRange?.length ?? 0) + 1
                    let searchRange = NSRange(location: searchStart, length: logText.utf16.count - searchStart)
                    let matches = regex.matches(in: logText, options: [], range: searchRange)
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
                                attributedLog.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: self.viewModel.baseFontSize, weight: .bold), range: statusCodeRange)
                            }
                        }
                    }
                    
                    // Match request method
                    if let methodRange = logText.range(of: log.requestURL.split(separator: " ").first ?? "") {
                        let nsRange = NSRange(methodRange, in: logText)
                        attributedLog.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: self.viewModel.baseFontSize, weight: .semibold), range: nsRange)
                    }
                    
                    attributedText.append(attributedLog)
                    
                    // Add error description if available
                    if log.errorDescription != "" {
                        let errorDescription = log.errorDescription + "\n"
                        let attributedErrorDescription = NSMutableAttributedString(string: errorDescription)
                        let errorRange = NSRange(location: 0, length: attributedErrorDescription.length)
                        attributedErrorDescription.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: self.viewModel.baseFontSize, weight: .medium), range: errorRange)
                        attributedErrorDescription.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: errorRange)
                        attributedText.append(attributedErrorDescription)
                    }
                }
                textView.textStorage?.setAttributedString(attributedText)
                textView.scrollToEndOfDocument(nil)
            }
        }
    }
}

struct PlanetAPIConsoleView: View {
    var body: some View {
        AttributedConsoleView()
            .frame(minWidth: 480, idealWidth: 480, maxWidth: .infinity, minHeight: 320, idealHeight: 320, maxHeight: .infinity)
    }
}
