import Foundation
import SwiftUI

struct MyPlanetSidebarItem: View {
    @EnvironmentObject var planetStore: PlanetStore
    @ObservedObject var planet: MyPlanetModel
    @State var isShowingArchiveConfirmation = false
    @State var isShowingDeleteConfirmation = false

    var body: some View {
        HStack(spacing: 4) {
            planet.avatarView(size: 24)
            Text(planet.name)
                .font(.body)
                .foregroundColor(.primary)
            Spacer()
            if planet.isPublishing {
                LoadingIndicatorView()
            }
            else {
                if planet.isPinned {
                    Image(systemName: "externaldrive.fill.badge.checkmark")
                        .foregroundColor(.secondary)
                        .opacity(0.5)
                        .help("Pinned with Pinnable")
                }
            }

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

                Divider()

                Button {
                    if let url = planet.browserURL {
                        debugPrint("My Planet Browser URL: \(url.absoluteString)")
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Text("Open in Public Gateway")
                }

                Button {
                    if let url = URL(string: "\(IPFSState.shared.getGateway())/ipns/\(planet.ipns)") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Text("Open in Local Gateway")
                }

                Divider()

                if let template = planet.template, template.hasSettings {
                    if template.name == "Croptop" {
                        Button {
                            Task {
                                PlanetStore.shared.selectedView = .myPlanet(planet)
                                PlanetStore.shared.isConfiguringMint = true
                            }
                        } label: {
                            Text("Mint Settings")
                        }
                    } else {
                        Button {
                            Task {
                                PlanetStore.shared.selectedView = .myPlanet(planet)
                                PlanetStore.shared.isConfiguringPlanetTemplate = true
                            }
                        } label: {
                            Text("Template Settings")
                        }
                    }

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
                        PlanetStore.shared.isEditingPlanetDonationSettings = true
                    }
                } label: {
                    Text("Accepts Donation")
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
                        PlanetStore.shared.selectedView = .myPlanet(planet)
                        PlanetStore.shared.isConfiguringAggregation = true
                    }
                } label: {
                    Text("Aggregation")
                }

                planet.batchDeleteMenu()

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
                copyMenu()

                Button {
                    Task {
                        PlanetStore.shared.selectedView = .myPlanet(planet)
                        PlanetStore.shared.isShowingPlanetIPNS = true
                    }
                } label: {
                    Text("Show IPNS and CID")
                }

                Divider()
            }

            Group {
                Menu("Export Planet") {
                    Button {
                        do {
                            try exportPlanet()
                        } catch PlanetError.FileExistsError {
                            Task { @MainActor in
                                self.planetStore.isShowingAlert = true
                                self.planetStore.alertTitle = "Failed to Share Planet Data"
                                self.planetStore.alertMessage = """
                                    There is already an exported Planet in the destination.
                                    We do not recommend override your backup.
                                    Please choose another destination, or rename your previous backup.
                                """
                            }
                        } catch {
                            Task { @MainActor in
                                self.planetStore.isShowingAlert = true
                                self.planetStore.alertTitle = "Failed to Share Planet Data"
                                self.planetStore.alertMessage = error.localizedDescription
                            }
                        }
                    } label: {
                        Text("Save as Planet Data File")
                    }
                    Button {
                        do {
                            try airDropPlanet()
                        } catch {
                            Task { @MainActor in
                                self.planetStore.isShowingAlert = true
                                self.planetStore.alertTitle = "Failed to Share Planet Data"
                                self.planetStore.alertMessage = error.localizedDescription
                            }
                        }
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

    private func hasiTerm() -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.googlecode.iterm2") != nil
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

    private func exportPlanet() throws {
        let panel = NSOpenPanel()
        panel.message = "Choose Directory to Export Planet"
        panel.prompt = "Export"
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.folder]
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return }
        try planet.exportBackup(to: url)
    }

    private func airDropPlanet() throws {
        guard let service: NSSharingService = NSSharingService(named: .sendViaAirDrop) else {
            throw PlanetError.ServiceAirDropNotExistsError
        }
        let url = URLUtils.temporaryPath
        let planetPath = url.appendingPathComponent(
            "\(planet.name.sanitized()).planet",
            isDirectory: true
        )
        if FileManager.default.fileExists(atPath: planetPath.path) {
            try FileManager.default.removeItem(at: planetPath)
        }
        try planet.exportBackup(to: url, isForAirDropSharing: true)
        if service.canPerform(withItems: [planetPath]) {
            service.perform(withItems: [planetPath])
        } else {
            throw PlanetError.ServiceAirDropNotExistsError
        }
    }

    private func templateHasGitRepo() -> Bool {
        if let template = planet.template, template.hasGitRepo {
            return true
        }
        return false
    }

    private func openVSCode(_ template: Template) {
        guard
            let appUrl = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: "com.microsoft.VSCode"
            )
        else { return }

        let url = URL(fileURLWithPath: template.path.path)
        NSWorkspace.shared.open(
            [url],
            withApplicationAt: appUrl,
            configuration: self.openConfiguration(),
            completionHandler: nil
        )
    }

    private func openiTerm(_ template: Template) {
        guard
            let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.googlecode.iterm2")
        else { return }

        let url = URL(fileURLWithPath: template.path.path)
        NSWorkspace.shared.open([url], withApplicationAt: appUrl, configuration: self.openConfiguration(), completionHandler: nil)
    }

    @ViewBuilder
    private func copyMenu() -> some View {
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

        if let cid = planet.lastPublishedCID {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(cid, forType: .string)
            } label: {
                Text("Copy CID")
            }
        }
    }

    @ViewBuilder
    private func developMenu() -> some View {
        Group {
            if hasWorldWideWeb() {
                Button {
                    openWorldWideWeb(planet.publicBasePath)
                } label: {
                    Image(systemName: "network")
                    Text("Open in WorldWideWeb Server")
                }
            }

            Button {
                Task(priority: .background) {
                    PlanetStore.shared.selectedView = .myPlanet(planet)
                    do {
                        try await planet.quickRebuild()
                    }
                    catch {
                        Task { @MainActor in
                            self.planetStore.isShowingAlert = true
                            self.planetStore.alertTitle = "Failed to Quick Rebuild Planet"
                            self.planetStore.alertMessage = error.localizedDescription
                        }
                    }
                }
            } label: {
                Image(systemName: "bolt.fill")
                Text("Quick Rebuild")
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])

            Button {
                Task(priority: .background) {
                    PlanetStore.shared.selectedView = .myPlanet(planet)
                    do {
                        try await planet.rebuild()
                    }
                    catch {
                        Task { @MainActor in
                            self.planetStore.isShowingAlert = true
                            self.planetStore.alertTitle = "Failed to Rebuild Planet"
                            self.planetStore.alertMessage = error.localizedDescription
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                Text("Full Rebuild")
            }
            .keyboardShortcut("r", modifiers: [.command])

            if templateHasGitRepo(), let template = planet.template {
                Button {
                    openVSCode(template)
                } label: {
                    Image(systemName: "chevron.left.slash.chevron.right")
                    Text("Edit Template")
                }
            }

            if hasiTerm(), let template = planet.template {
                Button {
                    openiTerm(template)
                } label: {
                    Image(systemName: "apple.terminal.fill")
                    Text("Open in iTerm")
                }
            }

            if let enabled = planet.pinnableEnabled, enabled {
                Button {
                    Task(priority: .background) {
                        await planet.callPinnable()
                    }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Check with Pinnable")
                }
            }

            Divider()
        }
    }
}
