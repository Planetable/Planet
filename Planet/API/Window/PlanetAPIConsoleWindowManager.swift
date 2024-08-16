//
//  PlanetAPIConsoleWindowManager.swift
//  Planet
//

import Foundation


class PlanetAPIConsoleWindowManager: NSObject {
    static let shared = PlanetAPIConsoleWindowManager()
    
    private var windowController: PlanetAPIConsoleWindowController?
    
    func activate() {
        if windowController == nil {
            let wc = PlanetAPIConsoleWindowController()
            let vc = PlanetAPIConsoleViewController()
            wc.contentViewController = vc
            windowController = wc
        }
        windowController?.showWindow(nil)
        Task { @MainActor in
            PlanetAPIConsoleViewModel.shared.isShowingConsoleWindow = true
        }
    }

    func deactivate() {
        windowController?.contentViewController = nil
        windowController?.window?.close()
        windowController?.window = nil
        windowController = nil
        Task { @MainActor in
            PlanetAPIConsoleViewModel.shared.isShowingConsoleWindow = false
        }
    }
}
