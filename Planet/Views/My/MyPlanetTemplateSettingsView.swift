//
//  MyPlanetTemplateSettingsView.swift
//  Planet
//
//  Created by Xin Liu on 5/17/23.
//

import SwiftUI

struct MyPlanetTemplateSettingsView: View {
    let CONTROL_CAPTION_WIDTH: CGFloat = 140
    let CONTROL_ROW_SPACING: CGFloat = 8

    @Environment(\.dismiss) var dismiss

    @EnvironmentObject var planetStore: PlanetStore
    @ObservedObject var planet: MyPlanetModel

    @State private var currentSettings: [String: String] = [:]
    @State private var userSettings: [String: String] = [:]
    @State private var colors: [String: Color] = [:]

    init(planet: MyPlanetModel) {
        self.planet = planet
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    planet.smallAvatarAndNameView()
                    Spacer()
                }

                TabView {
                    ScrollView {
                        VStack(spacing: CONTROL_ROW_SPACING) {
                            if let template = planet.template, let settings = template.settings,
                                let keys = Array(settings.keys) as? [String]
                            {

                                ForEach(keys.sorted(), id: \.self) { key in
                                    HStack {
                                        HStack {
                                            Text("\(settings[key]?.name ?? "Name")")
                                            Spacer()
                                        }
                                        .frame(width: CONTROL_CAPTION_WIDTH)

                                        TextField("", text: binding(key: key))
                                            .textFieldStyle(.roundedBorder)

                                        if key.hasSuffix("Color") {
                                            ColorPicker(
                                                "",
                                                selection: bindingColor(key: key),
                                                supportsOpacity: false
                                            )
                                        }
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
                        .padding(16)
                    }.frame(minHeight: 340, idealHeight: 410)
                        .tabItem {
                            Text("Template Settings")
                        }
                }

                HStack(spacing: 8) {
                    Button {
                        // Export current settings to a JSON file
                        let now = Int(Date().timeIntervalSince1970)
                        let fileName =
                            "\(planet.template?.id ?? "planet")-template-settings-\(now).json"
                        let savePanel = NSSavePanel()
                        savePanel.allowedFileTypes = ["json"]
                        savePanel.nameFieldStringValue = fileName.lowercased()
                        savePanel.begin { response in
                            if response == .OK, let url = savePanel.url {
                                do {
                                    let data = try JSONSerialization.data(
                                        withJSONObject: userSettings,
                                        options: [.prettyPrinted, .sortedKeys]
                                    )
                                    try data.write(to: url)
                                }
                                catch {
                                    debugPrint("Failed to save template settings: \(error)")
                                }
                            }
                        }
                    } label: {
                        Text("Export")
                            .frame(width: 50)
                    }

                    Button {
                        // Import settings from a JSON file
                        let openPanel = NSOpenPanel()
                        openPanel.allowedFileTypes = ["json"]
                        openPanel.begin { response in
                            if response == .OK, let url = openPanel.url {
                                do {
                                    let data = try Data(contentsOf: url)
                                    let settings =
                                        try JSONSerialization.jsonObject(with: data)
                                        as? [String: String]
                                    if let settings = settings {
                                        for (key, value) in settings {
                                            // If key exists in user settings, update it
                                            if userSettings[key] != nil {
                                                userSettings[key] = value
                                                if key.hasSuffix("Color") {
                                                    colors[key] = Color(hex: value)
                                                }
                                            }
                                        }
                                    }
                                }
                                catch {
                                    debugPrint("Failed to load template settings: \(error)")
                                }
                            }
                        }
                    } label: {
                        Text("Import")
                            .frame(width: 50)
                    }
                    Spacer()

                    Button {
                        PlanetStore.shared.isConfiguringPlanetTemplate = false
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
            let defaultSettings =
                planet.template?.settings?.reduce(into: [:]) { (result, setting) in
                    result[setting.key] = setting.value.defaultValue
                } ?? [:]
            for (key, value) in defaultSettings {
                // If not set, use the default value
                if currentSettings[key] == nil {
                    currentSettings[key] = value
                }
            }
            for (key, value) in currentSettings {
                userSettings[key] = value
                if key.hasSuffix("Color") {
                    colors[key] = Color(hex: value)
                }
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
                if key.hasSuffix("Color") {
                    colors[key] = Color(hex: $0)
                }
            }
        )
    }

    private func bindingColor(key: String) -> Binding<Color> {
        return Binding<Color>(
            get: {
                return colors[key] ?? Color.white
            },
            set: {
                userSettings[key] = $0.toHexValue()
                colors[key] = $0
            }
        )
    }
}
