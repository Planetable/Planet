//
//  AppContentDetailsWindowController.swift
//  PlanetLite
//

import Cocoa


class AppContentDetailsWindowController: NSWindowController {
    let article: MyArticleModel
    
    init(withArticle article: MyArticleModel) {
        self.article = article
        let windowSize = NSSize(width: PlanetUI.WINDOW_CONTENT_WIDTH_MIN, height: PlanetUI.WINDOW_CONTENT_HEIGHT_MIN)
        let screenSize = NSScreen.main?.frame.size ?? .zero
        let rect = NSMakeRect(screenSize.width/2 - windowSize.width/2, screenSize.height/2 - windowSize.height/2, windowSize.width, windowSize.height)
        let w = AppContentDetailsWindow(withArticle: article, contentRect: rect, styleMask: [.miniaturizable, .closable, .resizable, .titled], backing: .buffered, defer: true)
        w.minSize = windowSize
        w.maxSize = NSSize(width: screenSize.width, height: .infinity)
        super.init(window: w)
        self.window?.setFrameAutosaveName(.appName + "-" + article.id.uuidString)
    }
    
    required init?(coder: NSCoder) {
        fatalError()
    }

    deinit {
    }

    override func windowDidLoad() {
        super.windowDidLoad()
    }
    
    func articleID() -> UUID {
        return article.id
    }
}
