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
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Spacer()

            Divider()

            HStack {
                Button {
                    dismiss()
                } label: {
                    Text("Dismiss")
                }
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                Button {
                    dismiss()
                    if PlanetDataController.shared.getFollowingIPNSs().contains(processedEndpoint()) {
                        return
                    }
                    // If endpoint ends with .eth, create it as a Type 1 ENS Planet
                    if processedEndpoint().hasSuffix(".eth") {
                        if let planet = PlanetDataController.shared.createPlanetENS(ens: processedEndpoint()) {
                            Task.init(priority: .background) {
                                await PlanetDataController.shared.checkUpdateForPlanetENS(planet: planet)
                            }
                        }
                    } else {
                        if let planet = PlanetDataController.shared.createPlanet(withID: UUID(), name: "", about: "", keyName: nil, keyID: nil, ipns: processedEndpoint()) {
                            Task.init(priority: .background) {
                                await PlanetManager.shared.updateForPlanet(planet: planet)
                            }
                        }
                    }
                } label: {
                    Text("Follow")
                }
            }
            .padding(16)
        }
        .padding(0)
        .frame(width: 480, height: 260, alignment: .center)
    }

    private func processedEndpoint() -> String {
        if endpoint.hasPrefix("planet://") {
            endpoint = endpoint.replacingOccurrences(of: "planet://", with: "")
        }
        return endpoint
    }
}

struct FollowPlanetView_Previews: PreviewProvider {
    static var previews: some View {
        FollowPlanetView()
            .environmentObject(PlanetStore.shared)
            .frame(width: 480, height: 260, alignment: .center)
    }
}
