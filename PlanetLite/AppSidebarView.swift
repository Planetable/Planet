//
//  AppSidebarView.swift
//  PlanetLite
//

import SwiftUI


struct AppSidebarView: View {
    @StateObject private var ipfsState: IPFSState
    @StateObject private var planetStore: PlanetStore
    
    init() {
        _ipfsState = StateObject(wrappedValue: IPFSState.shared)
        _planetStore = StateObject(wrappedValue: PlanetStore.shared)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            List(selection: $planetStore.selectedView) {
                Section(header: Text("My Planets")) {
                    ForEach(planetStore.myPlanets) { planet in
                        Text(planet.name)
                            .tag(PlanetDetailViewType.myPlanet(planet))
                    }
                    .onMove { (indexes, dest) in
                        withAnimation {
                            planetStore.moveMyPlanets(fromOffsets: indexes, toOffset: dest)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            
            HStack(spacing: 6) {
                Circle()
                    .frame(width: 11, height: 11, alignment: .center)
                    .foregroundColor(ipfsState.online ? Color.green : Color.red)
                Text(ipfsState.online ? "Online (\(ipfsState.peers))" : "Offline")
                    .font(.body)

                Spacer()

                Menu {
                    Button {
                        planetStore.isCreatingPlanet = true
                    } label: {
                        Label("Create Planet", systemImage: "plus")
                    }
                    .disabled(planetStore.isCreatingPlanet)

                    Divider()

                    Button {
                        planetStore.isFollowingPlanet = true
                    } label: {
                        Label("Follow Planet", systemImage: "plus")
                    }
                } label: {
                    Image(systemName: "plus")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24, alignment: .center)
                }
                .padding(EdgeInsets(top: 2, leading: 10, bottom: 2, trailing: 0))
                .frame(width: 24, height: 24, alignment: .center)
                .menuStyle(BorderlessButtonMenuStyle())
                .menuIndicator(.hidden)
            }
            .frame(height: 44)
            .padding(.leading, 16)
            .padding(.trailing, 10)
            .background(Color.secondary.opacity(0.05))
        }
        .frame(minWidth: PlanetUI.WINDOW_SIDEBAR_WIDTH_MIN, idealWidth: PlanetUI.WINDOW_SIDEBAR_WIDTH_MIN, maxWidth: PlanetUI.WINDOW_SIDEBAR_WIDTH_MAX, minHeight: PlanetUI.WINDOW_CONTENT_HEIGHT_MIN, idealHeight: PlanetUI.WINDOW_CONTENT_HEIGHT_MIN, maxHeight: .infinity)
    }
}

struct AppSidebarView_Previews: PreviewProvider {
    static var previews: some View {
        AppSidebarView()
    }
}
