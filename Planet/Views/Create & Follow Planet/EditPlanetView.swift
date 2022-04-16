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

    @State private var planetName: String = ""
    @State private var planetDescription: String = ""

    var body: some View {
        VStack(spacing: 0) {
            Text("Edit Planet")
                .frame(height: 34, alignment: .leading)
                .padding(.bottom, 2)
                .padding(.horizontal, 16)
                .font(.system(size: 15, weight: .regular, design: .default))
                .background(.clear)

            Divider()

            HStack {
                VStack(spacing: 15) {
                    HStack {
                        HStack {
                            Text("Name")
                            Spacer()
                        }
                        .frame(width: 50)

                        TextField("", text: $planetName)
                        .textFieldStyle(.roundedBorder)
                    }
                    .padding(.top, 16)

                    HStack {
                        VStack {
                            HStack {
                                Text("About")
                                Spacer()
                            }
                            .frame(width: 50)

                            Spacer()
                        }

                        VStack {
                            TextEditor(text: $planetDescription)
                                .font(.system(size: 13, weight: .regular, design: .default))
                                .lineSpacing(8)
                                .disableAutocorrection(true)
                                .cornerRadius(6)
                                .frame(height: 80)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.secondary.opacity(0.25), lineWidth: 1.0)
                                )

                            Spacer()
                        }
                    }
                }
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
                    Task.init {
                        PlanetDataController.shared.updatePlanet(planet: planet, name: planetName, about: planetDescription)
                        await PlanetManager.shared.publish(planet)
                        PlanetDataController.shared.save()
                        dismiss()
                    }
                } label: {
                    Text("Save")
                }
                .disabled(planetName.isEmpty)
            }
            .padding(16)
        }
        .padding(0)
        .frame(width: 480, height: 300, alignment: .center)
        .task {
            planetName = planet.name ?? ""
            planetDescription = planet.about ?? ""
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
