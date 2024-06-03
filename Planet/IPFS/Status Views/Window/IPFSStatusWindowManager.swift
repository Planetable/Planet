//
//  IPFSStatusWindowManager.swift
//  Planet
//

import Foundation


class IPFSStatusWindowManager: NSObject {
    static let shared = IPFSStatusWindowManager()

    private var windowController: IPFSStatusWindowController?

    var windowOrigin: CGPoint = .zero
    var windowSize: CGSize = .init(width: 280, height: 280)

    func activate() {
        let rect = CGRect(origin: windowOrigin, size: windowSize)
        if windowController == nil {
            let wc = IPFSStatusWindowController()
            let vc = IPFSStatusViewController()
            wc.contentViewController = vc
            windowController = wc
        }
        windowController?.showWindow(nil)
        if rect.origin == .zero {
            windowController?.window?.center()
        }
        Task { @MainActor in
            IPFSState.shared.isShowingStatus = false
            IPFSState.shared.isShowingStatusWindow = true
        }
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
