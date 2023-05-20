//
//  PlanetLiteAppDelegate.swift
//  PlanetLite
//

import Cocoa
import SwiftUI


class PlanetLiteAppDelegate: NSObject, NSApplicationDelegate {
    static let shared = PlanetLiteAppDelegate()
    
    var appWindowController: AppWindowController?

    lazy var applicationName: String = {
        if let bundleName = Bundle.main.object(forInfoDictionaryKey:"CFBundleName"), let bundleNameAsString = bundleName as? String {
            return bundleNameAsString
        }
        return NSLocalizedString("Planet Lite", comment:"")
    }()

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        UserDefaults.standard.set(false, forKey: "NSFullScreenMenuItemEverywhere")
        populateMainMenu()
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if appWindowController == nil {
            appWindowController = AppWindowController()
        }
        appWindowController?.showWindow(nil)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if appWindowController == nil {
            appWindowController = AppWindowController()
        }
        appWindowController?.showWindow(nil)
        return true
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Task.detached(priority: .utility) {
//            IPFSDaemon.shared.shutdownDaemon()
            await NSApplication.shared.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
