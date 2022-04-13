//
//  TemplateBrowserManager.swift
//  Planet
//
//  Created by Xin Liu on 4/13/22.
//

import Foundation
import Cocoa
import SwiftUI

class TemplateBrowserManager: NSObject {
    static let shared = TemplateBrowserManager()
    
    @MainActor
    func launchTemplateBrowser() {
        let browserView = TemplateBrowserView()
        let browserWindow = TemplateBrowserWindow(rect: NSMakeRect(0, 0, 720, 480), maskStyle: [.closable, .miniaturizable, .resizable, .titled, .fullSizeContentView], backingType: .buffered, deferMode: false)
        browserWindow.center()
        browserWindow.contentView = NSHostingView(rootView: browserView)
        browserWindow.makeKeyAndOrderFront(nil)
    }
}
