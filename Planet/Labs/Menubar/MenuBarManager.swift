import AppKit
import SwiftUI

class MenuBarManager: NSObject {
    static let shared = MenuBarManager()

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

        if let icon = NSImage(systemSymbolName: "cricket.ball.fill", accessibilityDescription: nil) {
            icon.size = NSSize(width: 18, height: 18)
            icon.isTemplate = true
            button.image = icon
        } else {
            button.title = "🪐"
        }

        button.action = #selector(statusBarButtonClicked(sender:))
        button.target = self

        // Build the menu
        let menu = NSMenu()

        let aboutMenuItem = NSMenuItem(
            title: "About",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutMenuItem.target = self
        menu.addItem(aboutMenuItem)

        // Add Settings Menu Item
        let settingsMenuItem = NSMenuItem(
            title: "Show Main Window",
            action: #selector(showMainWindow),
            keyEquivalent: ""
        )
        settingsMenuItem.target = self
        menu.addItem(settingsMenuItem)

        // Separator before Toggle Item
        menu.addItem(NSMenuItem.separator())

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

    @objc func toggleMenuBarPreference() {
        let currentSetting = UserDefaults.standard.bool(
            forKey: .settingsShowMenuBarIcon
        )
        let newSetting = !currentSetting
        UserDefaults.standard.set(newSetting, forKey: .settingsShowMenuBarIcon)
        updateMenuBarVisibility(newSetting)
    }

    @objc func statusBarButtonClicked(sender: NSStatusBarButton) {}

    @objc func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc func showMainWindow() {
        let app = NSApplication.shared
        let current = app.activationPolicy()
        guard let window = app.windows.first(where: { $0.className == "SwiftUI.AppKitWindow" }) else {
            return
        }
        if !window.canBecomeMain || !window.isVisible {
            NSWorkspace.shared.open(.mainEvent)
            NSApplication.shared.setActivationPolicy(current)
        }
        window.makeKeyAndOrderFront(nil)
    }
}
