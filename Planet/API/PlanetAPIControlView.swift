//
//  PlanetAPIControlView.swift
//  Planet
//

import SwiftUI


enum PlanetAPIControlError: Error {
    case invalidAPIPortError
    case invalidAPIUsernameError
    case invalidAPIPasscodeError
}


struct PlanetAPIControlView: View {
    @ObservedObject private var control: PlanetAPIController
    
    @State private var apiUsesPasscode: Bool = UserDefaults.standard.bool(forKey: .settingsAPIUsesPasscode)
    @State private var apiUsername: String = UserDefaults.standard.string(forKey: .settingsAPIUsername) ?? "Planet"
    @State private var apiPort: String = UserDefaults.standard.string(forKey: .settingsAPIPort) ?? "8086"
    @State private var apiPasscode: String = ""
    @State private var isShowingPasscode: Bool = false
    @State private var isAlert: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    
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
                            .onChange(of: apiUsesPasscode) { newValue in
                                UserDefaults.standard.set(newValue, forKey: .settingsAPIUsesPasscode)
                            }
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
                        do {
                            try applyServerInformation()
                            control.startServer()
                        } catch PlanetAPIControlError.invalidAPIPortError {
                            isAlert = true
                            alertTitle = "Failed to Start Server"
                            alertMessage = "Invalid API port, please double check and try again."
                        } catch PlanetAPIControlError.invalidAPIUsernameError {
                            isAlert = true
                            alertTitle = "Failed to Start Server"
                            alertMessage = "Invalid username, please double check and try again."
                        } catch PlanetAPIControlError.invalidAPIPasscodeError {
                            isAlert = true
                            alertTitle = "Failed to Start Server"
                            alertMessage = "Invalid passcode, please double check and try again."
                        } catch {
                            isAlert = true
                            alertTitle = "Failed to Start Server"
                            alertMessage = "Please double check server informations and try again."
                        }
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
        .alert(isPresented: $isAlert) {
            Alert(title: Text(alertTitle), message: Text(alertMessage), dismissButton: .cancel(Text("OK")))
        }
    }
    
    private func applyServerInformation() throws {
        if let port = Int(apiPort), port > 1024, port < 60000 {
            UserDefaults.standard.set(apiPort, forKey: .settingsAPIPort)
        } else {
            throw PlanetAPIControlError.invalidAPIPortError
        }
        guard apiUsesPasscode else { return }
        if apiUsername != "" {
            UserDefaults.standard.set(apiUsername, forKey: .settingsAPIUsername)
        } else {
            throw PlanetAPIControlError.invalidAPIUsernameError
        }
        if apiPasscode == "" {
            throw PlanetAPIControlError.invalidAPIPasscodeError
        } else {
            try KeychainHelper.shared.saveValue(apiPasscode, forKey: .settingsAPIPasscode)
        }
    }
}

#Preview {
    PlanetAPIControlView()
}
