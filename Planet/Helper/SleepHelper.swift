//
//  SleepHelper.swift
//  SleepHelper
//
//  Created by Kai on 8/23/25.
//

import Foundation
import os
import IOKit
import IOKit.pwr_mgt


class SleepHelper: NSObject {
    static let shared = SleepHelper()

    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SleepHelper")

    private var reason: CFString = "IPFS Daemon or API Server is running in background." as CFString
    private var assertionID: IOPMAssertionID = 0
    private var returnStatus: IOReturn?

    // Preventing user idle sleep
    // https://developer.apple.com/documentation/iokit/kiopmassertiontypepreventuseridlesystemsleep
    func enablePreventingIdleSleep() {
        if let previousReturnStatus = returnStatus, previousReturnStatus == kIOReturnSuccess {
            Self.logger.info("Already enabled preventing user idle sleep, abort action.")
            return
        }
        returnStatus = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID
        )
        if let status = returnStatus, status == kIOReturnSuccess {
            Self.logger.info("Preventing user idle sleep enabled.")
        } else {
            Self.logger.info("Failed to prevent user idle sleep.")
        }
    }

    func disablePreventingIdleSleep() {
        guard let previousReturnStatus = returnStatus, previousReturnStatus == kIOReturnSuccess
        else {
            Self.logger.info("No need to disable preventing user idle sleep, abort action.")
            return
        }
        _ = IOPMAssertionRelease(assertionID)
        returnStatus = nil
        Self.logger.info("Preventing user idle sleep disabled.")
    }
}
