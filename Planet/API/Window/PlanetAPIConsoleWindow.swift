//
//  PlanetAPIConsoleWindow.swift
//  Planet
//

import Foundation
import Cocoa


class PlanetAPIConsoleWindow: NSWindow {
    static let minWidth: CGFloat = 480
    static let minHeight: CGFloat = 320
    static let updateConsoleWindowTitle = Notification.Name("APIConsoleUpdateWindowTitle")

    init() {
        let windowOrigin: NSPoint = {
            let screenFrame = NSScreen.main!.frame
            let x = (screenFrame.width - Self.minWidth) / 2
            let y = (screenFrame.height - Self.minHeight) / 2
            return NSPoint(x: x, y: y)
        }()
        super.init(contentRect: NSRect(origin: windowOrigin, size: .init(width: Self.minWidth, height: Self.minHeight)), styleMask: [.closable, .titled, .fullSizeContentView, .resizable, .miniaturizable], backing: .buffered, defer: true)
        self.minSize = CGSize(width: Self.minWidth, height: Self.minHeight)
        self.title = "API Console"
        self.titlebarAppearsTransparent = false
        self.titleVisibility = .visible
        self.isOpaque = true
        self.delegate = self
        self.setFrameAutosaveName("APIConsoleWindow")
        NotificationCenter.default.addObserver(forName: Self.updateConsoleWindowTitle, object: nil, queue: .main) { _ in
            let keyword = PlanetAPIConsoleViewModel.shared.keyword
            if keyword.isEmpty {
                self.title = "API Console"
            } else {
                self.title = "Searching Logs: \(keyword)"
            }
        }
    }
}


extension PlanetAPIConsoleWindow: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        Task { @MainActor in
            PlanetAPIConsoleViewModel.shared.isShowingConsoleWindow = false
        }
        return true
    }
}
