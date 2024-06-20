//
//  IPFSStatusWindowManager.swift
//  Planet
//

import Foundation


class IPFSStatusWindowManager: NSObject {
    static let shared = IPFSStatusWindowManager()
    static let lastWindowOriginKey: String = "PlanetIPFSStatusWindowLastOriginKey"

    private var windowController: IPFSStatusWindowController?

    func activate() {
        let origin: NSPoint = {
            if let value = UserDefaults.standard.value(forKey: Self.lastWindowOriginKey) as? NSValue {
                return value.pointValue
            }
            return .zero
        }()
        if windowController == nil {
            let wc = IPFSStatusWindowController(withOrigin: origin)
            let vc = IPFSStatusViewController()
            wc.contentViewController = vc
            windowController = wc
        }
        windowController?.showWindow(nil)
        Task { @MainActor in
            IPFSState.shared.isShowingStatus = false
            IPFSState.shared.isShowingStatusWindow = true
        }
    }

    func deactivate() {
        let windowOrigin: NSPoint = windowController?.window?.frame.origin ?? .zero
        UserDefaults.standard.set(NSValue(point: windowOrigin), forKey: Self.lastWindowOriginKey)
        windowController?.contentViewController = nil
        windowController?.window?.close()
        windowController?.window = nil
        windowController = nil
        Task { @MainActor in
            IPFSState.shared.isShowingStatusWindow = false
        }
    }
}
