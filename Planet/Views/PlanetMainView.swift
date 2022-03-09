//
//  PlanetMainView.swift
//  Planet
//
//  Created by Kai on 2/20/22.
//

import SwiftUI


struct PlanetMainView: View {
    @EnvironmentObject private var planetStore: PlanetStore
    @Environment(\.managedObjectContext) private var context

    @State private var isInfoAlert: Bool = false
    @State private var isFollowingAlert: Bool = false

    var body: some View {
        NavigationView {
            PlanetSidebarView()
                .environmentObject(planetStore)
                .environment(\.managedObjectContext, context)
                .frame(minWidth: 200)
                .toolbar {
                    ToolbarItemGroup(placement: .navigation) {
                        Spacer()
                        
                        Button(action: toggleSidebar) {
                            Image(systemName: "sidebar.left")
                                .resizable()
                                .frame(width: 16, height: 16, alignment: .center)
                                .help("Toggle Sidebar")
                        }
                    }
                }
            
            Text("No Planet Selected")
                .foregroundColor(.secondary)
                .frame(minWidth: 200)
            
            Text("No Article Selected")
                .foregroundColor(.secondary)
                .frame(minWidth: 320)
        }
        .alert(isPresented: $planetStore.isFailedAlert) {
            Alert(title: Text(planetStore.failedAlertTitle), message: Text(planetStore.failedAlertMessage), dismissButton: Alert.Button.cancel(Text("OK"), action: {
                DispatchQueue.main.async {
                    self.planetStore.failedAlertTitle = ""
                    self.planetStore.failedAlertMessage = ""
                }
            }))
        }
        .fileImporter(isPresented: $planetStore.isExportingPlanet, allowedContentTypes: [.directory], allowsMultipleSelection: false, onCompletion: { result in
            if let urls = try? result.get(), let url = urls.first {
                self.planetStore.exportPath = url
                PlanetManager.shared.exportCurrentPlanet()
            }
            DispatchQueue.main.async {
                self.planetStore.exportPath = nil
            }
        })
        .sheet(isPresented: $planetStore.isShowingPlanetInfo) {
            
        } content: {
            if let planet = planetStore.currentPlanet {
                PlanetAboutView(planet: planet)
                    .environmentObject(planetStore)
            }
        }
        .sheet(isPresented: $planetStore.isEditingPlanet) {
            
        } content: {
            if let planet = planetStore.currentPlanet {
                EditPlanetView(planet: planet)
                    .environmentObject(planetStore)
            }
        }
    }
    
    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?
            .tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
}

struct PlanetMainView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetMainView()
    }
}
