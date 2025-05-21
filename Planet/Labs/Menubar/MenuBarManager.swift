import AppKit
import SwiftUI

class MenuBarManager: NSObject {
    enum MenuItemTag: Int {
        case status = 1
        case menubar
        case dock
    }

    static let shared = MenuBarManager()

    private var statusMenuTitle: String {
        "IPFS Gateway: \(IPFSState.shared.online ? "Online" : "Offline")"
    }

    private var dockMenuTitle: String {
        let current = UserDefaults.standard.bool(
            forKey: .settingsHideDockIcon
        )
        return "\(current ? "Show" : "Hide") from Dock"
    }

    private var statusItem: NSStatusItem?

    init(defaults: UserDefaults = .standard) {
        if defaults.value(forKey: .settingsShowMenuBarIcon) == nil {
            defaults.set(true, forKey: .settingsShowMenuBarIcon)
        }
        if defaults.value(forKey: .settingsHideDockIcon) == nil {
            defaults.set(false, forKey: .settingsHideDockIcon)
        }
    }

    func setupMenuBar() {
        updateMenuBarVisibility(UserDefaults.standard.bool(forKey: .settingsShowMenuBarIcon))
        updateDockIconVisibility(UserDefaults.standard.bool(forKey: .settingsHideDockIcon))
    }

    func updateMenuBarVisibility(_ shouldShow: Bool) {
        DispatchQueue.main.async {
            if shouldShow {
                if self.statusItem == nil {
                    self.createMenuBarIcon()
                } else {
                    self.statusItem?.isVisible = true
                }
            } else {
                if self.statusItem != nil {
                    self.removeMenuBarIcon()
                }
                // Activate app window only when switching to regular mode
                if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    window.makeKeyAndOrderFront(nil)
                }
            }
        }
    }

    func updateDockIconVisibility(_ shouldHide: Bool) {
        if shouldHide {
            NSApplication.shared.setActivationPolicy(.accessory)
        } else {
            NSApplication.shared.setActivationPolicy(.regular)
        }
    }

    private func createMenuBarIcon() {
        guard statusItem == nil else {
            return
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let button = statusItem?.button else {
            if let item = statusItem { NSStatusBar.system.removeStatusItem(item) }
            statusItem = nil
            return
        }

        if let icon = NSImage(systemSymbolName: "globe.asia.australia", accessibilityDescription: nil) {
            icon.size = NSSize(width: 20, height: 20)
            icon.isTemplate = true
            button.image = icon
        } else {
            button.title = "🪐"
        }

        // Build the menu
        let menu = NSMenu()
        menu.delegate = self

        let statusMenuItem = NSMenuItem(title: "Status", action: nil, keyEquivalent: "")
        statusMenuItem.title = statusMenuTitle
        statusMenuItem.tag = MenuItemTag.status.rawValue
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())

        let toggleMenubarItem = NSMenuItem(
            title: "Hide from Menubar",
            action: #selector(hideMenubar),
            keyEquivalent: ""
        )
        toggleMenubarItem.tag = MenuItemTag.menubar.rawValue
        toggleMenubarItem.target = self
        menu.addItem(toggleMenubarItem)

        let toggleDockMenuItem = NSMenuItem(
            title: dockMenuTitle,
            action: #selector(toggleDockIcon),
            keyEquivalent: ""
        )
        toggleDockMenuItem.tag = MenuItemTag.dock.rawValue
        toggleDockMenuItem.target = self
        menu.addItem(toggleDockMenuItem)

        menu.addItem(NSMenuItem.separator())

        let aboutMenuItem = NSMenuItem(
            title: "About...",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutMenuItem.target = self
        menu.addItem(aboutMenuItem)

        menu.addItem(NSMenuItem(
            title: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        )

        statusItem?.menu = menu
        statusItem?.isVisible = true
    }

    private func removeMenuBarIcon() {
        guard let item = statusItem else {
            return
        }
        NSStatusBar.system.removeStatusItem(item)
        statusItem = nil
    }

    // --- Actions ---

    @objc func hideMenubar() {
        UserDefaults.standard.set(false, forKey: .settingsShowMenuBarIcon)
        updateMenuBarVisibility(false)
    }

    @objc func showAbout() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        NSApplication.shared.orderFrontStandardAboutPanel(nil)
    }

    @objc func toggleDockIcon() {
        let current = UserDefaults.standard.bool(forKey: .settingsHideDockIcon)
        updateDockIconVisibility(!current)
        UserDefaults.standard.setValue(!current, forKey: .settingsHideDockIcon)
    }
}

extension MenuBarManager: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        if let item = menu.item(withTag: MenuItemTag.status.rawValue) {
            item.title = statusMenuTitle
        }
        if let item = menu.item(withTag: MenuItemTag.dock.rawValue) {
            item.title = dockMenuTitle
        }
    }
}
