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
    private static let maxVisibleBytes = 256 * 1024
    private static let reloadDebounceInterval: DispatchTimeInterval = .milliseconds(100)
    private var logContent: String = ""
    @Published var attributedLogContent: NSAttributedString = NSAttributedString()
    @Published var contentVersion: Int = 0
    @Published var hasSSHKeyError: Bool = false
    @Published var selectedSource: PublishLogSource = PublishLogViewModel.loadSelectedSource() {
        didSet {
            UserDefaults.standard.set(selectedSource.rawValue, forKey: Self.selectedSourceDefaultsKey)
            reload()
            restartSelectedSourceMonitoringIfNeeded()
        }
    }

    private var selectedFileDispatchSource: DispatchSourceFileSystemObject?
    private var selectedFileDescriptor: Int32 = -1
    private var isMonitoring = false
    private var reloadWorkItem: DispatchWorkItem?
    private let ioQueue = DispatchQueue(label: "xyz.planetable.PublishLogViewModel.io", qos: .utility)
    private static let timestampRegex = try! NSRegularExpression(pattern: "^\\[[^\\]]+\\]", options: [])

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
        scheduleReload(immediate: true)
    }

    func clear() {
        reloadWorkItem?.cancel()
        selectedSource.clear()
        logContent = ""
        attributedLogContent = Self.buildAttributedString(from: "")
        contentVersion += 1
        hasSSHKeyError = false
    }

    func startMonitoring() {
        stopMonitoring()
        isMonitoring = true
        reload()
        startSelectedFileMonitoring()
    }

    func stopMonitoring() {
        isMonitoring = false
        reloadWorkItem?.cancel()
        stopSelectedFileMonitoring()
    }

    private func restartSelectedSourceMonitoringIfNeeded() {
        guard isMonitoring else { return }
        ensureLogFileExists(for: selectedSource)
        startSelectedFileMonitoring()
        scheduleReload(immediate: true)
    }

    private func startSelectedFileMonitoring() {
        stopSelectedFileMonitoring()
        let monitoredSource = selectedSource
        let logPath = monitoredSource.logPath
        ensureLogFileExists(for: monitoredSource)

        selectedFileDescriptor = open(logPath, O_EVTONLY)
        guard selectedFileDescriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: selectedFileDescriptor,
            eventMask: [.write, .extend, .delete, .rename, .revoke],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            guard let self else { return }
            guard self.selectedSource == monitoredSource else { return }
            let events = source.data
            if events.contains(.delete) || events.contains(.rename) || events.contains(.revoke) {
                DispatchQueue.main.async { [weak self] in
                    self?.ensureLogFileExists(for: monitoredSource)
                    self?.stopSelectedFileMonitoring()
                    self?.startSelectedFileMonitoring()
                    self?.scheduleReload(immediate: true)
                }
            } else {
                self.scheduleReload()
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

    private func scheduleReload(immediate: Bool = false) {
        reloadWorkItem?.cancel()
        let source = selectedSource
        let workItem = DispatchWorkItem { [weak self] in
            self?.loadContent(for: source)
        }
        reloadWorkItem = workItem
        if immediate {
            DispatchQueue.main.async(execute: workItem)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.reloadDebounceInterval, execute: workItem)
        }
    }

    private func loadContent(for source: PublishLogSource) {
        let logPath = source.logPath
        let checkSSHKeyErrors = (source == .sshRsync)
        ioQueue.async { [weak self] in
            let content = Self.readRecentContent(from: logPath, maxBytes: Self.maxVisibleBytes)
            let attributed = Self.buildAttributedString(from: content)
            let keyError: Bool
            if checkSSHKeyErrors {
                keyError = content.contains("Operation not permitted")
                    || content.contains("Permission denied")
                    || content.contains("identity file")
                    || content.contains("Host key verification failed")
            } else {
                keyError = false
            }
            DispatchQueue.main.async {
                guard let self, self.selectedSource == source else { return }
                if self.logContent != content {
                    self.logContent = content
                    self.attributedLogContent = attributed
                    self.contentVersion += 1
                    self.hasSSHKeyError = keyError
                }
            }
        }
    }

    private static func readRecentContent(from path: String, maxBytes: Int) -> String {
        guard let handle = FileHandle(forReadingAtPath: path) else { return "" }
        defer { handle.closeFile() }

        let fileSize = handle.seekToEndOfFile()
        let startOffset = fileSize > UInt64(maxBytes) ? fileSize - UInt64(maxBytes) : 0
        handle.seek(toFileOffset: startOffset)

        let data = handle.readDataToEndOfFile()
        var content = String(decoding: data, as: UTF8.self)
        if startOffset > 0, let newlineIndex = content.firstIndex(of: "\n") {
            content.removeSubrange(content.startIndex...newlineIndex)
        }
        return content
    }

    private static func buildAttributedString(from content: String) -> NSAttributedString {
        let fontSize: CGFloat = 12
        let baseFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let boldFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)

        guard !content.isEmpty else {
            return NSAttributedString(
                string: "No log entries yet.",
                attributes: [.font: baseFont, .foregroundColor: NSColor.secondaryLabelColor]
            )
        }

        let result = NSMutableAttributedString()
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)

        for line in lines {
            let line = String(line)
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

            if let match = timestampRegex.firstMatch(in: line, options: [], range: fullRange) {
                attrLine.addAttribute(.foregroundColor, value: NSColor.placeholderTextColor, range: match.range)
            }

            if line.contains("[WARNING]") {
                attrLine.addAttribute(.foregroundColor, value: NSColor.systemYellow, range: fullRange)
                attrLine.addAttribute(.font, value: boldFont, range: fullRange)
            } else if line.contains("[ERROR]") {
                if let range = nsLine.range(of: "[ERROR]").asOptional {
                    attrLine.addAttribute(.foregroundColor, value: NSColor.systemRed, range: range)
                    attrLine.addAttribute(.font, value: boldFont, range: range)
                }
            }

            result.append(attrLine)
        }

        return NSAttributedString(attributedString: result)
    }

    private func ensureLogFileExists(for source: PublishLogSource) {
        let logPath = source.logPath
        let logURL = URL(fileURLWithPath: logPath, isDirectory: false)
        let directoryURL = logURL.deletingLastPathComponent()

        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        if !FileManager.default.fileExists(atPath: logPath) {
            FileManager.default.createFile(atPath: logPath, contents: nil)
        }
    }
}


private struct PublishLogTextView: NSViewRepresentable {
    @ObservedObject var viewModel: PublishLogViewModel

    class Coordinator {
        var lastVersion: Int = -1
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
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
        let currentVersion = viewModel.contentVersion
        guard context.coordinator.lastVersion != currentVersion else { return }
        context.coordinator.lastVersion = currentVersion

        let shouldAutoScroll = Self.shouldAutoScroll(nsView)
        textView.textStorage?.setAttributedString(viewModel.attributedLogContent)
        if shouldAutoScroll {
            textView.scrollToEndOfDocument(nil)
        }
    }

    private static func shouldAutoScroll(_ scrollView: NSScrollView) -> Bool {
        guard let documentView = scrollView.documentView else { return true }
        let visibleRect = scrollView.contentView.documentVisibleRect
        return documentView.bounds.maxY - visibleRect.maxY < 80
    }
}


private extension NSRange {
    var asOptional: NSRange? {
        location == NSNotFound ? nil : self
    }
}


private struct SSHKeyWarningRow: View {
    let hasKeyError: Bool

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
                SSHKeyWarningRow(hasKeyError: viewModel.hasSSHKeyError)
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
