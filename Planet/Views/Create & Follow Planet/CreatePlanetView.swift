import SwiftUI

struct CreatePlanetView: View {
    @Environment(\.dismiss) var dismiss

    @EnvironmentObject var planetStore: PlanetStore
    @State private var name = ""
    @State private var about = ""
    @State private var templateName = (Bundle.main.executableURL?.lastPathComponent == "Croptop") ? "Croptop" : "Plain"
    @State private var creating = false

    var body: some View {
        VStack (spacing: 0) {
            Text(planetStore.app == .planet ? "New Planet" : "New Site")
                .frame(height: 34, alignment: .leading)
                .padding(.bottom, 2)
                .padding(.horizontal, 16)
                .font(.system(size: 15, weight: .regular, design: .default))
                .background(.clear)

            Divider()

            VStack(spacing: 15) {
                HStack {
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

                if planetStore.app == .planet {
                    Picker(selection: $templateName) {
                        ForEach(TemplateStore.shared.templates) { template in
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
                }

                Spacer()
            }
            .padding(.horizontal, 16)

            Divider()

            HStack {
                Button {
                    creating = false
                    dismiss()
                } label: {
                    Text("Cancel")
                }
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                if creating {
                    HStack {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.5, anchor: .center)
                    }
                    .padding(.horizontal, 4)
                    .frame(height: 10)
                }

                Button {
                    creating = true
                    Task {
                        do {
                            let planet = try await MyPlanetModel.create(
                                name: name,
                                about: about,
                                templateName: templateName
                            )
                            planetStore.myPlanets.insert(planet, at: 0)
                            Task(priority: .background) {
                                await PlanetStore.shared.saveMyPlanetsOrder()
                            }
                            planetStore.selectedView = .myPlanet(planet)
                            try planet.save()
                            try await planet.savePublic()
                        } catch {
                            PlanetStore.shared.alert(title: "Failed to create planet")
                        }
                        creating = false
                        dismiss()
                    }
                } label: {
                    Text("Create")
                }
                .disabled(creating || name.isEmpty)
            }
            .padding(16)
        }
        .frame(width: 480, alignment: .center)
    }
}
