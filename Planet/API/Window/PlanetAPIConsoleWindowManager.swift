//
//  PlanetAPIConsoleWindowManager.swift
//  Planet
//

import Foundation
import SwiftUI


class PlanetAPIConsoleWindowManager: NSObject {
    static let shared = PlanetAPIConsoleWindowManager()
    
    private var windowController: PlanetAPIConsoleWindowController?
    
    func activate() {
        if windowController == nil {
            let wc = PlanetAPIConsoleWindowController()
            let vc = PlanetAPIConsoleViewController()
            wc.contentViewController = vc
            windowController = wc
        }
        windowController?.showWindow(nil)
        Task { @MainActor in
            PlanetAPIConsoleViewModel.shared.isShowingConsoleWindow = true
        }
    }

    func deactivate() {
        windowController?.contentViewController = nil
        windowController?.window?.close()
        windowController?.window = nil
        windowController = nil
        Task { @MainActor in
            PlanetAPIConsoleViewModel.shared.isShowingConsoleWindow = false
        }
    }
    
    @ViewBuilder
    func consoleCommandMenu() -> some View {
        Menu("API Console") {
            Button {
                Task { @MainActor in
                    PlanetAPIConsoleViewModel.shared.increaseFontSize()
                }
            } label: {
                Text("Increase Font Size")
            }
            .keyboardShortcut("+", modifiers: [.command])
            Button {
                Task { @MainActor in
                    PlanetAPIConsoleViewModel.shared.decreaseFontSize()
                }
            } label: {
                Text("Decrease Font Size")
            }
            .keyboardShortcut("-", modifiers: [.command])
            Button {
                Task { @MainActor in
                    PlanetAPIConsoleViewModel.shared.resetFontSize()
                }
            } label: {
                Text("Reset to Default Size")
            }
            .keyboardShortcut("0", modifiers: [.command])
            Divider()
            Button {
                PlanetAPIConsoleViewModel.shared.clearLogs()
            } label: {
                Text("Clear Console Output")
            }
            .keyboardShortcut("c", modifiers: [.command, .shift, .option])
            Divider()
            Button {
                PlanetAPIConsoleWindowManager.shared.activate()
            } label: {
                Text("Open Console")
            }
            .keyboardShortcut("a", modifiers: [.command, .shift, .option])
        }

    }
}
