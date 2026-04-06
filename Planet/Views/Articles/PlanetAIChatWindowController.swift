import Cocoa
import Combine
import SwiftUI

private enum PlanetAIChatWindowConfiguration {
    static let windowAutosaveName = "Planet AI Chat Window"
    static let containerIdentifier = "PlanetAIChatContainerViewController"
    static let contentWidth: CGFloat = 720
    static let contentHeight: CGFloat = 560
    static let centerToolbarWidth: CGFloat = 260
    static let trailingToolbarWidth: CGFloat = 150
}

enum AIChatToolbarCommand {
    case selectProvider(String)
    case clearHistory
    case decreaseFont
    case increaseFont
}

@MainActor
final class AIChatToolbarState: ObservableObject {
    let commands = PassthroughSubject<AIChatToolbarCommand, Never>()

    @Published var title: String = "AI Chat"
    @Published var selectedProviderRawValue: String = "Remote"
    @Published var isRemoteAvailable: Bool = false
    @Published var isOnDeviceAvailable: Bool = false
    @Published var remoteProviderLabel: String = ""
    @Published var singleProviderLabel: String = ""
    @Published var isSending: Bool = false
    @Published var canClearHistory: Bool = false
    @Published var canDecreaseFont: Bool = true
    @Published var canIncreaseFont: Bool = true

    func requestProviderSelection(_ rawValue: String) {
        selectedProviderRawValue = rawValue
        commands.send(.selectProvider(rawValue))
    }

    func requestClearChat() {
        commands.send(.clearHistory)
    }

    func requestDecreaseFont() {
        commands.send(.decreaseFont)
    }

    func requestIncreaseFont() {
        commands.send(.increaseFont)
    }
}

@MainActor
final class AIChatProviderToolbarItem: NSToolbarItem {
    private let state: AIChatToolbarState
    private var cancellables = Set<AnyCancellable>()

    private lazy var segmentedControl: NSSegmentedControl = {
        let control = NSSegmentedControl(labels: ["Remote", "On-Device"], trackingMode: .selectOne, target: self, action: #selector(providerChanged(_:)))
        control.controlSize = .regular
        return control
    }()

    private lazy var statusLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: NSFont.systemFontSize)
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        return label
    }()

    init(identifier: NSToolbarItem.Identifier, state: AIChatToolbarState) {
        self.state = state
        super.init(itemIdentifier: identifier)
        subscribe()
        updateView()
    }

    @objc
    private func providerChanged(_ sender: NSSegmentedControl) {
        let rawValue = sender.selectedSegment == 1 ? "On-Device" : "Remote"
        state.requestProviderSelection(rawValue)
    }

    private func subscribe() {
        state.$selectedProviderRawValue
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateView() }
            .store(in: &cancellables)

        state.$isRemoteAvailable
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateView() }
            .store(in: &cancellables)

        state.$isOnDeviceAvailable
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateView() }
            .store(in: &cancellables)

        state.$remoteProviderLabel
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateView() }
            .store(in: &cancellables)

        state.$singleProviderLabel
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateView() }
            .store(in: &cancellables)
    }

    private func updateView() {
        if state.isRemoteAvailable && state.isOnDeviceAvailable {
            segmentedControl.setLabel(state.remoteProviderLabel, forSegment: 0)
            segmentedControl.setLabel("On-Device", forSegment: 1)
            segmentedControl.selectedSegment = state.selectedProviderRawValue == "On-Device" ? 1 : 0
            segmentedControl.sizeToFit()
            segmentedControl.frame.size = segmentedControl.fittingSize
            if view !== segmentedControl {
                view = segmentedControl
            }
        } else {
            statusLabel.stringValue = state.singleProviderLabel
            statusLabel.sizeToFit()
            statusLabel.frame.size = statusLabel.fittingSize
            if view !== statusLabel {
                view = statusLabel
            }
        }
    }
}

private extension NSToolbar.Identifier {
    static let planetAIChatToolbar = NSToolbar.Identifier("PlanetAIChatToolbar")
}

extension NSToolbarItem.Identifier {
    static let aiChatProvider = NSToolbarItem.Identifier("AIChatProviderItem")
    static let aiChatClear = NSToolbarItem.Identifier("AIChatClearItem")
    static let aiChatDecreaseFont = NSToolbarItem.Identifier("AIChatDecreaseFontItem")
    static let aiChatIncreaseFont = NSToolbarItem.Identifier("AIChatIncreaseFontItem")
    static let planetAIChatSidebar = NSToolbarItem.Identifier("PlanetAIChatSidebarItem")
    static let planetAIChatSidebarSeparator = NSToolbarItem.Identifier("PlanetAIChatSidebarSeparatorItem")
    static let planetAIChatNewSession = NSToolbarItem.Identifier("PlanetAIChatNewSessionItem")
}

