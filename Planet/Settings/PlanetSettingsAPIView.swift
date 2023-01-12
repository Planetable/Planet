//
//  PlanetSettingsAPIView.swift
//  Planet
//
//  Created by Kai on 1/13/23.
//

import SwiftUI


struct PlanetSettingsAPIView: View {
    
    @AppStorage(String.settingsAPIEnabled) private var apiEnabled: Bool =
        UserDefaults.standard.bool(forKey: String.settingsAPIEnabled)
    @AppStorage(String.settingsAPIPort) private var apiPort: String = UserDefaults
        .standard.string(forKey: String.settingsAPIPort) ?? "9191"

    var body: some View {
        Form {
            Section {
                VStack(spacing: 20) {
                    HStack(spacing: 4) {
                        Toggle("Enable Public API", isOn: $apiEnabled)
                            .onChange(of: apiEnabled) { newValue in
                                reloadAPIServer()
                            }
                        Spacer()
                    }
                    HStack(spacing: 4) {
                        TextField("API Server Port", text: $apiPort)
                            .disabled(!apiEnabled)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: apiPort) { newValue in
                                reloadAPIServer()
                            }
                        Spacer()
                    }
                }
            }
            Spacer()
        }
        .padding()
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
