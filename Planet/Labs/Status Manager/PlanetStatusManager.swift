//
//  PlanetStatusManager.swift
//  Planet
//

import Foundation
import SwiftUI


class PlanetStatusManager: ObservableObject {
    static let shared = PlanetStatusManager()

    @Published private(set) var isClear: Bool = true
    
    @MainActor
    func updateStatus() {
        let ongoingPlanets = PlanetStore.shared.myPlanets.filter({ $0.isPublishing || $0.isRebuilding })
        let processesCount: Int
        if PlanetStore.shared.app == .planet {
            let publishingFolders = PlanetPublishedServiceStore.shared.publishingFolders
            processesCount = ongoingPlanets.count + publishingFolders.count
        } else {
            processesCount = ongoingPlanets.count
        }
        isClear = processesCount == 0
    }
    
    // PlanetStatusManager controls current app termination status, if there're ongoing processes, notify user (with options) before termination.
    func reply() -> NSApplication.TerminateReply {
        if isClear {
            terminate()
            return .terminateNow
        } else {
            wait()
            return .terminateLater
        }
    }
    
    private func wait() {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "There're unfinished publish processes running, please wait for a few more seconds."
        alert.addButton(withTitle: "Wait")
        alert.addButton(withTitle: "Quit Anyway")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSApplication.shared.reply(toApplicationShouldTerminate: false)
        }
        if response == .alertSecondButtonReturn {
            terminate()
        }
    }
    
    private func terminate() {
        Task.detached(priority: .utility) {
            Task { @MainActor in
                if PlanetStore.shared.app == .planet {
                    await PlanetAPIHelper.shared.shutdown()
                }
            }
            IPFSDaemon.shared.shutdownDaemon()
            await NSApplication.shared.reply(toApplicationShouldTerminate: true)
        }
    }
}
