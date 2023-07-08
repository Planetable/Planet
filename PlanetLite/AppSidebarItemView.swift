//
//  AppSidebarItemView.swift
//  PlanetLite
//

import SwiftUI


struct AppSidebarItemView: View {
    @EnvironmentObject var planetStore: PlanetStore
    @ObservedObject var planet: MyPlanetModel

    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        HStack(spacing: 4) {
            planet.avatarView(size: 24)
            Text(planet.name)
                .font(.body)
                .foregroundColor(.primary)
            Spacer()
            LoadingIndicatorView()
                .opacity(planet.isPublishing ? 1.0 : 0.0)
        }
        .contextMenu {
            Group {
                Button {
                    Task {
                        PlanetStore.shared.selectedView = .myPlanet(planet)
                        PlanetStore.shared.isEditingPlanet = true
                    }
                } label: {
                    Text("Site Settings")
                }

                if let template = planet.template, template.hasSettings {
                    Button {
                        Task {
                            PlanetStore.shared.selectedView = .myPlanet(planet)
                            PlanetStore.shared.isConfiguringCPN = true
                        }
                    } label: {
                        Text("CPN Settings")
                    }
                }

                Button {
                    Task {
                        try await planet.publish()
                    }
                } label: {
                    Text(planet.isPublishing ? "Publishing" : "Publish Site")
                }
                .disabled(planet.isPublishing)

                Divider()
            }

            Group {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("planet://\(planet.ipns)", forType: .string)
                } label: {
                    Text("Copy URL")
                }

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(planet.ipns, forType: .string)
                } label: {
                    Text("Copy IPNS")
                }

                Button {
                    Task {
                        PlanetStore.shared.selectedView = .myPlanet(planet)
                        PlanetStore.shared.isShowingPlanetIPNS = true
                    }
                } label: {
                    Text("Show IPNS and CID")
                }

                Button {
                    if let url = planet.browserURL {
                        debugPrint("My Site Browser URL: \(url.absoluteString)")
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Text("Open in Public Gateway")
                }

                Button {
                    if let url = URL(string: "\(IPFSDaemon.shared.gateway)/ipns/\(planet.ipns)") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Text("Open in Local Gateway")
                }

                Divider()
            }

            Group {
                Button {
                    let panel = NSOpenPanel()
                    panel.message = "Choose Export Location"
                    panel.prompt = "Choose"
                    panel.allowsMultipleSelection = false
                    panel.allowedContentTypes = [.folder]
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    panel.canCreateDirectories = true
                    let response = panel.runModal()
                    guard response == .OK, let url = panel.url else { return }
                    do {
                        try planet.exportBackup(to: url)
                    } catch PlanetError.FileExistsError {
                        PlanetStore.shared.alert(
                            title: "Failed to Export Site",
                            message: """
                                There is already an exported Site in the destination. \
                                We do not recommend override your backup. \
                                Please choose another destination, or rename your previous backup.
                                """
                        )
                    } catch {
                        PlanetStore.shared.alert(title: "Failed to Export Site", message: "Please try again.")
                    }
                } label: {
                    Text("Export Site")
                }

                Divider()

                Button {
                    isShowingDeleteConfirmation = true
                } label: {
                    Text("Delete Site")
                }
            }
        }
        .confirmationDialog(
            Text("Are you sure you want to delete \(planet.name)? This action cannot be undone."),
            isPresented: $isShowingDeleteConfirmation
        ) {
            Button(role: .destructive) {
                try? planet.delete()
                if case .myPlanet(let selectedPlanet) = planetStore.selectedView,
                    planet == selectedPlanet
                {
                    planetStore.selectedView = nil
                }
                PlanetStore.shared.myPlanets.removeAll { $0.id == planet.id }
            } label: {
                Text("Delete")
            }
        }
    }
}