@MainActor
final class PlanetAIChatWindowController: NSWindowController {
    private var cancellables = Set<AnyCancellable>()
    private let toolbarState = AIChatToolbarState()

    override init(window: NSWindow?) {
        let windowSize = NSSize(
            width: PlanetUI.WINDOW_SIDEBAR_WIDTH_MIN + PlanetAIChatWindowConfiguration.contentWidth,
            height: max(PlanetUI.WINDOW_CONTENT_HEIGHT_MIN, PlanetAIChatWindowConfiguration.contentHeight)
        )
        let screenSize = NSScreen.main?.frame.size ?? .zero
        let rect = NSMakeRect(
            screenSize.width / 2 - windowSize.width / 2,
            screenSize.height / 2 - windowSize.height / 2,
            windowSize.width,
            windowSize.height
        )
        let chatWindow = PlanetAIChatWindow(
            toolbarState: toolbarState,
            contentRect: rect,
            styleMask: [.miniaturizable, .closable, .resizable, .titled, .fullSizeContentView, .unifiedTitleAndToolbar],
            backing: .buffered,
            defer: true
        )
        let defaultFrame = rect
        chatWindow.minSize = windowSize
        chatWindow.maxSize = NSSize(width: screenSize.width, height: .infinity)
        chatWindow.toolbarStyle = .unified
        if !chatWindow.setFrameUsingName(PlanetAIChatWindowConfiguration.windowAutosaveName) {
            chatWindow.setFrame(defaultFrame, display: false)
        }
        super.init(window: chatWindow)
        setupToolbar()
        observeSessionStore()
        toolbarState.title = "Planet AI Chat"
        toolbarState.singleProviderLabel = "Remote"
        window?.setFrameAutosaveName(PlanetAIChatWindowConfiguration.windowAutosaveName)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    private func setupToolbar() {
        guard let window else { return }

        let toolbar = NSToolbar(identifier: .planetAIChatToolbar)
        toolbar.delegate = self
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        toolbar.displayMode = .iconOnly

        window.title = "Planet AI Chat"
        window.titleVisibility = .hidden
        window.toolbar = toolbar
        window.toolbar?.validateVisibleItems()
    }

    private func observeSessionStore() {
        let store = PlanetAIChatSessionStore.shared

        store.$sessions
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.window?.toolbar?.validateVisibleItems()
            }
            .store(in: &cancellables)

        store.$selectedSessionID
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.window?.toolbar?.validateVisibleItems()
            }
            .store(in: &cancellables)

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
        case .planetAIChatSidebar:
            if let viewController = window?.contentViewController as? PlanetAIChatContainerViewController {
                viewController.toggleSidebar(sender)
            }
        case .planetAIChatNewSession:
            _ = PlanetAIChatSessionStore.shared.createSession()
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
extension PlanetAIChatWindowController: NSToolbarItemValidation {
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
        case .planetAIChatSidebar:
            return true
        case .planetAIChatSidebarSeparator:
            return true
        case .planetAIChatNewSession:
            return true
        default:
            return false
        }
    }
}

@MainActor
extension PlanetAIChatWindowController: NSToolbarDelegate {
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            .planetAIChatSidebar,
            .flexibleSpace,
            .planetAIChatNewSession,
            .planetAIChatSidebarSeparator,
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
            .aiChatIncreaseFont,
            .planetAIChatSidebar,
            .planetAIChatSidebarSeparator,
            .planetAIChatNewSession
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
        case .planetAIChatSidebar:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.target = self
            item.action = #selector(toolbarItemAction(_:))
            item.label = "Toggle Sidebar"
            item.paletteLabel = "Toggle Sidebar"
            item.toolTip = "Toggle Sidebar"
            item.isBordered = true
            item.image = NSImage(systemSymbolName: "sidebar.left", accessibilityDescription: "Toggle Sidebar")
            return item
        case .planetAIChatSidebarSeparator:
            if let viewController = window?.contentViewController as? PlanetAIChatContainerViewController {
                return NSTrackingSeparatorToolbarItem(
                    identifier: itemIdentifier,
                    splitView: viewController.splitView,
                    dividerIndex: 0
                )
            }
            return nil
        case .planetAIChatNewSession:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.target = self
            item.action = #selector(toolbarItemAction(_:))
            item.label = "New Session"
            item.paletteLabel = "New Session"
            item.toolTip = "New Session"
            item.isBordered = true
            item.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "New Session")
            return item
        default:
            return nil
        }
    }
}

