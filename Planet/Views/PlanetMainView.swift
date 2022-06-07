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
                .fileImporter(
                    isPresented: $planetStore.isImportingPlanet,
                    allowedContentTypes: [.data, .package]
                ) { result in
                    if let url = try? result.get(),
                       url.pathExtension == "planet" {
                        do {
                            let planet = try Planet.importMyPlanet(importURL: url)
                            PlanetStore.shared.currentPlanet = planet
                            return
                        } catch PlanetError.PlanetExistsError {
                            PlanetManager.shared.alert(
                                title: "Failed to Import Planet",
                                message: "The planet already exists."
                            )
                            return
                        } catch PlanetError.ImportPlanetError {
                            PlanetManager.shared.alert(
                                title: "Failed to Import Planet",
                                message: """
                                         Please try again. \
                                         If the problem persists, the planet backup may be corrupted.
                                         """
                            )
                            return
                        } catch PlanetError.IPFSError {
                            PlanetManager.shared.alert(
                                title: "Failed to Import Planet",
                                message: "There is an error in IPFS. Please try again."
                            )
                            return
                        } catch {}
                    }
                    PlanetManager.shared.alert(
                        title: "Failed to Import Planet",
                        message: " Please try again."
                    )
                }

            Text("No Planet Selected")
                .foregroundColor(.secondary)
                .font(.system(size: 14, weight: .regular))
                .frame(minWidth: 200)

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
        .fileImporter(
            isPresented: $planetStore.isExportingPlanet,
            allowedContentTypes: [.directory]
        ) { result in
            if let url = try? result.get(),
               let planet = planetStore.currentPlanet,
               planet.isMyPlanet() {
                do {
                    try planet.export(exportDirectory: url)
                    return
                } catch PlanetError.FileExistsError {
                    PlanetManager.shared.alert(
                        title: "Failed to Export Planet",
                        message: """
                                 There is already an exported Planet in the destination. \
                                 We do not recommend override your backup. \
                                 Please choose another destination, or rename your previous backup.
                                 """
                    )
                    return
                } catch {
                    // use general alert
                }
            }
            PlanetManager.shared.alert(title: "Failed to Export Planet", message: "Please try again.")
        }
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
