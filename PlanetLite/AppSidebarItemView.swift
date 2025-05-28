//
//  AppSidebarItemView.swift
//  PlanetLite
//

import SwiftUI

struct AppSidebarItemView: View {
    @EnvironmentObject var planetStore: PlanetStore
    @ObservedObject var planet: MyPlanetModel

    @State private var isShowingDeleteConfirmation = false

    // TODO: Some duplicated code here, needs to be refactored

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

    private func revealTemplateInFinder(_ template: Template) {
        let url = URL(fileURLWithPath: template.path.path)
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
    }

    private func openTemplateInTerminal(_ template: Template) {
        guard
            let appUrl = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: "com.apple.Terminal"
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

    private func hasVSCode() -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.VSCode") != nil
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

    @ViewBuilder
    private func devFeatures() -> some View {
        Group {
            Button {
                Task(priority: .background) {
                    do {
                        try await planet.rebuild()
                    } catch {
                        Task { @MainActor in
                            self.planetStore.isShowingAlert = true
                            self.planetStore.alertTitle = "Failed to Rebuild Planet"
                            self.planetStore.alertMessage = error.localizedDescription
                        }
                    }
                }
            } label: {
                Image(systemName: "goforward")
                Text("Rebuild Site")
            }

            if hasWorldWideWeb() {
                Button {
                    openWorldWideWeb(planet.publicBasePath)
                } label: {
                    Image(systemName: "globe")
                    Text("Open Site in WorldWideWeb Server")
                }
            }

            if let template = planet.template {
                Button(action: {
                    revealTemplateInFinder(template)
                }) {
                    Image(systemName: "folder")
                    Text("Reveal Template in Finder")
                }

                Button(action: {
                    openTemplateInTerminal(template)
                }) {
                    Image(systemName: "terminal.fill")
                    Text("Open Template in Terminal")
                }

                if hasVSCode() {
                    Button {
                        openVSCode(template)
                    } label: {
                        Image(systemName: "pencil")
                        Text("Open Template in VSCode")
                    }
                }
            }

            Divider()
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            planet.avatarView(size: 24)
            Text(planet.name)
                .font(.custom("Capsules", size: 14, relativeTo: .body))
                .foregroundColor(.primary)
            Spacer()
            if planet.isPublishing {
                LoadingIndicatorView()
            } else {
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
                    Task {
                        try await planet.publish()
                    }
                } label: {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                    Text(planet.isPublishing ? "Publishing" : "Publish Site")
                }
                .disabled(planet.isPublishing)

                Divider()

                Button {
                    Task {
                        PlanetStore.shared.selectedView = .myPlanet(planet)
                        PlanetStore.shared.isEditingPlanet = true
                    }
                } label: {
                    Image(systemName: "gear")
                    Text("Site Settings")
                }

                if let template = planet.template, template.hasSettings {
                    Button {
                        Task {
                            PlanetStore.shared.selectedView = .myPlanet(planet)
                            PlanetStore.shared.isConfiguringMint = true
                        }
                    } label: {
                        Image(systemName: "dollarsign")
                        Text("Monetization")
                    }
                }

                Button {
                    Task {
                        PlanetStore.shared.selectedView = .myPlanet(planet)
                        PlanetStore.shared.isEditingPlanetCustomCode = true
                    }
                } label: {
                    Image(systemName: "chevron.left.slash.chevron.right")
                    Text("Custom Code")
                }

                Button {
                    Task {
                        PlanetStore.shared.selectedView = .myPlanet(planet)
                        PlanetStore.shared.isConfiguringAggregation = true
                    }
                } label: {
                    if #available(macOS 15.0, *) {
                        Image(systemName: "square.and.arrow.down.badge.clock")
                    }
                    Text("Aggregation")
                }

                planet.batchDeleteMenu()

                Divider()
            }

            if let _ = UserDefaults.standard.string(forKey: "CroptopDevMode") {
                devFeatures()
            }

            Group {
                Button {
                    if let url = planet.browserURL {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(url.absoluteString, forType: .string)
                    }
                } label: {
                    Text("Copy Shareable Link")
                }

                Button {
                    if let url = planet.browserURL {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Text("Open Shareable Link in Browser")
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
                    if let url = URL(string: "\(IPFSState.shared.getGateway())/ipns/\(planet.ipns)") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Text("Test Site in Browser")
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
                        try planet.exportBackup(to: url, isCroptopSiteData: true)
                    }
                    catch PlanetError.FileExistsError {
                        PlanetStore.shared.alert(
                            title: "Failed to Export Site",
                            message: """
                                There is already an exported Site in the destination. \
                                We do not recommend override your backup. \
                                Please choose another destination, or rename your previous backup.
                                """
                        )
                    }
                    catch {
                        PlanetStore.shared.alert(
                            title: "Failed to Export Site",
                            message: "Please try again."
                        )
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
