//
//  FollowPlanetView.swift
//  Planet
//
//  Created by Kai on 1/15/22.
//

import SwiftUI


struct FollowPlanetView: View {
    @EnvironmentObject private var planetStore: PlanetStore

    @Environment(\.dismiss) private var dismiss

    @State private var endpoint: String = "planet://"

    var body: some View {
        VStack (spacing: 0) {
            Text("Follow Planet")
                .frame(height: 34, alignment: .leading)
                .padding(.bottom, 2)
                .padding(.horizontal, 16)
                .font(.system(size: 15, weight: .regular, design: .default))
                .background(.clear)

            Divider()

            HStack {
                TextEditor(text: $endpoint)
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .lineSpacing(4)
                    .disableAutocorrection(true)
                    .cornerRadius(6)
                    .frame(height: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.25), lineWidth: 1.0)
                    )
            }
            .padding(.all, 16)
            .frame(width: 480)

            Divider()

            HStack {
                Button {
                    if let planet = PlanetStore.shared.pendingFollowingPlanet {
                        planet.softDeleted = Date()
                        PlanetStore.shared.pendingFollowingPlanet = nil
                        PlanetDataController.shared.save()
                    }
                    dismiss()
                } label: {
                    Text("Dismiss")
                }
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                if PlanetStore.shared.pendingFollowingPlanet != nil {
                    HStack {
                        ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.5, anchor: .center)
                    }
                    .padding(.horizontal, 4)
                    .frame(height: 10)
                }

                Button {
                    Task {
                        do {
                            try await PlanetManager.shared.followPlanet(url: endpoint)
                            PlanetStore.shared.pendingFollowingPlanet = nil
                            PlanetDataController.shared.save()
                            dismiss()
                        } catch {
                            // TODO: the alert is currently not displaying above follow planet window
                            // PlanetManager.shared.alert(title: "Unable to follow Planet")
                        }
                    }
                } label: {
                    Text("Follow")
                }
                .disabled(PlanetStore.shared.pendingFollowingPlanet != nil)
            }
            .padding(16)
        }
        .padding(0)
        .frame(alignment: .center)
    }
}

struct FollowPlanetView_Previews: PreviewProvider {
    static var previews: some View {
        FollowPlanetView()
            .environmentObject(PlanetStore.shared)
            .frame(width: 480, height: 260, alignment: .center)
    }
}
