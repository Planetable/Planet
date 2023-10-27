//
//  PlanetLiteAppDelegate.swift
//  PlanetLite
//

import Cocoa
import SwiftUI
import UserNotifications


class PlanetLiteAppDelegate: NSObject, NSApplicationDelegate {
    static let shared = PlanetLiteAppDelegate()
    
    var appWindowController: AppWindowController?

    lazy var applicationName: String = {
        if let bundleName = Bundle.main.object(forInfoDictionaryKey:"CFBundleName"), let bundleNameAsString = bundleName as? String {
            return bundleNameAsString
        }
        return NSLocalizedString(.liteAppName, comment:"")
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
        setupNotification()
        PlanetUpdater.shared.checkForUpdatesInBackground()
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
        return PlanetStatusManager.shared.reply()
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        if let url = urls.first, url.lastPathComponent.hasSuffix(".planet") {
            Task { @MainActor in
                let planet = try MyPlanetModel.importBackup(from: url)
                PlanetStore.shared.myPlanets.insert(planet, at: 0)
                PlanetStore.shared.selectedView = .myPlanet(planet)
            }
        } else {
            createQuickShareWindow(forFiles: urls)
        }
    }
}


extension PlanetLiteAppDelegate {
    func createQuickShareWindow(forFiles files: [URL]) {
        guard files.count > 0 else { return }
        Task { @MainActor in
            do {
                try PlanetQuickShareViewModel.shared.prepareFiles(files)
                PlanetStore.shared.isQuickSharing = true
            } catch {
                let alert = NSAlert()
                alert.messageText = "Failed to Create Post"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }

    @objc func checkForUpdate(_ sender: Any) {
        PlanetUpdater.shared.checkForUpdates()
    }
}


extension PlanetLiteAppDelegate: UNUserNotificationCenterDelegate {
    func setupNotification() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional || settings.authorizationStatus == .notDetermined else { return }
            if settings.alertSetting == .disabled || settings.authorizationStatus == .notDetermined {
                center.requestAuthorization(options: [.alert, .badge]) { _, _ in
                }
            } else {
                center.delegate = self
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_: UNUserNotificationCenter, willPresent _: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .badge])
    }

    func userNotificationCenter(_: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}
