//
//  AggregationSettings.swift
//  Planet
//
//  Created by Xin Liu on 9/7/23.
//

import SwiftUI

struct AggregationSettings: View {
    let CONTROL_CAPTION_WIDTH: CGFloat = 100

    @Environment(\.dismiss) var dismiss

    @EnvironmentObject var planetStore: PlanetStore
    @ObservedObject var planet: MyPlanetModel

    @State private var selectedTab: String = "aggregation"

    @State private var newSites: String = ""

    init(planet: MyPlanetModel) {
        self.planet = planet

        let sites: [String] = planet.aggregation ?? []
        _newSites = State(initialValue: sites.joined(separator: "\n"))
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {

                HStack(spacing: 10) {
                    planet.smallAvatarAndNameView()
                    Spacer()
                }

                TabView(selection: $selectedTab) {
                    VStack(spacing: PlanetUI.CONTROL_ROW_SPACING) {
                        HStack {
                            HStack {
                                Text("Sites")
                                Spacer()
                            }
                            .frame(width: CONTROL_CAPTION_WIDTH)

                            TextEditor(text: $newSites)
                                .font(.system(size: 13, weight: .regular, design: .default))
                                .lineSpacing(8)
                                .disableAutocorrection(true)
                                .cornerRadius(6)
                                .frame(height: 80)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.secondary.opacity(0.25), lineWidth: 1.0)
                                )
                        }

                        HStack {
                            HStack {
                                Spacer()
                            }
                            .frame(width: CONTROL_CAPTION_WIDTH + 10)

                            Text(
                                "Please enter the sites you wish to aggregate, one per line. You can use ENS (Ethereum Name Service) or IPNS (InterPlanetary Name System) addresses."
                            )
                            .lineLimit(2)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(16)
                    .tabItem {
                        Text("Aggregation")
                    }
                    .tag("aggregation")
                }

                HStack(spacing: PlanetUI.CONTROL_ITEM_GAP) {
                    Button {
                        Task {
                            try await planet.aggregate()
                            dismiss()
                        }
                    } label: {
                        Text("Aggregate Now")
                    }

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .frame(width: 50)
                    }
                    .keyboardShortcut(.escape, modifiers: [])

                    Button {
                        if verifyUserInput() > 0 {
                            return
                        }

                        let aggregation: [String] = newSites.split(
                            separator: "\n",
                            omittingEmptySubsequences: true
                        ).map(String.init).sorted()

                        planet.aggregation = aggregation

                        Task {
                            try planet.save()
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
        .frame(width: 520, height: nil, alignment: .top)
    }

    private func verifyUserInput() -> Int {
        var errors: Int = 0
        return errors
    }
}
