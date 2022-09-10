//
//  PlanetSettingsGeneralView.swift
//  Planet
//
//  Created by Kai on 9/11/22.
//

import SwiftUI


struct PlanetSettingsGeneralView: View {
    @EnvironmentObject private var viewModel: PlanetSettingsViewModel

    @AppStorage(String.settingsPublicGatewayIndex) private var publicGatewayIndex: Int = UserDefaults.standard.integer(forKey: String.settingsPublicGatewayIndex)

    var body: some View {
        Form {
            Section {
                VStack (spacing: 20) {
                    HStack {
                        Text("Public Gateway")
                        Spacer()
                        Picker(selection: $publicGatewayIndex, label: Text("")) {
                            ForEach(0..<IPFSDaemon.publicGateways.count, id: \.self) { index in
                                Text(IPFSDaemon.publicGateways[index])
                                    .tag(index)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                }
            }

            Spacer()
        }
        .padding()
    }
}

struct PlanetSettingsGeneralView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetSettingsGeneralView()
    }
}
