//
//  CreatePlanetView.swift
//  Planet
//
//  Created by Kai on 1/15/22.
//

import SwiftUI


struct CreatePlanetView: View {
    @EnvironmentObject private var planetStore: PlanetStore

    @Environment(\.dismiss) private var dismiss

    @State private var planetName: String = ""
    @State private var planetDescription: String = ""

    var body: some View {
        VStack (spacing: 0) {
            Text("New Planet")
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
                    dismiss()
                    Task.init(priority: .utility) {
                        let (keyName, keyID) = await PlanetManager.shared.generateKeys()
                        guard let keyName = keyName else {
                            return
                        }
                        guard let keyID = keyID else {
                            return
                        }
                        if keyName != "" && keyID != "" {
                            let _ = PlanetDataController.shared.createPlanet(
                                    withID: UUID(uuidString: keyName)!,
                                    name: planetName, about: planetDescription,
                                    keyName: keyName,
                                    keyID: keyID,
                                    ipns: keyID
                            )
                            PlanetDataController.shared.save()
                        }
                    }
                } label: {
                    Text("Create")
                }
                .disabled(planetName.count > 0 ? false : true)
            }
            .padding(16)
        }
        .padding(0)
        .frame(width: 480, height: 300, alignment: .center)
    }
}

struct CreatePlanetView_Previews: PreviewProvider {
    static var previews: some View {
        CreatePlanetView()
            .environmentObject(PlanetStore.shared)
            .frame(width: 480, height: 300, alignment: .center)
    }
}
