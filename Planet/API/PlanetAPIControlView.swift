//
//  PlanetAPIControlView.swift
//  Planet
//

import SwiftUI


struct PlanetAPIControlView: View {
    @ObservedObject private var control: PlanetAPIController
    
    @State private var apiUsesPasscode: Bool = UserDefaults.standard.bool(forKey: String.settingsAPIUsesPasscode)
    @State private var apiUsername: String = UserDefaults.standard.string(forKey: String.settingsAPIUsername) ?? "Planet"
    @State private var apiPort: String = UserDefaults
        .standard.string(forKey: String.settingsAPIPort) ?? "8086"
    @State private var apiPasscode: String = ""
    @State private var isShowingPasscode: Bool = false
    
    init() {
        _control = ObservedObject(wrappedValue: PlanetAPIController.shared)
    }

    var body: some View {
        VStack {
            Form {
                Section {
                    TextField("API Server Port", text: $apiPort)
                        .disabled(control.serverIsRunning)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.top, 6)
                Section {
                    HStack(spacing: 4) {
                        Toggle("Require Authentication", isOn: $apiUsesPasscode)
                            .disabled(control.serverIsRunning)
                        Spacer()
                        HelpLinkButton(helpLink: URL(string: "https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Authorization#basic_authentication")!)
                    }
                    .padding(.top, 10)
                    TextField("API Server Username", text: $apiUsername)
                        .disabled(control.serverIsRunning)
                        .textFieldStyle(.roundedBorder)
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
                    .disabled(control.serverIsRunning)
                    .textFieldStyle(.roundedBorder)
                }
                Spacer()
            }
            .padding()
            .task {
                do {
                    let passcode = try KeychainHelper.shared.loadValue(forKey: .settingsAPIPasscode)
                    if passcode != "" {
                        apiPasscode = passcode
                    }
                } catch {
                    apiPasscode = ""
                    apiUsesPasscode = false
                    UserDefaults.standard.set(false, forKey: .settingsAPIUsesPasscode)
                    Task { @MainActor in
                        do {
                            try KeychainHelper.shared.delete(forKey: .settingsAPIPasscode)
                        } catch {
                            debugPrint("failed to delete api passcode from keychain: \(error)")
                        }
                    }
                }
            }

            Spacer(minLength: 12)

            HStack {
                Circle()
                    .frame(width: 12, height: 12)
                    .foregroundStyle(control.serverIsRunning ? Color.green : Color.gray)
                let status: String = control.serverIsRunning ? "Running" : "Stopped"
                Text("Server Status: **\(status)**")
                    .padding(.leading, -2)
                Spacer()
                Button {
                    if control.serverIsRunning {
                        control.stopServer()
                    } else {
                        control.startServer()
                    }
                } label: {
                    HStack {
                        if control.serverIsRunning {
                            Text("Stop Server")
                        } else {
                            Text("Start Server")
                        }
                    }
                }
            }
            .frame(height: 54)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .background(Color.secondary.opacity(0.1))
        }
    }
}

#Preview {
    PlanetAPIControlView()
}
