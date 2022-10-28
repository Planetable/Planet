import SwiftUI

struct MyPlanetSidebarItem: View {
    @EnvironmentObject private var planetStore: PlanetStore
    @ObservedObject var planet: MyPlanetModel
    @State var isShowingDeleteConfirmation = false
    @State var isExportingPlanet = false

    var body: some View {
        HStack(spacing: 4) {
            if let image = planet.avatar {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24, alignment: .center)
                    .cornerRadius(12)
            } else {
                Text(planet.nameInitials)
                    .font(Font.custom("Arial Rounded MT Bold", size: 12))
                    .foregroundColor(Color.white)
                    .contentShape(Rectangle())
                    .frame(width: 24, height: 24, alignment: .center)
                    .background(LinearGradient(
                        gradient: ViewUtils.getPresetGradient(from: planet.id),
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .cornerRadius(12)
            }
            Text(planet.name)
                .font(.body)
                .foregroundColor(.primary)
            Spacer()
            LoadingIndicatorView()
                .opacity(planet.isPublishing ? 1.0 : 0.0)
        }
        .onDrop(of: [.plainText], isTargeted: nil, perform: processDrop)
        .contextMenu {
            Group {
                Button {
                    do {
                        try WriterStore.shared.newArticle(for: planet)
                    } catch {
                        PlanetStore.shared.alert(title: "Failed to launch writer")
                    }
                } label: {
                    Text("New Article")
                }

                Button {
                    Task {
                        PlanetStore.shared.selectedView = .myPlanet(planet)
                        PlanetStore.shared.isEditingPlanet = true
                    }
                } label: {
                    Text("Edit Planet")
                }

                Button {
                    Task {
                        PlanetStore.shared.selectedView = .myPlanet(planet)
                        PlanetStore.shared.isEditingPlanetCustomCode = true
                    }
                } label: {
                    Text("Custom Code")
                }

                Button {
                    Task {
                        PlanetStore.shared.selectedView = .myPlanet(planet)
                        PlanetStore.shared.isEditingPlanetPodcastSettings = true
                    }
                } label: {
                    Text("Podcast Settings")
                }

                Button {
                    Task {
                        try await planet.publish()
                    }
                } label: {
                    Text(planet.isPublishing ? "Publishing" : "Publish Planet")
                }
                .disabled(planet.isPublishing)


                Divider()
            }

            Group {
                Menu {
                    if hasWorldWideWeb() {
                        Button {
                            openWorldWideWeb(planet.publicBasePath)
                        } label: {
                            Text("Open in WorldWideWeb Server")
                        }
                    }

                    Button {
                        Task {
                            try planet.copyTemplateAssets()
                            try planet.articles.forEach { try $0.savePublic() }
                            try planet.savePublic()
                        }
                    } label: {
                        Text("Rebuild")
                    }
                } label: {
                    Text("Develop")
                }

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
                    if let url = planet.browserURL {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Text("Open in Public Gateway")
                }

                Divider()
            }

            Group {
                Button {
                    isExportingPlanet = true
                } label: {
                    Text("Export Planet")
                }

                Divider()

                Button {
                    isShowingDeleteConfirmation = true
                } label: {
                    Text("Delete Planet")
                }
            }
        }
        .confirmationDialog(
            Text("Are you sure you want to delete this planet? This action cannot be undone."),
            isPresented: $isShowingDeleteConfirmation
        ) {
            Button(role: .destructive) {
                try? planet.delete()
                if case .myPlanet(let selectedPlanet) = planetStore.selectedView,
                   planet == selectedPlanet {
                    planetStore.selectedView = nil
                }
                PlanetStore.shared.myPlanets.removeAll { $0.id == planet.id }
            } label: {
                Text("Delete")
            }
        }
        .fileImporter(
            isPresented: $isExportingPlanet,
            allowedContentTypes: [.directory]
        ) { result in
            if let url = try? result.get() {
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
    }

    private func processDrop(items: [NSItemProvider]) -> Bool {
        guard let item = items.first else { return false }
        _ = item.loadObject(ofClass: String.self, completionHandler: { articleUUIDString, error in
            if error == nil, let uuidString = articleUUIDString, let articleID = UUID(uuidString: uuidString) {
                debugPrint("moving my article: \(articleID), to my planet: \(planet.id) ...")
                Task(priority: .userInitiated) {
                    do {
                        try await self.planet.importArticle(articleID: articleID)
                    } catch {
                        debugPrint("failed to move article: \(articleID) into planet: \(self.planet)")
                    }
                }
            } else {
                debugPrint("failed to process drop: \(error)")
            }
        })
        return true
    }

    private func hasWorldWideWeb() -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.iconfactory.WorldWideWeb") != nil
    }

    private func openWorldWideWeb(_ path: URL) {
        guard
            let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.iconfactory.WorldWideWeb")
        else { return }

        let url = URL(fileURLWithPath: path.path)
        NSWorkspace.shared.open([url], withApplicationAt: appUrl, configuration: self.openConfiguration(), completionHandler: nil)
    }

    private func openConfiguration() -> NSWorkspace.OpenConfiguration {
        let conf = NSWorkspace.OpenConfiguration()
        conf.hidesOthers = false
        conf.hides = false
        conf.activates = true
        return conf
    }
}
