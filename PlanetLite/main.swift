//
//  main.swift
//  PlanetLite
//

import Cocoa


autoreleasepool {
    let delegate = PlanetLiteAppDelegate.shared
    NSApplication.shared.delegate = delegate
    _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
}
