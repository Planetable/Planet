//
//  PlanetQuickShareWindowController.swift
//  Planet
//
//  Created by Kai on 4/12/23.
//

import Foundation
import Cocoa


class PlanetQuickShareWindowController: NSWindowController {
    override init(window: NSWindow?) {
        let windowSize = NSSize(width: .sheetWidth, height: .sheetHeight)
        let screenSize = NSScreen.main?.frame.size ?? .zero
        let rect = NSMakeRect(screenSize.width/2 - windowSize.width/2, screenSize.height/2 - windowSize.height/2, windowSize.width, windowSize.height)
        let w = PlanetQuickShareWindow(contentRect: rect, styleMask: [], backing: .buffered, defer: true)
        super.init(window: w)
        self.window?.setFrameAutosaveName("Planet Quick Share Sheet")
        NotificationCenter.default.addObserver(forName: .cancelQuickShare, object: nil, queue: nil) { [weak self] _ in
            self?.window?.close()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
    }
}
