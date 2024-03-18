//
//  PlanetSettingsPublishedFoldersView.swift
//  Planet
//

import SwiftUI


struct PlanetSettingsPublishedFoldersView: View {
    @EnvironmentObject private var serviceStore: PlanetPublishedServiceStore

    var body: some View {
        Form {
            Section {
                VStack {
                    HStack {
                        Text("Option")
                            .frame(width: PlanetUI.SETTINGS_CAPTION_WIDTH, alignment: .trailing)
                        Toggle("Publish Changes Automatically", isOn: $serviceStore.autoPublish)
                            .help("Turn on to publish changes automatically.")
                        Spacer(minLength: 1)
                    }
                    Spacer()
                }
                .padding()
            }
        }
    }
}
