//
//  PlanetUpdater.swift
//  Planet
//
//  Created by Kai on 7/28/22.
//

import Foundation
import SwiftUI
import Sparkle


class PlanetUpdater: NSObject, ObservableObject {
    static let shared = PlanetUpdater()

    @Published var canCheckForUpdates: Bool = false

    private let updater: SPUUpdater = {
        let mainAppBundle = Bundle.main
        let userDriver = SPUStandardUserDriver(hostBundle: Bundle.main, delegate: nil)
        let anUpdater = SPUUpdater(hostBundle: mainAppBundle, applicationBundle: mainAppBundle, userDriver: userDriver, delegate: nil)
        return anUpdater
    }()

    override init() {
        do {
            try updater.start()
            canCheckForUpdates = updater.canCheckForUpdates
        } catch {
            debugPrint("failed to start planet updater: \(error)")
        }
    }

    func checkForUpdates() {
        updater.checkForUpdates()
    }

    func checkForUpdatesInBackground() {
        updater.checkForUpdatesInBackground()
    }
}
