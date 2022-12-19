//
//  PFDashboardView.swift
//  PublishedFoldersDashboard
//
//  Created by Kai on 11/25/22.
//

import SwiftUI


struct PFDashboardView: View {
    @StateObject private var serviceStore: PlanetPublishedServiceStore
    
    @State private var url: URL?

    init() {
        _serviceStore = StateObject(wrappedValue: PlanetPublishedServiceStore.shared)
    }

    var body: some View {
        VStack {
            if let url = url {
                if let selectedID = serviceStore.selectedFolderID, let folder = serviceStore.publishedFolders.first(where: { $0.id == selectedID }) {
                    let folderIsPublishing: Bool = serviceStore.publishingFolders.contains(folder.id)
                    if !FileManager.default.fileExists(atPath: folder.url.path) {
                        missingPublishedFolderView(folder: folder)
                    } else if folderIsPublishing {
                        publishingFolderView(folder: folder)
                    } else if let _ = folder.published {
                        PFDashboardContentView(url: url)
                    } else {
                        readyToPublishFolderView(folder: folder)
                    }
                } else {
                    noPublishedFolderSelectedView()
                }
            } else {
                noPublishedFolderSelectedView()
            }
        }
        .frame(minWidth: .contentWidth, idealWidth: .contentWidth, maxWidth: .infinity, minHeight: 320, idealHeight: 320, maxHeight: .infinity, alignment: .center)
        .onReceive(NotificationCenter.default.publisher(for: .dashboardPreviewURL)) { n in
            Task { @MainActor in
                if let u = n.object as? URL {
                    self.url = u.appendingQueryParameters(["t": "\(Date().timeIntervalSince1970)"])
                } else {
                    self.url = nil
                }
            }
        }
    }
    
    @ViewBuilder
    private func missingPublishedFolderView(folder: PlanetPublishedFolder) -> some View {
        VStack {
            Text(folder.url.path)
            Text("Folder is missing")
                .foregroundColor(.secondary)
                .font(.caption)
        }
    }
    
    @ViewBuilder
    private func noPublishedFolderSelectedView() -> some View {
        Text("No Published Folder Selected")
    }
    
    @ViewBuilder
    private func readyToPublishFolderView(folder: PlanetPublishedFolder) -> some View {
        VStack {
            Text(folder.url.path)
            Button {
            } label: {
                Text("Publish Folder")
            }
        }
    }
    
    @ViewBuilder
    private func publishingFolderView(folder: PlanetPublishedFolder) -> some View {
        VStack {
            Text(folder.url.path)
            Text("Publishing ...")
                .foregroundColor(.secondary)
                .font(.caption)
        }
    }
}

struct PublishedFoldersDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        PFDashboardView()
    }
}
