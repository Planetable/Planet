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
        if PlanetStore.app == .planet {
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
        } else {
            // Read @AppStorage(String.settingsWarnBeforeQuitIfPublishing) to determine whether to show alert or not
            if let warnBeforeQuitIfPublishing = UserDefaults.standard.object(forKey: String.settingsWarnBeforeQuitIfPublishing) as? Bool, warnBeforeQuitIfPublishing {
                wait()
            } else {
                terminate()
            }
        }
        return .terminateLater
    }

    private func wait() {
        DispatchQueue.main.async {
            NSApp.requestUserAttention(.criticalRequest)
        }
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
        debugPrint("Main application is terminating...")
        Task.detached(priority: .userInitiated) {
            await withTaskGroup(of: Void.self) { group in
                if UserDefaults.standard.bool(forKey: .settingsAPIEnabled) {
                    group.addTask {
                        try? await PlanetAPIController.shared.stop(skipStatus: true)
                    }
                }
                group.addTask {
                    try? await IPFSDaemon.shared.shutdown()
                }
                group.addTask {
                    ScheduledTasksManager.shared.stopTasks()
                }
                await group.waitForAll()
            }
            await NSApplication.shared.reply(toApplicationShouldTerminate: true)
            debugPrint("Main application terminated")
        }
    }
}
