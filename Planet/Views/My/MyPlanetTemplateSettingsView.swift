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

    @State private var isShowingResetConfirmation = false
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
                    if let template = planet.template, let settings = template.settings {
                        let basicKeys = settingKeys(in: settings, advanced: false)
                        let advancedKeys = settingKeys(in: settings, advanced: true)

                        settingsList(settings: settings, keys: basicKeys)
                            .tabItem {
                                Text("Template Settings")
                            }

                        if !advancedKeys.isEmpty {
                            settingsList(settings: settings, keys: advancedKeys)
                                .tabItem {
                                    Text("Advanced")
                                }
                        }
                    }
                }

                HStack(spacing: 8) {
                    Button {
                        // Export current settings to a JSON file
                        let now = Int(Date().timeIntervalSince1970)
                        let fileName =
                            "\(planet.template?.id ?? "planet")-template-settings-\(now).json"
                        let savePanel = NSSavePanel()
                        savePanel.allowedContentTypes = [.json]
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
                        openPanel.allowedContentTypes = [.json]
                        openPanel.begin { response in
                            if response == .OK, let url = openPanel.url {
                                do {
                                    let data = try Data(contentsOf: url)
                                    let json = try JSONSerialization.jsonObject(with: data)
                                    let settings = stringTemplateSettings(from: json)
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
                            .frame(minWidth: 50)
                    }
                    Button {
                        isShowingResetConfirmation = true
                    } label: {
                        Text("Defaults")
                            .frame(minWidth: 50)
                    }
                    .confirmationDialog(
                        Text("Are you sure you want to reset all settings to the default values?"),
                        isPresented: $isShowingResetConfirmation
                    ) {
                        Button {
                            let defaultSettings = planet.template?.settings?.reduce(into: [:]) {
                                    (result, setting) in
                                    result[setting.key] = setting.value.defaultValue
                                } ?? [:]
                                for (key, value) in defaultSettings {
                                    userSettings[key] = value
                                    if key.hasSuffix("Color") {
                                        colors[key] = Color(hex: value)
                                    }
                                }
                        } label: {
                            Text("Reset")
                        }
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
                        Task.detached(priority: .userInitiated) {
                            await planet.updateTemplateSettings(settings: userSettings)
                            try await planet.save()
                            Task(priority: .background) {
                                try await planet.rebuild()
                            }
                            NotificationCenter.default.post(name: .loadArticle, object: nil)
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

    private func stringTemplateSettings(from json: Any) -> [String: String]? {
        guard let dict = json as? [String: Any] else {
            return nil
        }
        return dict.reduce(into: [:]) { result, item in
            if let value = item.value as? String {
                result[item.key] = value
            }
            else if isJSONBoolean(item.value), let value = item.value as? Bool {
                result[item.key] = value ? "true" : "false"
            }
            else if let value = item.value as? NSNumber {
                result[item.key] = value.stringValue
            }
        }
    }

    private func isJSONBoolean(_ value: Any) -> Bool {
        return CFGetTypeID(value as CFTypeRef) == CFBooleanGetTypeID()
    }

    private func bindingBoolean(key: String) -> Binding<Bool> {
        return Binding<Bool>(
            get: {
                return booleanValue(
                    from: userSettings[key] ?? planet.template?.settings?[key]?.defaultValue ?? "false"
                )
            },
            set: {
                userSettings[key] = $0 ? "true" : "false"
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

    private func settingKeys(in settings: [String: TemplateSetting], advanced: Bool) -> [String] {
        return settings.keys
            .filter { key in
                isAdvancedSetting(settings[key]) == advanced
            }
            .sorted()
    }

    private func settingsList(settings: [String: TemplateSetting], keys: [String]) -> some View {
        ScrollView {
            VStack(spacing: CONTROL_ROW_SPACING) {
                ForEach(keys, id: \.self) { key in
                    settingRow(key: key, setting: settings[key])
                }
            }
            .padding(16)
        }
        .frame(minHeight: 340, idealHeight: 410)
    }

    @ViewBuilder
    private func settingRow(key: String, setting: TemplateSetting?) -> some View {
        HStack {
            HStack {
                Text(setting?.name ?? L10n("Name"))
                Spacer()
            }
            .frame(width: CONTROL_CAPTION_WIDTH)

            if isBooleanSetting(setting) {
                Toggle("", isOn: bindingBoolean(key: key))
                    .toggleStyle(.switch)
                    .labelsHidden()
                Spacer()
            }
            else {
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
        }

        if let description = setting?.description, description.count > 0 {
            HStack {
                HStack {
                    Spacer()
                }
                .frame(width: CONTROL_CAPTION_WIDTH + 10)

                Text(description)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()
            }
        }
    }

    private func isBooleanSetting(_ setting: TemplateSetting?) -> Bool {
        return setting?.type.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare("boolean") == .orderedSame
    }

    private func isAdvancedSetting(_ setting: TemplateSetting?) -> Bool {
        return setting?.advanced == true
    }

    private func booleanValue(from value: String) -> Bool {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "true", "1", "yes", "on":
            return true
        default:
            return false
        }
    }
}
