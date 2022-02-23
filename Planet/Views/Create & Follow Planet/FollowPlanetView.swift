//
//  FollowPlanetView.swift
//  Planet
//
//  Created by Kai on 1/15/22.
//

import SwiftUI


struct FollowPlanetView: View {
    @EnvironmentObject private var planetStore: PlanetStore
    
    @State private var ipns: String = "planet://"

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
                TextEditor(text: $ipns)
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
                    planetStore.isFollowingPlanet = false
                } label: {
                    Text("Dismiss")
                }
                
                Spacer()
                
                Button {
                    planetStore.isFollowingPlanet = false
                    if PlanetDataController.shared.getFollowingIPNSs().contains(processedIPNS()) {
                        return
                    }
                    PlanetDataController.shared.createPlanet(withID: UUID(), name: "", about: "", keyName: nil, keyID: nil, ipns: processedIPNS())
                } label: {
                    Text("Follow")
                }
            }
            .padding(16)
        }
        .padding(0)
        .frame(width: 480, height: 260, alignment: .center)
    }
    
    private func processedIPNS() -> String {
        if ipns.hasPrefix("planet://") {
            ipns = ipns.replacingOccurrences(of: "planet://", with: "")
        }
        return ipns
    }
}

struct FollowPlanetView_Previews: PreviewProvider {
    static var previews: some View {
        FollowPlanetView()
            .environmentObject(PlanetStore.shared)
            .frame(width: 480, height: 260, alignment: .center)
    }
}
