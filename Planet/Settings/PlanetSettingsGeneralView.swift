//
//  PlanetSettingsGeneralView.swift
//  Planet
//
//  Created by Kai on 9/11/22.
//

import SwiftUI

struct PlanetSettingsGeneralView: View {
    let CAPTION_WIDTH: CGFloat = 120

    @EnvironmentObject private var viewModel: PlanetSettingsViewModel

    @AppStorage(String.settingsPublicGatewayIndex) private var publicGatewayIndex: Int =
        UserDefaults.standard.integer(forKey: String.settingsPublicGatewayIndex)

    @AppStorage(String.settingsEthereumChainId) private var ethereumChainId: Int = UserDefaults
        .standard.integer(forKey: String.settingsEthereumChainId)

    var body: some View {
        Form {
            Section {
                VStack(spacing: 20) {
                    HStack(spacing: 4) {
                        Text("Public Gateway")
                            .frame(width: CAPTION_WIDTH, alignment: .trailing)
                        Picker(selection: $publicGatewayIndex, label: Text("")) {
                            ForEach(0..<IPFSDaemon.publicGateways.count, id: \.self) { index in
                                Text(IPFSDaemon.publicGateways[index])
                                    .tag(index)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }

                    VStack {
                        HStack(spacing: 4) {
                            Text("Ethereum Network")
                                .frame(width: CAPTION_WIDTH, alignment: .trailing)
                            Picker(selection: $ethereumChainId, label: Text("")) {
                                ForEach(EthereumChainID.allCases, id: \.id) { value in
                                    Text(
                                        "\(EthereumChainID.names[value.rawValue] ?? "Unknown Chain ID \(value.rawValue)")"
                                    )
                                    .tag(value)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                        HStack {
                            Text("")
                                .frame(width: CAPTION_WIDTH)
                            Text(
                                "When you tip a creator, transactions will be sent to the selected Ethereum network."
                            )
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        }

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