@MainActor
final class PlanetAIChatWindow: NSWindow {
    init(
        toolbarState: AIChatToolbarState,
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        collectionBehavior = .fullScreenNone
        title = "Planet AI Chat"
        titleVisibility = .hidden
        titlebarAppearsTransparent = false
        toolbarStyle = .unified
        contentViewController = PlanetAIChatContainerViewController(toolbarState: toolbarState)
        delegate = self
    }

    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        fatalError("Use init(toolbarState:contentRect:styleMask:backing:defer:)")
    }
}

extension PlanetAIChatWindow: NSWindowDelegate {
    func windowDidMove(_ notification: Notification) {
        saveFrame(usingName: PlanetAIChatWindowConfiguration.windowAutosaveName)
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        saveFrame(usingName: PlanetAIChatWindowConfiguration.windowAutosaveName)
    }

    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? PlanetAIChatWindow {
            window.saveFrame(usingName: PlanetAIChatWindowConfiguration.windowAutosaveName)
            window.delegate = nil
            PlanetAppDelegate.shared.planetAIChatWindowController = nil
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.contentView = nil
        sender.contentViewController = nil
        return true
    }
}

@MainActor
final class PlanetAIChatContainerViewController: NSSplitViewController {
    private let toolbarState: AIChatToolbarState
    lazy var sidebarViewController = PlanetAIChatSidebarViewController()
    lazy var contentViewController = PlanetAIChatContentViewController(toolbarState: toolbarState)

    init(toolbarState: AIChatToolbarState) {
        self.toolbarState = toolbarState
        super.init(nibName: nil, bundle: nil)
        setupViewControllers()
        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    private func setupViewControllers() {
        view.wantsLayer = true
        view.layer?.backgroundColor = .clear

        splitView.dividerStyle = .thin
        sidebarViewController.view.widthAnchor.constraint(greaterThanOrEqualToConstant: PlanetUI.WINDOW_SIDEBAR_WIDTH_MIN).isActive = true
        contentViewController.view.widthAnchor.constraint(greaterThanOrEqualToConstant: PlanetUI.WINDOW_CONTENT_WIDTH_MIN).isActive = true
    }

    private func setupLayout() {
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarViewController)
        sidebarItem.canCollapse = true
        sidebarItem.titlebarSeparatorStyle = .automatic
        sidebarItem.holdingPriority = .defaultLow
        sidebarItem.allowsFullHeightLayout = true
        sidebarItem.minimumThickness = PlanetUI.WINDOW_SIDEBAR_WIDTH_MIN
        sidebarItem.maximumThickness = PlanetUI.WINDOW_SIDEBAR_WIDTH_MAX
        addSplitViewItem(sidebarItem)

        let contentItem = NSSplitViewItem(viewController: contentViewController)
        contentItem.titlebarSeparatorStyle = .line
        addSplitViewItem(contentItem)

        splitView.autosaveName = NSSplitView.AutosaveName(stringLiteral: PlanetAIChatWindowConfiguration.containerIdentifier)
        splitView.identifier = NSUserInterfaceItemIdentifier(PlanetAIChatWindowConfiguration.containerIdentifier)

        let splitAutosaveKey = "NSSplitView Subview Frames \(PlanetAIChatWindowConfiguration.containerIdentifier)"
        if UserDefaults.standard.object(forKey: splitAutosaveKey) == nil {
            DispatchQueue.main.async { [weak self] in
                self?.splitView.setPosition(PlanetUI.WINDOW_SIDEBAR_WIDTH_MIN, ofDividerAt: 0)
            }
        }
    }
}

@MainActor
final class PlanetAIChatSidebarViewController: NSViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let contentView = NSHostingView(
            rootView: PlanetAIChatSessionSidebar()
                .environmentObject(PlanetAIChatSessionStore.shared)
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

@MainActor
final class PlanetAIChatContentViewController: NSViewController {
    private let toolbarState: AIChatToolbarState

    init(toolbarState: AIChatToolbarState) {
        self.toolbarState = toolbarState
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let contentView = NSHostingView(
            rootView: PlanetAIChatSessionContentView()
                .environmentObject(PlanetAIChatSessionStore.shared)
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
