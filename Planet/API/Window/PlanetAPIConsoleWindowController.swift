//
//  PlanetAPIConsoleWindowController.swift
//  Planet
//

import Foundation
import Cocoa


class PlanetAPIConsoleWindowController: NSWindowController {
    init() {
        let w = PlanetAPIConsoleWindow()
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
