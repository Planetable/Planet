import SwiftUI
import Cocoa


class WriterWindow: NSWindow {
    let draft: DraftModel
    let viewModel: WriterViewModel

    init(draft: DraftModel) {
        self.draft = draft
        self.viewModel = WriterViewModel()
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 320),
            styleMask: [.closable, .miniaturizable, .resizable, .titled, .unifiedTitleAndToolbar, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        try? self.draft.renderPreview()
        self.titleVisibility = .visible
        self.isMovableByWindowBackground = true
        self.titlebarAppearsTransparent = false
        self.toolbarStyle = .unified
        self.isReleasedWhenClosed = false
        let toolbar = NSToolbar(identifier: "WriterToolbar")
        toolbar.displayMode = .iconOnly
        toolbar.delegate = self
        self.toolbar = toolbar
        self.delegate = self
        self.contentView = NSHostingView(rootView: WriterView(draft: draft, viewModel: viewModel))
        self.center()
        self.setFrameAutosaveName("PlanetWriter-\(draft.planetUUIDString)")
        self.makeKeyAndOrderFront(nil)
        // MARK: TODO: Add a offset if there's an opened writer window in the center.
    }

    deinit {
        debugPrint("WriterWindow deinit.")
    }

    @objc func send(_ sender: Any?) {
        do {
            try draft.saveToArticle()
            Task { @MainActor in
                WriterStore.shared.closeWriterWindow(byDraftID: self.draft.id)
            }
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

        // For the send button, add debouncing to prevent double-clicks
        if itemIdentifier == .send {
            // Use a custom send button class with debounce protection
            let debounceButton = DebounceButton(frame: CGRect(x: 0, y: 0, width: 45, height: 28))
            debounceButton.widthAnchor.constraint(equalToConstant: debounceButton.frame.width).isActive = true
            debounceButton.heightAnchor.constraint(equalToConstant: debounceButton.frame.height).isActive = true
            debounceButton.bezelStyle = .texturedRounded
            debounceButton.image = image
            debounceButton.action = Selector((selector))
            debounceButton.target = self
            toolbarItem.view = debounceButton
        } else {
            let button = NSButton(frame: CGRect(x: 0, y: 0, width: 45, height: 28))
            button.widthAnchor.constraint(equalToConstant: button.frame.width).isActive = true
            button.heightAnchor.constraint(equalToConstant: button.frame.height).isActive = true
            button.bezelStyle = .texturedRounded
            button.image = image
            button.action = Selector((selector))
            button.target = self
            toolbarItem.view = button
        }

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
        if let target = draft.target {
            switch target {
            case .myPlanet(let wrapper):
                let planet = wrapper.value
                if draft.isEmpty {
                    debugPrint("Draft for planet \(planet.name) is empty, delete the draft now")
                    try? draft.delete()
                }
            default:
                break
            }
        }
        return true
    }

    func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            WriterStore.shared.closeWriterWindow(byDraftID: self.draft.id)
        }
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

class DebounceButton: NSButton {
    private var isProcessingClick = false
    private let debounceTime: TimeInterval = 1.0

    override func sendAction(_ action: Selector?, to target: Any?) -> Bool {
        guard !isProcessingClick else { return false }

        isProcessingClick = true

        // Schedule re-enabling of the button
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceTime) { [weak self] in
            self?.isProcessingClick = false
        }

        return super.sendAction(action, to: target)
    }
}
