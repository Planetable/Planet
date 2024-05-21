//
//  CPNSettings.swift
//  Planet
//
//  Created by Xin Liu on 7/7/23.
//

import SwiftUI

struct MintSettings: View {
    let CONTROL_CAPTION_WIDTH: CGFloat = 180
    let CONTROL_ROW_SPACING: CGFloat = 8
    let LOGO_SIZE: CGFloat = 16

    @Environment(\.dismiss) var dismiss

    @EnvironmentObject var planetStore: PlanetStore
    @ObservedObject var planet: MyPlanetModel

    @State private var currentSettings: [String: String] = [:]
    @State private var userSettings: [String: String] = [:]

    @State private var settingKeys: [String] = [
        "collectionAddress",
        "collectionCategory",
        "curatorAddress",
        "separator1",
        "label:If you want to use a different RPC endpoint, please enter it below.",
        "ethereumMainnetRPC",
        "ethereumSepoliaRPC",
        "optimismMainnetRPC",
        "optimismSepoliaRPC",
        "arbitrumMainnetRPC",
        "arbitrumSepoliaRPC",
        "baseMainnetRPC",
        "baseSepoliaRPC",
        // "separator2",
        // "highlightColor",
    ]

    init(planet: MyPlanetModel) {
        self.planet = planet
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    planet.smallAvatarAndNameView()
                    Spacer()
                    HelpLinkButton(helpLink: URL(string: "https://croptop.eth.sucks/")!)
                }

                TabView {
                    VStack(spacing: CONTROL_ROW_SPACING) {
                        if let template = planet.template, let settings = template.settings {
                            ForEach(settingKeys, id: \.self) { key in
                                if key.hasPrefix("separator") {
                                    Divider()
                                        .padding(.top, 6)
                                        .padding(.bottom, 6)
                                }
                                else if key.hasPrefix("label:") {
                                    HStack {
                                        Text(key.replacingOccurrences(of: "label:", with: ""))
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                        Spacer()
                                    }
                                    .padding(.bottom, 6)
                                }
                                else {
                                    HStack {
                                        HStack {
                                            // You can get more logo images from:
                                            // https://cryptologos.cc/ethereum
                                            cryptoLogo(key)
                                            Text("\(settings[key]?.name ?? key)")
                                            Spacer()
                                        }
                                        .frame(width: CONTROL_CAPTION_WIDTH)

                                        TextField("", text: binding(key: key))
                                            .textFieldStyle(.roundedBorder)
                                    }

                                    if let description = settings[key]?.description,
                                        description.count > 0
                                    {
                                        HStack {
                                            HStack {
                                                Spacer()
                                            }
                                            .frame(width: CONTROL_CAPTION_WIDTH + 10)

                                            Text(
                                                description
                                            )
                                            .font(.footnote)
                                            .foregroundColor(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)

                                            Spacer()
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                    .tabItem {
                        Text("Mint Settings")
                    }
                }

                HStack(spacing: 8) {
                    Spacer()

                    Button {
                        PlanetStore.shared.isConfiguringMint = false
                    } label: {
                        Text("Cancel")
                            .frame(width: 50)
                    }
                    .keyboardShortcut(.escape, modifiers: [])

                    Button {
                        debugPrint("Template-level user settings: \(userSettings)")
                        Task {
                            planet.updateTemplateSettings(settings: userSettings)
                            try? planet.copyTemplateSettings()
                            try await planet.publish()
                        }
                        dismiss()
                    } label: {
                        Text("OK")
                            .frame(width: 50)
                    }
                }

            }.padding(PlanetUI.SHEET_PADDING)
        }
        .padding(0)
        .frame(width: 560, alignment: .top)
        .onAppear {
            currentSettings = planet.templateSettings()
            for (key, value) in currentSettings {
                userSettings[key] = value
            }
        }
    }

    private func binding(key: String) -> Binding<String> {
        return Binding<String>(
            get: {
                return userSettings[key] ?? planet.template?.settings?[key]?.defaultValue ?? ""
            },
            set: {
                userSettings[key] = $0
            }
        )
    }

    @ViewBuilder
    private func cryptoLogo(_ key: String) -> some View {
        if key == "ethereumMainnetRPC"
            || key == "ethereumSepoliaRPC"
        {
            Image("eth-logo")
                .interpolation(.high)
                .resizable()
                .frame(width: LOGO_SIZE, height: LOGO_SIZE)
        }
        if key == "optimismMainnetRPC"
            || key == "optimismSepoliaRPC"
        {
            Image("op-logo")
                .interpolation(.high)
                .resizable()
                .frame(width: LOGO_SIZE, height: LOGO_SIZE)
        }
        if key == "arbitrumMainnetRPC"
            || key == "arbitrumSepoliaRPC"
        {
            Image("arb-logo")
                .interpolation(.high)
                .resizable()
                .frame(width: LOGO_SIZE, height: LOGO_SIZE)
        }
        if key == "baseMainnetRPC"
            || key == "baseSepoliaRPC"
        {
            Image("base-logo")
                .interpolation(.high)
                .resizable()
                .frame(width: LOGO_SIZE, height: LOGO_SIZE)
        }
    }
}
