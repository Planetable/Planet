//
//  PlanetSettingsAPIView.swift
//  Planet
//
//  Created by Kai on 1/13/23.
//

import SwiftUI
import KeychainSwift


struct PlanetSettingsAPIView: View {
    
    @AppStorage(String.settingsAPIEnabled) private var apiEnabled: Bool =
        UserDefaults.standard.bool(forKey: String.settingsAPIEnabled)
    @AppStorage(String.settingsAPIUsesPasscode) private var apiUsesPasscode: Bool = UserDefaults.standard.bool(forKey: String.settingsAPIUsesPasscode)
    @AppStorage(String.settingsAPIUsername) private var apiUsername: String = UserDefaults.standard.string(forKey: String.settingsAPIUsername) ?? "Planet"
    @AppStorage(String.settingsAPIPort) private var apiPort: String = UserDefaults
        .standard.string(forKey: String.settingsAPIPort) ?? "9191"
    
    @State private var apiPasscode: String = ""

    var body: some View {
        Form {
            Section {
                VStack(spacing: 10) {
                    HStack(spacing: 4) {
                        Toggle("Enable Public API", isOn: $apiEnabled)
                            .onChange(of: apiEnabled) { newValue in
                                reloadAPIServer()
                            }
                        Spacer()
                    }
                    TextField("API Server Port", text: $apiPort)
                        .disabled(!apiEnabled)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: apiPort) { newValue in
                            reloadAPIServer()
                        }
                    
                    Divider()
                        .padding(.vertical, 15)
                    
                    HStack(spacing: 4) {
                        Toggle("API Uses Passcode", isOn: $apiUsesPasscode)
                            .disabled(!apiEnabled)
                            .onChange(of: apiUsesPasscode) { newValue in
                                reloadAPIServer()
                            }
                        Spacer()
                    }
                    TextField("API Server Username", text: $apiUsername)
                        .disabled(!apiEnabled)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: apiUsername) { newValue in
                            if newValue == "" {
                                apiUsesPasscode = false
                            }
                            reloadAPIServer()
                        }
                    SecureField("API Server Passcode", text: $apiPasscode)
                        .disabled(!apiEnabled)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: apiPasscode) { newValue in
                            if newValue == "" {
                                apiUsesPasscode = false
                            }
                            Task {
                                await self.updatePasscode(newValue)
                                reloadAPIServer()
                            }
                        }
                }
            }
            Spacer()
        }
        .padding()
        .task {
            let keychain = KeychainSwift()
            if let passcode = keychain.get(.settingsAPIPasscode) {
                apiPasscode = passcode
            } else {
                apiPasscode = ""
                apiUsesPasscode = false
                UserDefaults.standard.set(false, forKey: .settingsAPIUsesPasscode)
                Task { @MainActor in
                    keychain.delete(.settingsAPIPasscode)
                }
            }
        }
    }
    
    private func updatePasscode(_ passcode: String) async {
        guard passcode != "" else { return }
        let keychain = KeychainSwift()
        keychain.set(passcode, forKey: .settingsAPIPasscode)
    }
    
    private func reloadAPIServer() {
        do {
            try PlanetAPI.shared.relaunch()
        } catch {
            debugPrint("failed to relaunch api server: \(error)")
        }
    }
}

struct PlanetSettingsAPIView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetSettingsAPIView()
    }
}
