//
//  AppContentDetailsWindow.swift
//  PlanetLite
//

import Cocoa


class AppContentDetailsWindow: NSWindow {
    let article: MyArticleModel
    
    init(withArticle article: MyArticleModel, contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        self.article = article
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        self.title = article.title + " - " + article.id.uuidString.prefix(4)
        self.contentViewController = AppContentDetailsViewController(withArticle: article)
        self.delegate = self
    }
}


extension AppContentDetailsWindow: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        return true
    }
}
