//
//  AppMenu.swift
//  PlanetLite
//

import Cocoa


@objc protocol EditMenuActions {
    func redo(_ sender: AnyObject)
    func undo(_ sender: AnyObject)
}


@objc protocol FileMenuActions {
    func importPlanet(_ sender: AnyObject)
}


extension PlanetLiteAppDelegate: FileMenuActions {
    func importPlanet(_ sender: AnyObject) {
        let panel = NSOpenPanel()
        panel.message = "Choose Planet Data"
        panel.prompt = "Import"
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.data, .package]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.canCreateDirectories = false
        let response = panel.runModal()
        guard response == .OK, let url = panel.url, url.pathExtension == "planet" else { return }
        Task { @MainActor in
            do {
                let planet = try MyPlanetModel.importBackup(from: url)
                PlanetStore.shared.myPlanets.insert(planet, at: 0)
                PlanetStore.shared.selectedView = .myPlanet(planet)
            } catch {
                PlanetStore.shared.alert(title: "Failed to import planet")
            }
        }
    }

    func populateMainMenu() {
        let mainMenu = NSMenu(title:"MainMenu")
        
        // The titles of the menu items are for identification purposes only and shouldn't be localized.
        // The strings in the menu bar come from the submenu titles,
        // except for the application menu, whose title is ignored at runtime.
        var menuItem = mainMenu.addItem(withTitle:"Application", action:nil, keyEquivalent:"")
        var submenu = NSMenu(title:"Application")
        populateApplicationMenu(submenu)
        mainMenu.setSubmenu(submenu, for:menuItem)
        
        menuItem = mainMenu.addItem(withTitle:"File", action:nil, keyEquivalent:"")
        submenu = NSMenu(title:NSLocalizedString("File", comment:"File menu"))
        populateFileMenu(submenu)
        mainMenu.setSubmenu(submenu, for:menuItem)
        
        // Keep basic text editing features
        menuItem = mainMenu.addItem(withTitle:"Edit", action:nil, keyEquivalent:"")
        submenu = NSMenu(title:NSLocalizedString("Edit", comment:"Edit menu"))
        populateEditMenu(submenu)
        mainMenu.setSubmenu(submenu, for:menuItem)

        /*
         * No needs for view functions
        menuItem = mainMenu.addItem(withTitle:"View", action:nil, keyEquivalent:"")
        submenu = NSMenu(title:NSLocalizedString("View", comment:"View menu"))
        populateViewMenu(submenu)
        mainMenu.setSubmenu(submenu, for:menuItem)
         */
        
        menuItem = mainMenu.addItem(withTitle:"Window", action:nil, keyEquivalent:"")
        submenu = NSMenu(title:NSLocalizedString("Window", comment:"Window menu"))
        populateWindowMenu(submenu)
        mainMenu.setSubmenu(submenu, for:menuItem)
        NSApp.windowsMenu = submenu
        
        menuItem = mainMenu.addItem(withTitle:"Help", action:nil, keyEquivalent:"")
        submenu = NSMenu(title:NSLocalizedString("Help", comment:"View menu"))
        populateHelpMenu(submenu)
        mainMenu.setSubmenu(submenu, for:menuItem)
        
        NSApp.mainMenu = mainMenu
    }
    
    func populateApplicationMenu(_ menu:NSMenu) {

        var title = NSLocalizedString("About", comment:"About menu item") + " " + applicationName
        var menuItem = menu.addItem(withTitle:title, action:#selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent:"")
        menuItem.target = NSApp
        
        title = NSLocalizedString("Check for Updates", comment: "")
        menuItem = menu.addItem(withTitle: title, action: #selector(self.checkForUpdate(_:)), keyEquivalent: "")
        menuItem.target = self
        
        menu.addItem(NSMenuItem.separator())
        
        title = NSLocalizedString("Services", comment:"Services menu item")
        menuItem = menu.addItem(withTitle:title, action:nil, keyEquivalent:"")
        let servicesMenu = NSMenu(title:"Services")
        menu.setSubmenu(servicesMenu, for:menuItem)
        NSApp.servicesMenu = servicesMenu
        
        menu.addItem(NSMenuItem.separator())
        
        title = NSLocalizedString("Hide", comment:"Hide menu item") + " " + applicationName
        menuItem = menu.addItem(withTitle:title, action:#selector(NSApplication.hide(_:)), keyEquivalent:"h")
        menuItem.target = NSApp
        
        title = NSLocalizedString("Hide Others", comment:"Hide Others menu item")
        menuItem = menu.addItem(withTitle:title, action:#selector(NSApplication.hideOtherApplications(_:)), keyEquivalent:"h")
        menuItem.keyEquivalentModifierMask = [.command, .option]
        menuItem.target = NSApp
        
        title = NSLocalizedString("Show All", comment:"Show All menu item")
        menuItem = menu.addItem(withTitle:title, action:#selector(NSApplication.unhideAllApplications(_:)), keyEquivalent:"")
        menuItem.target = NSApp
        
        menu.addItem(NSMenuItem.separator())
        
        title = NSLocalizedString("Quit", comment:"Quit menu item") + " " + applicationName
        menuItem = menu.addItem(withTitle:title, action:#selector(NSApplication.terminate(_:)), keyEquivalent:"q")
        menuItem.target = NSApp
    }
    
    func populateFileMenu(_ menu:NSMenu) {
        let title = NSLocalizedString("Close Window", comment:"Close Window menu item")
        menu.addItem(withTitle:title, action:#selector(NSWindow.performClose(_:)), keyEquivalent:"w")
        
        menu.addItem(NSMenuItem.separator())

        let importItem = NSMenuItem(title: NSLocalizedString("Import Planet", comment: "Import Planet menu item"), action: #selector(FileMenuActions.importPlanet(_:)), keyEquivalent: "i")
        importItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(importItem)
    }
    
    func populateEditMenu(_ menu:NSMenu) {
        var title = NSLocalizedString("Undo", comment:"Undo menu item")
        menu.addItem(withTitle:title, action:#selector(EditMenuActions.undo(_:)), keyEquivalent:"z")
        
        title = NSLocalizedString("Redo", comment:"Redo menu item")
        menu.addItem(withTitle:title, action:#selector(EditMenuActions.redo(_:)), keyEquivalent:"Z")
        
        menu.addItem(NSMenuItem.separator())
        
        title = NSLocalizedString("Cut", comment:"Cut menu item")
        menu.addItem(withTitle:title, action:#selector(NSText.cut(_:)), keyEquivalent:"x")
        
        title = NSLocalizedString("Copy", comment:"Copy menu item")
        menu.addItem(withTitle:title, action:#selector(NSText.copy(_:)), keyEquivalent:"c")
        
        title = NSLocalizedString("Paste", comment:"Paste menu item")
        menu.addItem(withTitle:title, action:#selector(NSText.paste(_:)), keyEquivalent:"v")
        
        title = NSLocalizedString("Paste and Match Style", comment:"Paste and Match Style menu item")
        var menuItem = menu.addItem(withTitle:title, action:#selector(NSTextView.pasteAsPlainText(_:)), keyEquivalent:"V")
        menuItem.keyEquivalentModifierMask = [.command, .option]
        
        title = NSLocalizedString("Delete", comment:"Delete menu item")
        menu.addItem(withTitle:title, action:#selector(NSText.delete(_:)), keyEquivalent:"\u{8}") // backspace
        
        title = NSLocalizedString("Select All", comment:"Select All menu item")
        menu.addItem(withTitle:title, action:#selector(NSText.selectAll(_:)), keyEquivalent:"a")
        
        menu.addItem(NSMenuItem.separator())
        
        title = NSLocalizedString("Find", comment:"Find menu item")
        menuItem = menu.addItem(withTitle:title, action:nil, keyEquivalent:"")
        let findMenu = NSMenu(title:"Find")
        populateFindMenu(findMenu)
        menu.setSubmenu(findMenu, for:menuItem)
        
        title = NSLocalizedString("Spelling", comment:"Spelling menu item")
        menuItem = menu.addItem(withTitle:title, action:nil, keyEquivalent:"")
        let spellingMenu = NSMenu(title:"Spelling")
        populateSpellingMenu(spellingMenu)
        menu.setSubmenu(spellingMenu, for:menuItem)
    }
    
    func populateFindMenu(_ menu:NSMenu) {
        var title = NSLocalizedString("Find…", comment:"Find… menu item")
        var menuItem = menu.addItem(withTitle:title, action:#selector(NSResponder.performTextFinderAction(_:)), keyEquivalent:"f")
        menuItem.tag = NSTextFinder.Action.showFindInterface.rawValue
        
        title = NSLocalizedString("Find Next", comment:"Find Next menu item")
        menuItem = menu.addItem(withTitle:title, action:#selector(NSResponder.performTextFinderAction(_:)), keyEquivalent:"g")
        menuItem.tag = NSTextFinder.Action.nextMatch.rawValue
        
        title = NSLocalizedString("Find Previous", comment:"Find Previous menu item")
        menuItem = menu.addItem(withTitle:title, action:#selector(NSResponder.performTextFinderAction(_:)), keyEquivalent:"G")
        menuItem.tag = NSTextFinder.Action.previousMatch.rawValue
        
        title = NSLocalizedString("Use Selection for Find", comment:"Use Selection for Find menu item")
        menuItem = menu.addItem(withTitle:title, action:#selector(NSResponder.performTextFinderAction(_:)), keyEquivalent:"e")
        menuItem.tag = NSTextFinder.Action.setSearchString.rawValue
        
        title = NSLocalizedString("Jump to Selection", comment:"Jump to Selection menu item")
        menu.addItem(withTitle:title, action:#selector(NSResponder.centerSelectionInVisibleArea(_:)), keyEquivalent:"j")
    }
    
    func populateSpellingMenu(_ menu:NSMenu) {
        var title = NSLocalizedString("Spelling…", comment:"Spelling… menu item")
        menu.addItem(withTitle:title, action:#selector(NSText.showGuessPanel(_:)), keyEquivalent:":")
        
        title = NSLocalizedString("Check Spelling", comment:"Check Spelling menu item")
        menu.addItem(withTitle:title, action:#selector(NSText.checkSpelling(_:)), keyEquivalent:";")
        
        title = NSLocalizedString("Check Spelling as You Type", comment:"Check Spelling as You Type menu item")
        menu.addItem(withTitle:title, action:#selector(NSTextView.toggleContinuousSpellChecking(_:)), keyEquivalent:"")
    }
    
    func populateViewMenu(_ menu:NSMenu) {
        var title = NSLocalizedString("Show Toolbar", comment:"Show Toolbar menu item")
        var menuItem = menu.addItem(withTitle:title, action:#selector(NSWindow.toggleToolbarShown(_:)), keyEquivalent:"t")
        menuItem.keyEquivalentModifierMask = [.command, .option]
        
        title = NSLocalizedString("Customize Toolbar…", comment:"Customize Toolbar… menu item")
        menu.addItem(withTitle:title, action:#selector(NSWindow.runToolbarCustomizationPalette(_:)), keyEquivalent:"")
        
        menu.addItem(NSMenuItem.separator())
        
        title = NSLocalizedString("Enter Full Screen", comment:"Enter Full Screen menu item")
        menuItem = menu.addItem(withTitle:title, action:#selector(NSWindow.toggleFullScreen(_:)), keyEquivalent:"f")
        menuItem.keyEquivalentModifierMask = [.command, .control]
    }
    
    func populateWindowMenu(_ menu:NSMenu) {
        var title = NSLocalizedString("Minimize", comment:"Minimize menu item")
        menu.addItem(withTitle:title, action:#selector(NSWindow.performMiniaturize(_:)), keyEquivalent:"m")
        
        title = NSLocalizedString("Zoom", comment:"Zoom menu item")
        menu.addItem(withTitle:title, action:#selector(NSWindow.performZoom(_:)), keyEquivalent:"")
        
        menu.addItem(NSMenuItem.separator())
        
        title = NSLocalizedString("Bring All to Front", comment:"Bring All to Front menu item")
        let menuItem = menu.addItem(withTitle:title, action:#selector(NSApplication.arrangeInFront(_:)), keyEquivalent:"")
        menuItem.target = NSApp
    }
    
    func populateHelpMenu(_ menu:NSMenu) {
        let title = applicationName + " " + NSLocalizedString("Help", comment:"Help menu item")
        let menuItem = menu.addItem(withTitle:title, action:#selector(NSApplication.showHelp(_:)), keyEquivalent:"?")
        menuItem.target = NSApp
    }
}
