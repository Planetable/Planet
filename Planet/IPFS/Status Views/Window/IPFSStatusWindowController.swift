//
//  IPFSStatusWindowController.swift
//  Planet
//

import Foundation
import Cocoa


class IPFSStatusWindowController: NSWindowController {
    init(withOrigin origin: NSPoint) {
        let w = IPFSStatusWindow(withOrigin: origin)
        super.init(window: w)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.window?.contentViewController = nil
        self.window?.windowController = nil
        self.window = nil
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
    }
}
