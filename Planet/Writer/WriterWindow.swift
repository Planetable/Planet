import SwiftUI

class WriterWindow: NSWindow {
    let draft: DraftModel
    let viewModel: WriterViewModel

    init(draft: DraftModel) {
        self.draft = draft
        viewModel = WriterViewModel()
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 320),
            styleMask: [.closable, .miniaturizable, .resizable, .titled, .unifiedTitleAndToolbar, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        try? draft.renderPreview()
        titleVisibility = .visible
        isMovableByWindowBackground = true
        titlebarAppearsTransparent = false
        toolbarStyle = .unified
        let toolbar = NSToolbar(identifier: "WriterToolbar")
        toolbar.displayMode = .iconOnly
        toolbar.delegate = self
        self.toolbar = toolbar
        delegate = self
        isReleasedWhenClosed = false
        contentView = NSHostingView(rootView: WriterView(draft: draft, viewModel: viewModel))
        center()
        setFrameAutosaveName("PlanetWriter-\(draft.planetUUIDString)")
        makeKeyAndOrderFront(nil)
        NotificationCenter.default.addObserver(
            forName: .writerNotification(.close, for: draft),
            object: nil,
            queue: .main
        ) { _ in
            // Close this window
            self.close()
        }
    }

    @objc func send(_ sender: Any?) {
        if draft.title.isEmpty {
            viewModel.isShowingEmptyTitleAlert = true
            return
        }
        do {
            Task {
                try await draft.saveToArticle()
                WriterStore.shared.writers.removeValue(forKey: draft)
            }
            close()
        } catch {
            PlanetStore.shared.alert(title: "Failed to send article: \(error)")
        }
    }

    @objc func insertEmoji(_ sender: Any?) {
        NSApp.orderFrontCharacterPalette(sender)
    }

    @objc func attachPhoto(_ sender: Any?) {
        viewModel.chooseImages()
    }

    @objc func attachVideo(_ sender: Any?) {
        viewModel.chooseVideo()
    }

    @objc func attachAudio(_ sender: Any?) {
        viewModel.chooseAudio()
    }
}

extension NSToolbarItem.Identifier {
    static let send = NSToolbarItem.Identifier("send")
    static let insertEmoji = NSToolbarItem.Identifier("insertEmoji")
    static let attachPhoto = NSToolbarItem.Identifier("attachPhoto")
    static let attachVideo = NSToolbarItem.Identifier("attachVideo")
    static let attachAudio = NSToolbarItem.Identifier("attachAudio")
}

extension WriterWindow: NSToolbarDelegate {
    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        switch itemIdentifier {
        case .send:
            let title = NSLocalizedString("Send", comment: "Send")
            return makeToolbarButton(
                itemIdentifier: .send,
                title: title,
                image: NSImage(systemSymbolName: "paperplane", accessibilityDescription: "Send")!,
                selector: "send:"
            )
        case .insertEmoji:
            let title = NSLocalizedString("Insert Emoji", comment: "Insert Emoji")
            return makeToolbarButton(
                itemIdentifier: .insertEmoji,
                title: title,
                image: NSImage(systemSymbolName: "face.smiling", accessibilityDescription: "Insert Emoji")!,
                selector: "insertEmoji:"
            )
        case .attachPhoto:
            let title = NSLocalizedString("Attach Photo", comment: "Attach Photo")
            return makeToolbarButton(
                itemIdentifier: .attachPhoto,
                title: title,
                image: NSImage(systemSymbolName: "photo.on.rectangle", accessibilityDescription: "Attach Photo")!,
                selector: "attachPhoto:"
            )
        case .attachVideo:
            let title = NSLocalizedString("Attach Video", comment: "Attach Video")
            return makeToolbarButton(
                itemIdentifier: .attachVideo,
                title: title,
                image: NSImage(systemSymbolName: "video.badge.plus", accessibilityDescription: "Attach Video")!,
                selector: "attachVideo:"
            )
        case .attachAudio:
            let title = NSLocalizedString("Attach Audio", comment: "Attach Audio")
            return makeToolbarButton(
                itemIdentifier: .attachAudio,
                title: title,
                image: NSImage(systemSymbolName: "waveform.badge.plus", accessibilityDescription: "Attach Audio")!,
                selector: "attachAudio:"
            )

        default:
            return nil
        }
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.send, .insertEmoji, .attachPhoto, .attachVideo, .attachAudio, .flexibleSpace]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.send, .insertEmoji, .attachPhoto, .attachVideo, .attachAudio]
    }

    func toolbarWillAddItem(_ notification: Notification) {
        guard let _ = notification.userInfo?["item"] as? NSToolbarItem else {
            return
        }
    }

    func toolbarDidRemoveItem(_ notification: Notification) {
        guard let _ = notification.userInfo?["item"] as? NSToolbarItem else {
            return
        }
    }

    func makeToolbarButton(
        itemIdentifier: NSToolbarItem.Identifier,
        title: String,
        image: NSImage,
        selector: String
    ) -> NSToolbarItem {
        let toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)
        toolbarItem.autovalidates = true

        switch itemIdentifier {
        case .send:
            toolbarItem.isNavigational = true
        default:
            toolbarItem.isNavigational = false
        }

        let button = NSButton(frame: CGRect(x: 0, y: 0, width: 45, height: 28))
        button.widthAnchor.constraint(equalToConstant: button.frame.width).isActive = true
        button.heightAnchor.constraint(equalToConstant: button.frame.height).isActive = true
        button.bezelStyle = .texturedRounded
        button.image = image
        button.action = Selector((selector))
        toolbarItem.view = button

        // toolbarItem.isBordered = true
        // toolbarItem.image = image
        // toolbarItem.action = Selector((selector))

        toolbarItem.toolTip = title
        toolbarItem.label = title
        return toolbarItem
    }
}

extension WriterWindow: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if (viewModel.madeDiscardChoice) {
            return true
        }
        let draftCurrentContentSHA256 = draft.contentSHA256()
        debugPrint("Draft contentSHA256: current - \(draftCurrentContentSHA256) / initial - \(draft.initialContentSHA256)")
        if draftCurrentContentSHA256 != draft.initialContentSHA256 {
            viewModel.isShowingDiscardConfirmation = true
            return false
        }
        debugPrint("Draft Window Should Close: \(viewModel)")
        return true
    }

    func windowWillClose(_ notification: Notification) {
        WriterStore.shared.writers.removeValue(forKey: draft)
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        Task { @MainActor in
            KeyboardShortcutHelper.shared.activeWriterWindow = self
        }
    }
    
    func windowDidResignKey(_ notification: Notification) {
        Task { @MainActor in
            KeyboardShortcutHelper.shared.activeWriterWindow = nil
        }
    }
}
