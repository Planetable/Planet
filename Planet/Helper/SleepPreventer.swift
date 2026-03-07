//
//  SleepPreventer.swift
//  Planet
//

import Foundation

class SleepPreventer {
    static let shared = SleepPreventer()

    private var activity: NSObjectProtocol?

    func enable() {
        guard activity == nil else { return }
        activity = ProcessInfo.processInfo.beginActivity(
            options: .idleSystemSleepDisabled,
            reason: "Planet is running"
        )
    }

    func disable() {
        guard let activity = activity else { return }
        ProcessInfo.processInfo.endActivity(activity)
        self.activity = nil
    }
}
