//
//  PlanetMainView.swift
//  Planet
//
//  Created by Kai on 2/20/22.
//

import SwiftUI


struct PlanetMainView: View {
    @EnvironmentObject var planetStore: PlanetStore

    @State private var isInfoAlert: Bool = false
    @State private var isFollowingAlert: Bool = false

    var body: some View {
        NavigationView {
            PlanetSidebarView()
                .frame(minWidth: 200)
                .toolbar {
                    ToolbarItem {
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
                        Task {
                            do {
                                let planet = try await MyPlanetModel.importBackup(from: url)
                                try planet.save()
                                PlanetStore.shared.myPlanets.insert(planet, at: 0)
                            } catch {
                                PlanetStore.shared.alert(title: "Failed to import planet")
                            }
                        }
                    }
                }

            Text("No Planet Selected")
                .foregroundColor(.secondary)
                .font(.system(size: 14, weight: .regular))
                .frame(minWidth: 200, maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    Color(NSColor.textBackgroundColor)
                )
                .toolbar {
                    Spacer()
                }

            PlanetArticleView()
                .frame(minWidth: 320)
                .toolbar {
                    ToolbarItem {
                        Button {
                            do {
                                if case .myPlanet(let planet) = planetStore.selectedView {
                                    try WriterStore.shared.newArticle(for: planet)
                                }
                            } catch {
                                PlanetStore.shared.alert(title: "Failed to launch writer")
                            }
                        } label: {
                            Image(systemName: "square.and.pencil")
                        }
                            .visibility({ () -> ViewVisibility in
                                // use closure as workaround for enum with value
                                if case .myPlanet(_) = planetStore.selectedView {
                                    return .visible
                                } else {
                                    return .gone
                                }
                            }())
                    }

                    ToolbarItem {
                        Button {
                            planetStore.isShowingPlanetInfo = true
                        } label: {
                            Image(systemName: "info.circle")
                        }
                            .visibility({ () -> ViewVisibility in
                                switch planetStore.selectedView {
                                case .today, .unread, .starred:
                                    return .gone
                                default:
                                    return .visible
                                }
                            }())
                    }
                }
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
        .fileImporter(
            isPresented: $planetStore.isExportingPlanet,
            allowedContentTypes: [.directory]
        ) { result in
            if let url = try? result.get(),
               case .myPlanet(let planet) = planetStore.selectedView {
                do {
                    try planet.exportBackup(to: url)
                    return
                } catch PlanetError.FileExistsError {
                    PlanetStore.shared.alert(
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
            PlanetStore.shared.alert(title: "Failed to Export Planet", message: "Please try again.")
        }
        .sheet(isPresented: $planetStore.isShowingPlanetInfo) {
            if case .myPlanet(let planet) = planetStore.selectedView {
                AboutMyPlanetView(planet: planet)
            } else
            if case .followingPlanet(let planet) = planetStore.selectedView {
                AboutFollowingPlanetView(planet: planet)
            }
        }
        .sheet(isPresented: $planetStore.isEditingPlanet) {
            if case .myPlanet(let planet) = planetStore.selectedView {
                EditMyPlanetView(planet: planet)
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
