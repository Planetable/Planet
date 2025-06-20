//
//  PlanetImportWindowController.swift
//  Planet
//
//  Created by Kai on 6/20/25.
//

import Foundation
import Cocoa


class PlanetImportWindowController: NSWindowController {
    override init(window: NSWindow?) {
        let windowSize = NSSize(width: PlanetImportWindow.windowMinWidth, height: PlanetImportWindow.windowMinHeight)
        let screenSize = NSScreen.main?.frame.size ?? .zero
        let rect = NSMakeRect(screenSize.width/2 - windowSize.width/2, screenSize.height/2 - windowSize.height/2, windowSize.width, windowSize.height)
        let w = PlanetImportWindow(contentRect: rect, styleMask: [], backing: .buffered, defer: true)
        super.init(window: w)
        self.window?.setFrameAutosaveName("Import Markdown Files")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func windowDidLoad() {
        super.windowDidLoad()
    }
}
