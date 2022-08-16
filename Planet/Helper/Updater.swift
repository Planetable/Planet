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

    func appVersion() -> String {
        var v = "0.1"
        if let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            v = build
        }
        return v
    }

    func appBuildVersion() -> String {
        var b = "1"
        if let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
            b = build
        }
        return b
    }

    func checkForUpdates() {
        updater.checkForUpdates()
    }

    func checkForUpdatesInBackground() {
        updater.checkForUpdatesInBackground()
    }
}
