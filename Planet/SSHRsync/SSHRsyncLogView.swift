//
//  SSHRsyncLogView.swift
//  Planet
//

import SwiftUI
import AppKit


class SSHRsyncLogWindowManager: NSObject, NSWindowDelegate {
    static let shared = SSHRsyncLogWindowManager()

    private var window: NSWindow?

    func open() {
        if let window {
            reload()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let viewModel = SSHRsyncLogViewModel.shared
        viewModel.reload()
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 400),
            styleMask: [.closable, .titled, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        w.isReleasedWhenClosed = false
        w.title = "SSH Rsync Log"
        w.minSize = NSSize(width: 400, height: 240)
        w.contentView = NSHostingView(rootView: SSHRsyncLogView(viewModel: viewModel))
        w.center()
        w.setFrameAutosaveName("SSHRsyncLogWindow")
        w.delegate = self
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = w
    }

    func reload() {
        SSHRsyncLogViewModel.shared.reload()
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}


class SSHRsyncLogViewModel: ObservableObject {
    static let shared = SSHRsyncLogViewModel()
    @Published var logContent: String = ""

    private var dispatchSource: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1

    func reload() {
        logContent = SSHRsyncLogger.readAll()
    }

    func clear() {
        SSHRsyncLogger.clear()
        logContent = ""
    }

    func startMonitoring() {
        stopMonitoring()
        // Monitor the tmp directory so we catch file creation after clear/first write
        let dirPath = NSTemporaryDirectory()
        fileDescriptor = open(dirPath, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: .write,
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.reload()
        }
        source.setCancelHandler { [weak self] in
            guard let self, self.fileDescriptor >= 0 else { return }
            close(self.fileDescriptor)
            self.fileDescriptor = -1
        }
        source.resume()
        dispatchSource = source
    }

    func stopMonitoring() {
        dispatchSource?.cancel()
        dispatchSource = nil
    }
}


private struct SSHRsyncLogTextView: NSViewRepresentable {
    @ObservedObject var viewModel: SSHRsyncLogViewModel

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
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.minSize = NSSize(width: 400, height: 240)
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
        let content = viewModel.logContent
        let fontSize: CGFloat = 12
        let baseFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let boldFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)

        guard !content.isEmpty else {
            let placeholder = NSAttributedString(
                string: "No log entries yet.",
                attributes: [.font: baseFont, .foregroundColor: NSColor.secondaryLabelColor]
            )
            textView.textStorage?.setAttributedString(placeholder)
            return
        }

        let result = NSMutableAttributedString()
        let lines = content.components(separatedBy: "\n")

        for line in lines {
            guard !line.isEmpty else {
                result.append(NSAttributedString(string: "\n"))
                continue
            }

            let attrLine = NSMutableAttributedString(
                string: line + "\n",
                attributes: [.font: baseFont, .foregroundColor: NSColor.textColor]
            )
            let nsLine = line as NSString
            let fullRange = NSRange(location: 0, length: nsLine.length)

            // Dim timestamps
            if let regex = try? NSRegularExpression(pattern: "^\\[[^\\]]+\\]", options: []),
               let match = regex.firstMatch(in: line, options: [], range: fullRange)
            {
                attrLine.addAttribute(.foregroundColor, value: NSColor.placeholderTextColor, range: match.range)
            }

            // Yellow warning lines
            if line.contains("[WARNING]") {
                attrLine.addAttribute(.foregroundColor, value: NSColor.systemYellow, range: fullRange)
                attrLine.addAttribute(.font, value: boldFont, range: fullRange)
            }
            // Red error tags
            else if line.contains("[ERROR]") {
                if let range = nsLine.range(of: "[ERROR]").asOptional {
                    attrLine.addAttribute(.foregroundColor, value: NSColor.systemRed, range: range)
                    attrLine.addAttribute(.font, value: boldFont, range: range)
                }
            }

            result.append(attrLine)
        }

        textView.textStorage?.setAttributedString(result)
        textView.scrollToEndOfDocument(nil)
    }
}


private extension NSRange {
    var asOptional: NSRange? {
        location == NSNotFound ? nil : self
    }
}


private struct SSHKeyWarningRow: View {
    let logContent: String

    var hasKeyError: Bool {
        logContent.contains("Operation not permitted")
            || logContent.contains("Permission denied")
            || logContent.contains("identity file")
            || logContent.contains("Host key verification failed")
    }

    var body: some View {
        if hasKeyError {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)
                Text("SSH key error detected. Select a key in the planet's Publishing settings.")
                    .font(.system(size: 12))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.yellow.opacity(0.1))
            Divider()
        }
    }
}


struct SSHRsyncLogView: View {
    @ObservedObject fileprivate var viewModel: SSHRsyncLogViewModel

    var body: some View {
        VStack(spacing: 0) {
            SSHKeyWarningRow(logContent: viewModel.logContent)
            SSHRsyncLogTextView(viewModel: viewModel)
        }
        .frame(minWidth: 400, minHeight: 240)
            .onAppear { viewModel.startMonitoring() }
            .onDisappear { viewModel.stopMonitoring() }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        viewModel.clear()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .help("Clear log")
                }
            }
    }
}
