//
//  PublishLogView.swift
//  Planet
//

import SwiftUI
import AppKit


enum PublishLogSource: String, CaseIterable {
    case ipfs = "IPFS"
    case sshRsync = "SSH Rsync"
    case cloudflarePages = "Cloudflare Pages"

    var logPath: String {
        switch self {
        case .ipfs:
            return IPFSLogger.logPath
        case .sshRsync:
            return SSHRsyncLogger.logPath
        case .cloudflarePages:
            return CloudflarePagesLogger.logPath
        }
    }

    func readAll() -> String {
        switch self {
        case .ipfs:
            return IPFSLogger.readAll()
        case .sshRsync:
            return SSHRsyncLogger.readAll()
        case .cloudflarePages:
            return CloudflarePagesLogger.readAll()
        }
    }

    func clear() {
        switch self {
        case .ipfs:
            IPFSLogger.clear()
        case .sshRsync:
            SSHRsyncLogger.clear()
        case .cloudflarePages:
            CloudflarePagesLogger.clear()
        }
    }
}


class PublishLogWindowManager: NSObject, NSWindowDelegate {
    static let shared = PublishLogWindowManager()

    private var window: NSWindow?

    func open(tab: PublishLogSource? = nil) {
        if let tab {
            PublishLogViewModel.shared.selectedSource = tab
        }
        if let window {
            reload()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let viewModel = PublishLogViewModel.shared
        viewModel.reload()
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 400),
            styleMask: [.closable, .titled, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        w.isReleasedWhenClosed = false
        w.title = "Log"
        w.minSize = NSSize(width: 400, height: 240)
        w.contentView = NSHostingView(rootView: PublishLogView(viewModel: viewModel))
        w.center()
        w.setFrameAutosaveName("PublishLogWindow")
        w.delegate = self
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = w
    }

    func reload() {
        PublishLogViewModel.shared.reload()
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}


class PublishLogViewModel: ObservableObject {
    static let shared = PublishLogViewModel()
    private static let selectedSourceDefaultsKey = "PublishLogView.SelectedSource"
    @Published var logContent: String = ""
    @Published var selectedSource: PublishLogSource = PublishLogViewModel.loadSelectedSource() {
        didSet {
            UserDefaults.standard.set(selectedSource.rawValue, forKey: Self.selectedSourceDefaultsKey)
            reload()
            restartSelectedSourceMonitoringIfNeeded()
        }
    }

    private var directoryDispatchSource: DispatchSourceFileSystemObject?
    private var selectedFileDispatchSource: DispatchSourceFileSystemObject?
    private var directoryFileDescriptor: Int32 = -1
    private var selectedFileDescriptor: Int32 = -1
    private var isMonitoring = false

    private static func loadSelectedSource() -> PublishLogSource {
        guard
            let rawValue = UserDefaults.standard.string(forKey: selectedSourceDefaultsKey),
            let source = PublishLogSource(rawValue: rawValue)
        else {
            return .sshRsync
        }
        return source
    }

    func reload() {
        logContent = selectedSource.readAll()
    }

    func clear() {
        selectedSource.clear()
        logContent = ""
    }

    func startMonitoring() {
        stopMonitoring()
        isMonitoring = true
        reload()
        startDirectoryMonitoring()
        startSelectedFileMonitoring()
    }

    func stopMonitoring() {
        isMonitoring = false
        stopSelectedFileMonitoring()
        stopDirectoryMonitoring()
    }

    private func restartSelectedSourceMonitoringIfNeeded() {
        guard isMonitoring else { return }
        startSelectedFileMonitoring()
    }

    private func startDirectoryMonitoring() {
        guard directoryDispatchSource == nil else { return }
        let dirPath = NSTemporaryDirectory()
        directoryFileDescriptor = open(dirPath, O_EVTONLY)
        guard directoryFileDescriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: directoryFileDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            guard let self else { return }
            self.startSelectedFileMonitoring()
            self.reload()
        }
        source.setCancelHandler { [weak self] in
            guard let self, self.directoryFileDescriptor >= 0 else { return }
            close(self.directoryFileDescriptor)
            self.directoryFileDescriptor = -1
        }
        source.resume()
        directoryDispatchSource = source
    }

    private func stopDirectoryMonitoring() {
        directoryDispatchSource?.cancel()
        directoryDispatchSource = nil
    }

    private func startSelectedFileMonitoring() {
        stopSelectedFileMonitoring()
        let logPath = selectedSource.logPath
        guard FileManager.default.fileExists(atPath: logPath) else { return }

        selectedFileDescriptor = open(logPath, O_EVTONLY)
        guard selectedFileDescriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: selectedFileDescriptor,
            eventMask: [.write, .extend, .delete, .rename, .revoke],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            guard let self else { return }
            let events = source.data
            self.reload()
            if events.contains(.delete) || events.contains(.rename) || events.contains(.revoke) {
                DispatchQueue.main.async { [weak self] in
                    self?.startSelectedFileMonitoring()
                }
            }
        }
        source.setCancelHandler { [weak self] in
            guard let self, self.selectedFileDescriptor >= 0 else { return }
            close(self.selectedFileDescriptor)
            self.selectedFileDescriptor = -1
        }
        source.resume()
        selectedFileDispatchSource = source
    }

    private func stopSelectedFileMonitoring() {
        selectedFileDispatchSource?.cancel()
        selectedFileDispatchSource = nil
    }
}


private struct PublishLogTextView: NSViewRepresentable {
    @ObservedObject var viewModel: PublishLogViewModel

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


struct PublishLogView: View {
    @ObservedObject fileprivate var viewModel: PublishLogViewModel

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $viewModel.selectedSource) {
                ForEach(PublishLogSource.allCases, id: \.self) { source in
                    Text(source.rawValue).tag(source)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 8)

            Divider()

            if viewModel.selectedSource == .sshRsync {
                SSHKeyWarningRow(logContent: viewModel.logContent)
            }

            PublishLogTextView(viewModel: viewModel)
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
