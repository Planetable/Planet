//
//  MyPlanetPodcastSettingsView.swift
//  Planet
//
//  Created by Xin Liu on 10/7/22.
//

import SwiftUI

struct MyPlanetPodcastSettingsView: View {
    let CONTROL_CAPTION_WIDTH: CGFloat = 80
    let CONTROL_ROW_SPACING: CGFloat = 8

    @Environment(\.dismiss) var dismiss

    @EnvironmentObject var planetStore: PlanetStore
    @ObservedObject var planet: MyPlanetModel
    @State private var name: String

    @State private var podcastCategories: [String: [String]]?
    @State private var podcastLanguage: String = "en"
    @State private var podcastExplicit: Bool = false

    let categories: [String: [String]] = PodcastUtils.categories
    @State private var selectedCategories: [String: Bool] = [:]

    init(planet: MyPlanetModel) {
        self.planet = planet
        _name = State(wrappedValue: planet.name)

        _podcastCategories = State(wrappedValue: planet.podcastCategories ?? [:])
        _podcastLanguage = State(wrappedValue: planet.podcastLanguage ?? "en")
        _podcastExplicit = State(wrappedValue: planet.podcastExplicit ?? false)
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
                        HStack {
                            HStack {
                                Text("Cover Art")
                                Spacer()
                            }
                            .frame(width: CONTROL_CAPTION_WIDTH)

                            ArtworkView(image: planet.podcastCoverArt, planetNameInitials: planet.nameInitials, planetID: planet.id, cornerRadius: 10, size: CGSize(width: 128, height: 128), uploadAction: { url in
                                do {
                                    try planet.updatePodcastCoverArt(path: url)
                                } catch {
                                    debugPrint("failed to upload podcast cover art: \(error)")
                                }
                            }, deleteAction: {
                                do {
                                    try planet.removePodcastCoverArt()
                                } catch {
                                    debugPrint("failed to remove podcast cover art: \(error)")
                                }
                            })
                            .padding(.top, 16)
                            .padding(.bottom, 16)

                            Spacer()
                        }

                        HStack {
                            HStack {
                                Text("Language")
                                Spacer()
                            }
                            .frame(width: CONTROL_CAPTION_WIDTH)

                            TextField("", text: $podcastLanguage)
                                .textFieldStyle(.roundedBorder)
                        }

                        HStack {
                            HStack {
                                Spacer()
                            }.frame(width: CONTROL_CAPTION_WIDTH + 10)
                            Toggle(
                                "Podcast contains explicit contents",
                                isOn: $podcastExplicit
                            )
                            .toggleStyle(.checkbox)
                            .frame(alignment: .leading)
                            Spacer()
                        }
                    }
                    .padding(16)
                    .tabItem {
                        Text("General")
                    }

                    VStack(spacing: CONTROL_ROW_SPACING) {
                        LazyVGrid(columns: [GridItem(), GridItem()], alignment: .leading) {
                            ForEach(allCategories, id: \.self) { category in
                                HStack {
                                    Toggle(
                                        category,
                                        isOn: binding(for: category)
                                    )
                                    Spacer()
                                }
                            }
                        }
                    }
                    .padding(16)
                    .tabItem {
                        Text("Categories")
                    }
                    .onAppear {
                        if let podcastCategories = podcastCategories {
                            for category in podcastCategories.keys {
                                self.selectedCategories[category] = true
                            }
                        }
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
                        var newCategories: [String: [String]] = [:]
                        for category in selectedCategories.keys {
                            if let selected = selectedCategories[category], selected {
                                newCategories[category] = []
                            }
                        }
                        planet.podcastCategories = newCategories
                        planet.podcastLanguage = podcastLanguage
                        planet.podcastExplicit = podcastExplicit
                        Task {
                            try planet.save()
                            try planet.copyTemplateAssets()
                            try planet.articles.forEach { try $0.savePublic() }
                            try planet.savePublic()
                            NotificationCenter.default.post(name: .loadArticle, object: nil)
                            try await planet.publish()
                        }
                        dismiss()
                    } label: {
                        Text("OK")
                            .frame(width: 50)
                    }
                    .disabled(name.isEmpty)
                }

            }.padding(20)
        }
        .padding(0)
        .frame(width: 520, height: 460, alignment: .top)
        .task {
            name = planet.name
        }
    }

    private var allCategories: [String] {
        return categories.keys.sorted().map { String($0) }
    }

    private func binding(for category: String) -> Binding<Bool> {
        return Binding(get: {
            return self.selectedCategories[category] ?? false
        }, set: {
            self.selectedCategories[category] = $0
        })
    }
}
