//
//  MyPlanetTemplateSettingsView.swift
//  Planet
//
//  Created by Xin Liu on 5/17/23.
//

import SwiftUI

struct MyPlanetTemplateSettingsView: View {
    let CONTROL_CAPTION_WIDTH: CGFloat = 130
    let CONTROL_ROW_SPACING: CGFloat = 8

    @Environment(\.dismiss) var dismiss

    @EnvironmentObject var planetStore: PlanetStore
    @ObservedObject var planet: MyPlanetModel
    @State private var name: String

    @State private var currentSettings: [String: String] = [:]
    @State private var userSettings: [String: String] = [:]

    init(planet: MyPlanetModel) {
        self.planet = planet
        _name = State(wrappedValue: planet.name)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    planet.smallAvatarAndNameView()
                    Spacer()
                }

                TabView {
                    VStack(spacing: CONTROL_ROW_SPACING) {
                        if let template = planet.template, let settings = template.settings,
                            let keys = Array(settings.keys) as? [String]
                        {
                            ForEach(keys, id: \.self) { key in
                                HStack {
                                    HStack {
                                        Text("\(settings[key]?.name ?? "Name")")
                                        Spacer()
                                    }
                                    .frame(width: CONTROL_CAPTION_WIDTH)

                                    TextField("", text: binding(key: key))
                                        .textFieldStyle(.roundedBorder)
                                }

                                if let description = settings[key]?.description {
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
                    .padding(16)
                    .tabItem {
                        Text("Template Settings")
                    }
                }

                HStack(spacing: 8) {
                    Spacer()

                    Button {
                        dismiss()
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
        .frame(width: 520, alignment: .top)
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
}
