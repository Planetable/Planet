import Cocoa
import SwiftUI

class ArticleAIChatWindowManager: NSObject, NSWindowDelegate {
    static let shared = ArticleAIChatWindowManager()

    private var windows: [UUID: NSWindow] = [:]

    func open(for article: ArticleModel) {
        if let window = windows[article.id] {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 520),
            styleMask: [.closable, .titled, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        w.isReleasedWhenClosed = false
        w.title = "AI Chat – \(article.title)"
        w.minSize = NSSize(width: 480, height: 360)
        w.contentView = NSHostingView(rootView: ArticleAIChatView(article: article))
        w.center()
        w.setFrameAutosaveName("ArticleAIChat-\(article.id.uuidString)")
        w.delegate = self
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        windows[article.id] = w
    }

    func windowWillClose(_ notification: Notification) {
        if let closedWindow = notification.object as? NSWindow {
            windows = windows.filter { $0.value !== closedWindow }
        }
    }
}
