//
//  AppContentDetailsWindowManager.swift
//  PlanetLite
//

import Cocoa


class AppContentDetailsWindowManager: NSObject {
    static let shared = AppContentDetailsWindowManager()
    
    private(set) var windowControllers: [AppContentDetailsWindowController] = []

    @MainActor
    func activateWindowController(forArticle article: MyArticleModel) {
        if let controller = windowControllers.first(where: { $0.articleID() == article.id }) {
            controller.window?.makeKeyAndOrderFront(nil)
        } else {
            addWindowController(forArticle: article)
        }
    }
    
    @MainActor
    func deactivateWindowController(forArticle article: MyArticleModel) {
        guard windowControllers.first(where: { $0.articleID() == article.id }) != nil else { return }
        destroyWindowController(forArticle: article)
    }
    
    // MARK: -

    private func addWindowController(forArticle article: MyArticleModel) {
        let controller = AppContentDetailsWindowController(withArticle: article)
        guard windowControllers.first(where: { $0.articleID() == controller.articleID() }) == nil else { return }
        windowControllers.append(controller)
        controller.showWindow(nil)
    }
    
    private func destroyWindowController(forArticle article: MyArticleModel) {
        windowControllers = windowControllers.filter({ controller in
            if controller.articleID() == article.id {
                controller.window?.close()
                controller.window = nil
                controller.contentViewController = nil
                return false
            }
            return true
        })
    }
}
