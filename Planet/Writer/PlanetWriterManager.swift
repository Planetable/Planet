//
//  PlanetWriterManager.swift
//  Planet
//
//  Created by Kai on 3/29/22.
//

import Foundation
import SwiftUI


class PlanetWriterManager: NSObject {
    static let shared = PlanetWriterManager()

    @MainActor
    func launchWriter(forPlanet planet: Planet) {
        let articleID = planet.id!

        if PlanetStore.shared.writerIDs.contains(articleID) {
            DispatchQueue.main.async {
                PlanetStore.shared.activeWriterID = articleID
            }
            return
        }

        let writerView = PlanetWriterView(articleID: articleID)
        let writerWindow = PlanetWriterWindow(rect: NSMakeRect(0, 0, 720, 480), maskStyle: [.closable, .miniaturizable, .resizable, .titled, .fullSizeContentView], backingType: .buffered, deferMode: false, articleID: articleID)
        writerWindow.center()
        writerWindow.contentView = NSHostingView(rootView: writerView)
        writerWindow.makeKeyAndOrderFront(nil)
    }

    @MainActor
    func launchWriter(forArticle article: PlanetArticle) {
        let articleID = article.id!

        if PlanetStore.shared.writerIDs.contains(articleID) {
            DispatchQueue.main.async {
                PlanetStore.shared.activeWriterID = articleID
            }
            return
        }

        let writerView = PlanetWriterView(articleID: articleID, isEditing: true, title: article.title ?? "", content: article.content ?? "")
        let writerWindow = PlanetWriterWindow(rect: NSMakeRect(0, 0, 720, 480), maskStyle: [.closable, .miniaturizable, .resizable, .titled, .fullSizeContentView], backingType: .buffered, deferMode: false, articleID: articleID)
        writerWindow.center()
        writerWindow.contentView = NSHostingView(rootView: writerView)
        writerWindow.makeKeyAndOrderFront(nil)
    }
}
