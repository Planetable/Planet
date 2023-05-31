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
                ForEach(planetStore.myPlanets) { planet in
                    AppSidebarItemView(planet: planet)
                        .environmentObject(planetStore)
                        .tag(PlanetDetailViewType.myPlanet(planet))
                }
                .onMove { (indexes, dest) in
                    withAnimation {
                        planetStore.moveMyPlanets(fromOffsets: indexes, toOffset: dest)
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
                
                Button {
                    planetStore.isCreatingPlanet = true
                } label: {
                    Image(systemName: "plus")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 14, height: 14, alignment: .center)
                }
                .disabled(planetStore.isCreatingPlanet)
                .buttonStyle(.plain)
            }
            .frame(height: 44)
            .padding(.leading, 16)
            .padding(.trailing, 10)
            .background(Color.secondary.opacity(0.05))
        }
        .alert(isPresented: $planetStore.isShowingAlert) {
            Alert(
                title: Text(PlanetStore.shared.alertTitle),
                message: Text(PlanetStore.shared.alertMessage),
                dismissButton: Alert.Button.cancel(Text("OK")) {
                    PlanetStore.shared.alertTitle = ""
                    PlanetStore.shared.alertMessage = ""
                }
            )
        }
        .sheet(isPresented: $planetStore.isCreatingPlanet) {
            CreatePlanetView()
                .environmentObject(planetStore)
        }
        .sheet(isPresented: $planetStore.isShowingPlanetInfo) {
            if case .myPlanet(let planet) = planetStore.selectedView {
                MyPlanetInfoView(planet: planet)
                    .environmentObject(planetStore)
            }
        }
        .sheet(isPresented: $planetStore.isEditingPlanet) {
            if case .myPlanet(let planet) = planetStore.selectedView {
                MyPlanetEditView(planet: planet)
                    .environmentObject(planetStore)
            }
        }
        .sheet(isPresented: $planetStore.isRebuilding) {
            RebuildProgressView()
        }
        .sheet(isPresented: $planetStore.isQuickSharing) {
            PlanetQuickShareView()
                .frame(width: .sheetWidth, height: .sheetHeight + 28)
        }
        .frame(minWidth: PlanetUI.WINDOW_SIDEBAR_WIDTH_MIN, idealWidth: PlanetUI.WINDOW_SIDEBAR_WIDTH_MIN, maxWidth: PlanetUI.WINDOW_SIDEBAR_WIDTH_MAX, minHeight: PlanetUI.WINDOW_CONTENT_HEIGHT_MIN, idealHeight: PlanetUI.WINDOW_CONTENT_HEIGHT_MIN, maxHeight: .infinity)
    }
}

struct AppSidebarView_Previews: PreviewProvider {
    static var previews: some View {
        AppSidebarView()
    }
}
