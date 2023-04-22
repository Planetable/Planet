import Foundation
import SwiftUI

struct MyPlanetSidebarItem: View {
    @EnvironmentObject var planetStore: PlanetStore
    @ObservedObject var planet: MyPlanetModel
    @State var isShowingArchiveConfirmation = false
    @State var isShowingDeleteConfirmation = false
    @State var isExportingPlanet = false

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
                    do {
                        try WriterStore.shared.newArticle(for: planet)
                    }
                    catch {
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

            developMenu()

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
                        debugPrint("My Planet Browser URL: \(url.absoluteString)")
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
                Menu("Export Planet") {
                    Button {
                        isExportingPlanet = true
                    } label: {
                        Text("Save as Planet Data File")
                    }
                    Button {
                        airdropPlanet()
                    } label: {
                        Text("Share via AirDrop")
                    }
                }

                Divider()

                Button {
                    isShowingArchiveConfirmation = true
                } label: {
                    Text("Archive Planet")
                }

                Button {
                    isShowingDeleteConfirmation = true
                } label: {
                    Text("Delete Planet")
                }
            }
        }
        .confirmationDialog(
            Text(
                "Are you sure you want to archive this planet? Archived planets will not be auto published. You can later unarchive it from settings."
            ),
            isPresented: $isShowingArchiveConfirmation
        ) {
            Button {
                planet.archive()
                if case .myPlanet(let selectedPlanet) = planetStore.selectedView,
                    planet == selectedPlanet
                {
                    planetStore.selectedView = nil
                }
                planetStore.myArchivedPlanets.insert(planet, at: 0)
                planetStore.myPlanets.removeAll { $0.id == planet.id }
            } label: {
                Text("Archive")
            }
        }
        .confirmationDialog(
            Text("Are you sure you want to delete this planet? This action cannot be undone."),
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
        .fileImporter(
            isPresented: $isExportingPlanet,
            allowedContentTypes: [.directory]
        ) { result in
            if let url = try? result.get() {
                do {
                    try planet.exportBackup(to: url)
                    return
                }
                catch PlanetError.FileExistsError {
                    PlanetStore.shared.alert(
                        title: "Failed to Export Planet",
                        message: """
                            There is already an exported Planet in the destination. \
                            We do not recommend override your backup. \
                            Please choose another destination, or rename your previous backup.
                            """
                    )
                    return
                }
                catch {
                    // use general alert
                }
            }
            PlanetStore.shared.alert(title: "Failed to Export Planet", message: "Please try again.")
        }
    }

    private func hasWorldWideWeb() -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.iconfactory.WorldWideWeb")
            != nil
    }

    private func openWorldWideWeb(_ path: URL) {
        guard
            let appUrl = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: "com.iconfactory.WorldWideWeb"
            )
        else { return }

        let url = URL(fileURLWithPath: path.path)
        NSWorkspace.shared.open(
            [url],
            withApplicationAt: appUrl,
            configuration: self.openConfiguration(),
            completionHandler: nil
        )
    }

    private func openConfiguration() -> NSWorkspace.OpenConfiguration {
        let conf = NSWorkspace.OpenConfiguration()
        conf.hidesOthers = false
        conf.hides = false
        conf.activates = true
        return conf
    }

    private func airdropPlanet() {
        func failedWithErrorDescription(_ description: String) {
            Task { @MainActor in
                self.planetStore.isShowingAlert = true
                self.planetStore.alertTitle = "Failed to Start AirDrop Service"
                self.planetStore.alertMessage = description
            }
        }

        guard let service: NSSharingService = NSSharingService(named: .sendViaAirDrop) else {
            failedWithErrorDescription("Please check your system settings and try again later.")
            return
        }
        let url = URLUtils.temporaryPath
        let planetPath = url.appendingPathComponent(
            "\(planet.name.sanitized()).planet",
            isDirectory: true
        )
        do {
            if FileManager.default.fileExists(atPath: planetPath.path) {
                try FileManager.default.removeItem(at: planetPath)
            }
            try planet.exportBackup(to: url, isForAirDropSharing: true)
            if service.canPerform(withItems: [planetPath]) {
                service.perform(withItems: [planetPath])
            }
            else {
                failedWithErrorDescription("Please check your system settings and try again later.")
            }
        }
        catch {
            try? FileManager.default.removeItem(at: planetPath)
            failedWithErrorDescription(error.localizedDescription)
        }
    }

    @ViewBuilder
    private func developMenu() -> some View {
        Group {
            if hasWorldWideWeb() {
                Button {
                    openWorldWideWeb(planet.publicBasePath)
                } label: {
                    Text("Open in WorldWideWeb Server")
                }
            }

            Button {
                do {
                    try planet.rebuild()
                }
                catch {
                    Task { @MainActor in
                        self.planetStore.isShowingAlert = true
                        self.planetStore.alertTitle = "Failed to Rebuild Planet"
                        self.planetStore.alertMessage = error.localizedDescription
                    }
                }
            } label: {
                Text("Rebuild")
            }
            .keyboardShortcut("r", modifiers: [.command])

            Divider()
        }
    }
}
