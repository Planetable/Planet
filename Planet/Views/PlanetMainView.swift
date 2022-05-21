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
                                .help("Toggle Sidebar")
                        }
                    }
                }
                .fileImporter(isPresented: $planetStore.isImportingPlanet, allowedContentTypes: [.data, .package], allowsMultipleSelection: false, onCompletion: { result in
                    if let urls = try? result.get(), let url = urls.first, url.pathExtension == "planet" {
                        PlanetManager.shared.importPath = url
                        PlanetManager.shared.importCurrentPlanet()
                        return
                    }
                    PlanetManager.shared.importPath = nil
                    PlanetManager.shared.alert(title: "Failed to Import Planet", message: "Please try again.")
                })

            Text("No Planet Selected")
                .foregroundColor(.secondary)
                .font(.system(size: 14, weight: .regular))
                .frame(minWidth: 200)

            //Text("No Article Selected")
            //    .foregroundColor(.secondary)
            //    .frame(minWidth: 320)

            PlanetArticleView()
                .environmentObject(planetStore)
                .frame(minWidth: 320)
        }
        .alert(isPresented: $planetStore.isAlert) {
            Alert(title: Text(PlanetManager.shared.alertTitle), message: Text(PlanetManager.shared.alertMessage), dismissButton: Alert.Button.cancel(Text("OK"), action: {
                PlanetManager.shared.alertTitle = ""
                PlanetManager.shared.alertMessage = ""
            }))
        }
        .fileImporter(isPresented: $planetStore.isExportingPlanet, allowedContentTypes: [.directory], allowsMultipleSelection: false, onCompletion: { result in
            if let urls = try? result.get(), let url = urls.first {
                PlanetManager.shared.exportPath = url
                PlanetManager.shared.exportCurrentPlanet()
                return
            }
            PlanetManager.shared.exportPath = nil
            PlanetManager.shared.alert(title: "Failed to Export Planet", message: "Please try again.")
        })
        .sheet(isPresented: $planetStore.isShowingPlanetInfo) {
            if let planet = planetStore.currentPlanet {
                PlanetAboutView(planet: planet)
                    .environmentObject(planetStore)
            }
        }
        .sheet(isPresented: $planetStore.isEditingPlanet) {
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
