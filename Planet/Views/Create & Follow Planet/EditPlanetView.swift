//
//  EditPlanetView.swift
//  Planet
//
//  Created by Kai on 2/26/22.
//

import SwiftUI


struct EditPlanetView: View {
    @EnvironmentObject private var planetStore: PlanetStore

    @Environment(\.dismiss) private var dismiss

    var planet: Planet

    @State private var name: String = ""
    @State private var about: String = ""
    @State private var templateName: String = ""

    var body: some View {
        VStack(spacing: 0) {
            Text("Edit Planet")
                .frame(height: 34, alignment: .leading)
                .padding(.bottom, 2)
                .padding(.horizontal, 16)
                .font(.system(size: 15, weight: .regular, design: .default))
                .background(.clear)

            Divider()

            VStack(spacing: 15) {
                HStack(alignment: .top) {
                    HStack {
                        Text("Name")
                        Spacer()
                    }
                    .frame(width: 70)

                    TextField("", text: $name)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.top, 16)

                HStack(alignment: .top) {
                    HStack {
                        Text("About")
                        Spacer()
                    }
                    .frame(width: 70)

                    TextEditor(text: $about)
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

                Picker(selection: $templateName) {
                    ForEach(TemplateBrowserStore.shared.templates) { template in
                        Text(template.name)
                            .tag(template.name)
                    }
                } label: {
                    HStack {
                        Text("Template")
                        Spacer()
                    }
                    .frame(width: 70)
                }
                .pickerStyle(.menu)

                Spacer()
            }
            .padding(.horizontal, 16)

            Divider()

            HStack {
                Button {
                    dismiss()
                } label: {
                    Text("Close")
                }
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                Button {
                    if !name.isEmpty {
                        planet.name = name
                    }
                    planet.about = about
                    planet.templateName = templateName
                    try? FileManager.default.removeItem(at: planet.assetsURL)

                    // re-render all articles
                    let articles = PlanetDataController.shared.getArticles(byPlanetID: planet.id!)
                    for article in articles {
                        try? PlanetManager.shared.renderArticle(article)
                    }
                    PlanetDataController.shared.save()
                    NotificationCenter.default.post(name: .refreshArticle, object: nil)
                    dismiss()

                    Task.init {
                        if !planet.isPublishing {
                            planet.isPublishing = true
                            do {
                                try await PlanetManager.shared.publish(planet)
                            } catch {}
                            planet.isPublishing = false
                        }
                    }
                } label: {
                    Text("Save")
                }
                .disabled(name.isEmpty)
            }
            .padding(16)
        }
        .padding(0)
        .frame(width: 480, height: 300, alignment: .center)
        .task {
            name = planet.name ?? ""
            about = planet.about ?? ""
            templateName = planet.templateName ?? "Plain"
        }
    }
}

struct EditPlanetView_Previews: PreviewProvider {
    static var previews: some View {
        EditPlanetView(planet: Planet())
            .environmentObject(PlanetStore.shared)
            .frame(width: 480, height: 300, alignment: .center)
    }
}
