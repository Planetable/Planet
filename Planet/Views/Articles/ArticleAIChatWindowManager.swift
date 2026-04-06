import Cocoa
import Combine
import SwiftUI

private enum ArticleAIChatWindowConfiguration {
    static let contentWidth: CGFloat = 720
    static let contentHeight: CGFloat = 520
    static let minimumWindowSize = NSSize(width: 480, height: 360)

    static func autosaveName(for articleID: UUID) -> String {
        "ArticleAIChat-\(articleID.uuidString)"
    }
}

private extension NSToolbar.Identifier {
    static let articleAIChatToolbar = NSToolbar.Identifier("ArticleAIChatToolbar")
}

@MainActor
final class ArticleAIChatWindowManager {
    static let shared = ArticleAIChatWindowManager()

    private var windowControllers: [UUID: ArticleAIChatWindowController] = [:]

    func open(for article: ArticleModel) {
        if let windowController = windowControllers[article.id] {
            windowController.showWindow(nil)
            windowController.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let windowController = ArticleAIChatWindowController(article: article) { [weak self] articleID in
            self?.windowControllers.removeValue(forKey: articleID)
        }
        windowControllers[article.id] = windowController
        windowController.showWindow(nil)
        windowController.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@MainActor
final class ArticleAIChatWindowController: NSWindowController {
    private let article: ArticleModel
    private let toolbarState = AIChatToolbarState()
    private let onClose: (UUID) -> Void
    private let autosaveName: String
    private var cancellables = Set<AnyCancellable>()

    init(article: ArticleModel, onClose: @escaping (UUID) -> Void) {
        self.article = article
        self.onClose = onClose
        self.autosaveName = ArticleAIChatWindowConfiguration.autosaveName(for: article.id)

        let windowSize = NSSize(
            width: ArticleAIChatWindowConfiguration.contentWidth,
            height: ArticleAIChatWindowConfiguration.contentHeight
        )
        let screenSize = NSScreen.main?.frame.size ?? .zero
        let rect = NSMakeRect(
            screenSize.width / 2 - windowSize.width / 2,
            screenSize.height / 2 - windowSize.height / 2,
            windowSize.width,
            windowSize.height
        )

        let window = NSWindow(
            contentRect: rect,
            styleMask: [.miniaturizable, .closable, .resizable, .titled, .fullSizeContentView, .unifiedTitleAndToolbar],
            backing: .buffered,
            defer: true
        )
        window.isReleasedWhenClosed = false
        window.title = article.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "AI Research Chat" : article.title
        window.titleVisibility = .hidden
        window.minSize = ArticleAIChatWindowConfiguration.minimumWindowSize
        window.maxSize = NSSize(width: screenSize.width, height: .infinity)
        window.toolbarStyle = .unified
        window.contentViewController = ArticleAIChatContentViewController(article: article, toolbarState: toolbarState)
        if !window.setFrameUsingName(autosaveName) {
            window.setFrame(rect, display: false)
        }

        super.init(window: window)

        toolbarState.title = "AI Research Chat"
        toolbarState.singleProviderLabel = "Remote"
        window.setFrameAutosaveName(autosaveName)
        window.delegate = self
        setupToolbar()
        observeToolbarState()
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    private func setupToolbar() {
        guard let window else { return }

        let toolbar = NSToolbar(identifier: .articleAIChatToolbar)
        toolbar.delegate = self
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        toolbar.displayMode = .iconOnly

        window.toolbar = toolbar
        window.toolbar?.validateVisibleItems()
    }

    private func observeToolbarState() {
        toolbarState.$canClearHistory
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.window?.toolbar?.validateVisibleItems()
            }
            .store(in: &cancellables)

        toolbarState.$canDecreaseFont
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.window?.toolbar?.validateVisibleItems()
            }
            .store(in: &cancellables)

        toolbarState.$canIncreaseFont
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.window?.toolbar?.validateVisibleItems()
            }
            .store(in: &cancellables)

    }

    @objc
    private func toolbarItemAction(_ sender: Any) {
        guard let item = sender as? NSToolbarItem else { return }

        switch item.itemIdentifier {
        case .aiChatClear:
            toolbarState.requestClearChat()
        case .aiChatDecreaseFont:
            toolbarState.requestDecreaseFont()
        case .aiChatIncreaseFont:
            toolbarState.requestIncreaseFont()
        default:
            break
        }

        window?.toolbar?.validateVisibleItems()
    }
}

@MainActor
extension ArticleAIChatWindowController: NSToolbarItemValidation {
    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        switch item.itemIdentifier {
        case .aiChatProvider:
            return true
        case .aiChatClear:
            return toolbarState.canClearHistory
        case .aiChatDecreaseFont:
            return toolbarState.canDecreaseFont
        case .aiChatIncreaseFont:
            return toolbarState.canIncreaseFont
        default:
            return false
        }
    }
}

@MainActor
extension ArticleAIChatWindowController: NSToolbarDelegate {
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            .aiChatProvider,
            .flexibleSpace,
            .aiChatClear,
            .aiChatDecreaseFont,
            .aiChatIncreaseFont
        ]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            .space,
            .flexibleSpace,
            .aiChatProvider,
            .aiChatClear,
            .aiChatDecreaseFont,
            .aiChatIncreaseFont
        ]
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        switch itemIdentifier {
        case .aiChatProvider:
            return AIChatProviderToolbarItem(identifier: itemIdentifier, state: toolbarState)
        case .aiChatClear:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.target = self
            item.action = #selector(toolbarItemAction(_:))
            item.label = "Clear Chat History"
            item.paletteLabel = "Clear Chat History"
            item.toolTip = "Clear Chat History"
            item.isBordered = true
            item.image = NSImage(systemSymbolName: "trash", accessibilityDescription: "Clear Chat History")
            return item
        case .aiChatDecreaseFont:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.target = self
            item.action = #selector(toolbarItemAction(_:))
            item.label = "Decrease Font Size"
            item.paletteLabel = "Decrease Font Size"
            item.toolTip = "Decrease Font Size"
            item.isBordered = true
            item.image = NSImage(systemSymbolName: "textformat.size.smaller", accessibilityDescription: "Decrease Font Size")
            return item
        case .aiChatIncreaseFont:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.target = self
            item.action = #selector(toolbarItemAction(_:))
            item.label = "Increase Font Size"
            item.paletteLabel = "Increase Font Size"
            item.toolTip = "Increase Font Size"
            item.isBordered = true
            item.image = NSImage(systemSymbolName: "textformat.size.larger", accessibilityDescription: "Increase Font Size")
            return item
        default:
            return nil
        }
    }
}

@MainActor
extension ArticleAIChatWindowController: NSWindowDelegate {
    func windowDidMove(_ notification: Notification) {
        window?.saveFrame(usingName: autosaveName)
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        window?.saveFrame(usingName: autosaveName)
    }

    func windowWillClose(_ notification: Notification) {
        window?.saveFrame(usingName: autosaveName)
        onClose(article.id)
        window?.delegate = nil
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.contentView = nil
        sender.contentViewController = nil
        return true
    }
}

@MainActor
final class ArticleAIChatContentViewController: NSViewController {
    private let article: ArticleModel
    private let toolbarState: AIChatToolbarState

    init(article: ArticleModel, toolbarState: AIChatToolbarState) {
        self.article = article
        self.toolbarState = toolbarState
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let contentView = NSHostingView(
            rootView: ArticleAIChatView(article: article)
                .environment(\.aiChatToolbarState, toolbarState)
        )
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentView)
        contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        contentView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = .clear
    }
}
