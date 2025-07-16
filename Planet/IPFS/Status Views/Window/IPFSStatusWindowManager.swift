//
//  IPFSStatusWindowManager.swift
//  Planet
//

import Foundation


class IPFSStatusWindowManager: NSObject {
    static let shared = IPFSStatusWindowManager()
    static let lastWindowOriginKey: String = "PlanetIPFSStatusWindowLastOriginKey"

    private var windowController: IPFSStatusWindowController?

    struct SavedOriginPoint: Codable {
        var x: Double
        var y: Double
    }

    func activate() {
        let origin: NSPoint = loadOrigin()
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
            if let w = windowController?.window as? IPFSStatusWindow {
                KeyboardShortcutHelper.shared.activeIPFSStatusWindow = w
            }
        }
    }

    func deactivate() {
        let windowOrigin: NSPoint = windowController?.window?.frame.origin ?? .zero
        do {
            try saveOrigin(windowOrigin)
        } catch {
            debugPrint("failed to save status window origin point: \(error)")
        }
        windowController?.contentViewController = nil
        windowController?.window?.close()
        windowController?.window = nil
        windowController = nil
        Task { @MainActor in
            IPFSState.shared.isShowingStatusWindow = false
            KeyboardShortcutHelper.shared.activeIPFSStatusWindow = nil
        }
    }

    // MARK: -

    private func saveOrigin(_ origin: NSPoint) throws {
        let data = try PropertyListEncoder().encode(SavedOriginPoint(x: origin.x, y: origin.y))
        UserDefaults.standard.set(data, forKey: Self.lastWindowOriginKey)
    }

    private func loadOrigin() -> NSPoint {
        guard
            let data = UserDefaults.standard.data(forKey: Self.lastWindowOriginKey),
            let origin = try? PropertyListDecoder().decode(SavedOriginPoint.self, from: data)
        else {
            return .zero
        }
        return NSPoint(x: origin.x, y: origin.y)
    }
}
