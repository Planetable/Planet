//
//  IPFSStatusWindowManager.swift
//  Planet
//

import Foundation


class IPFSStatusWindowManager: NSObject {
    static let shared = IPFSStatusWindowManager()

    private var windowController: IPFSStatusWindowController?

    func activate() {
        //MARK: TODO: show status window at the same position.
    }

    func close() {
        windowController?.window?.close()
    }

    func deactivate() {
        windowController?.contentViewController = nil
        windowController?.window?.close()
        windowController?.window = nil
        windowController = nil
    }
}
