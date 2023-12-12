//
//  AppSettingsWindowController.swift
//  Croptop
//

import Foundation
import Cocoa


class AppSettingsWindowController: NSWindowController {
    override init(window: NSWindow?) {
        let windowSize = NSSize(width: 480, height: 320)
        let screenSize = NSScreen.main?.frame.size ?? .zero
        let rect = NSMakeRect(screenSize.width/2 - windowSize.width/2, screenSize.height/2 - windowSize.height/2, windowSize.width, windowSize.height)
        let w = NSWindow(contentRect: rect, styleMask: [.miniaturizable, .closable, .titled], backing: .buffered, defer: true)
        super.init(window: w)
        self.window?.setFrameAutosaveName(.liteAppName + " Settings")
        self.window?.title = "Settings"
        self.window?.minSize = windowSize
        self.window?.maxSize = windowSize
        self.window?.contentViewController = AppSettingsViewController()
        self.window?.setFrame(rect, display: true)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    deinit {
    }

    override func windowDidLoad() {
        super.windowDidLoad()
    }
}
