//
//  PlanetImportManager.swift
//  Planet
//
//  Created by Kai on 6/16/25.
//

import Foundation
import Cocoa
import UniformTypeIdentifiers


extension UTType {
    // https://daringfireball.net/linked/2011/08/05/markdown-uti
    static var markdown: UTType {
        UTType(importedAs: "net.daringfireball.markdown", conformingTo: .plainText)
    }
}


class PlanetImportManager: NSObject {
    static let shared = PlanetImportManager()

    private var importWindowController: PlanetImportWindowController?

    @MainActor
    func dismiss() {
        importWindowController?.close()
        importWindowController = nil
    }

    @MainActor
    func importMarkdownFiles() {
        // Make sure there's planet available
        guard PlanetStore.shared.myPlanets.count > 0 else {
            let alert = NSAlert()
            alert.messageText = "Failed to Import Files"
            alert.informativeText = "No planet available."
            alert.runModal()
            return
        }

        // Choose markdown files
        let panel = NSOpenPanel()
        panel.message = "Select Markdown Files to Import"
        panel.prompt = "Select"
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [UTType.markdown]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.canCreateDirectories = false
        let response = panel.runModal()
        guard response == .OK, panel.urls.count > 0 else { return }
        let urls = panel.urls

        // Present import window
        if importWindowController == nil {
            importWindowController = PlanetImportWindowController()
        }
        importWindowController?.showWindow(nil)
        PlanetImportViewModel.shared.updateMarkdownURLs(urls)
    }
}
