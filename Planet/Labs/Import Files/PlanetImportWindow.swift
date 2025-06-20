//
//  PlanetImportWindow.swift
//  Planet
//
//  Created by Kai on 6/20/25.
//

import Foundation
import Cocoa


class PlanetImportWindow: NSWindow {
    static let windowMinWidth: CGFloat = 520
    static let windowMinHeight: CGFloat = 320

    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: [.miniaturizable, .closable, .resizable, .titled], backing: .buffered, defer: true)
        self.title = "Import Markdown Files"
        self.collectionBehavior = .fullScreenNone
        self.minSize = NSMakeSize(Self.windowMinWidth, Self.windowMinHeight)
        self.contentViewController = PlanetImportViewController()
        self.delegate = self
    }
}


extension PlanetImportWindow: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        DispatchQueue.global(qos: .background).async {
            PlanetImportViewModel.shared.cleanup()
        }
        return true
    }
}
