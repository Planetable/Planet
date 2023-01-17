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
    @State private var isShowingPasscode: Bool = false
    
    var body: some View {
        Form {
            Section {
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
            }
            Section {
                HStack(spacing: 4) {
                    Toggle("Require Authentication", isOn: $apiUsesPasscode)
                        .disabled(!apiEnabled)
                        .onChange(of: apiUsesPasscode) { newValue in
                            reloadAPIServer()
                        }
                    Spacer()
                    HelpLinkButton(helpLink: URL(string: "https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Authorization#basic_authentication")!)
                }
                .padding(.top, 10)
                TextField("API Server Username", text: $apiUsername)
                    .disabled(!apiEnabled)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: apiUsername) { newValue in
                        if newValue == "" {
                            apiUsesPasscode = false
                        }
                        reloadAPIServer()
                    }
                ZStack {
                    TextField("API Server Passcode", text: $apiPasscode)
                        .opacity(isShowingPasscode ? 1.0 : 0.0)
                    SecureField("API Server Passcode", text: $apiPasscode)
                        .opacity(!isShowingPasscode ? 1.0 : 0.0)
                    HStack {
                        Spacer()
                        Button {
                            isShowingPasscode.toggle()
                        } label: {
                            Image(systemName: !isShowingPasscode ? "eye.slash" : "eye")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 14, height: 14, alignment: .center)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                }
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
