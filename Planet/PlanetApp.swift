//
//  PlanetApp.swift
//  Planet
//
//  Created by Kai on 2/15/22.
//

import SwiftUI


@main
struct PlanetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var planetStore = PlanetStore.shared

    var body: some Scene {
        WindowGroup {
            PlanetMainView()
                .environmentObject(planetStore)
                .environment(\.managedObjectContext, PlanetDataController.shared.persistentContainer.viewContext)
        }
        .handlesExternalEvents(matching: Set(arrayLiteral: "Planet"))
        .commands {
            CommandGroup(replacing: .newItem) {
            }
            CommandMenu("Planet") {
                Button {
                    PlanetManager.shared.publishLocalPlanets()
                } label: {
                    Text("Publish My Planets")
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])

                Button {
                    PlanetManager.shared.updateFollowingPlanets()
                } label: {
                    Text("Update Following Planets")
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Divider()
                
                Button {
                    PlanetDataController.shared.resetDatabase()
                } label: {
                    Text("Reset Database")
                }
            }
            SidebarCommands()
            TextEditingCommands()
            TextFormattingCommands()
        }
    }
}


class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        let ipns = url.absoluteString.replacingOccurrences(of: "planet://", with: "")
        guard !PlanetDataController.shared.getFollowingIPNSs().contains(ipns) else { return }
        PlanetDataController.shared.createPlanet(withID: UUID(), name: "", about: "", keyName: nil, keyID: nil, ipns: ipns)
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        UserDefaults.standard.set(false, forKey: "NSFullScreenMenuItemEverywhere")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        PlanetDataController.shared.reportDatabaseStatus()
        PlanetManager.shared.setup()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        PlanetDataController.shared.reportDatabaseStatus()
        PlanetDataController.shared.saveContext()
        PlanetManager.shared.cleanup()
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
             NSApplication.shared.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
