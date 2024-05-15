//
//  IPFSOpenWindowManager.swift
//  Planet
//
//  Created by Kai on 5/15/24.
//

import Foundation


class IPFSOpenWindowManager: NSObject {
    static let shared = IPFSOpenWindowManager()
    
    private var openWindowController: IPFSOpenWindowController?
    
    func activate() {
        if openWindowController == nil {
            let wc = IPFSOpenWindowController()
            let vc = IPFSOpenViewController()
            wc.contentViewController = vc
            openWindowController = wc
        }
        openWindowController?.showWindow(nil)
    }
    
    func close() {
        openWindowController?.window?.close()
    }
    
    func deactivate() {
        openWindowController?.contentViewController = nil
        openWindowController?.window?.close()
        openWindowController?.window = nil
        openWindowController = nil
    }
}
