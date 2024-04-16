//
//  PFDashboardView.swift
//  PublishedFoldersDashboard
//
//  Created by Kai on 11/25/22.
//

import SwiftUI


struct PFDashboardView: View {
    @StateObject private var serviceStore: PlanetPublishedServiceStore
    
    @State private var url: URL = Bundle.main.url(forResource: "NoSelection.html", withExtension: "")!
    @State private var contentView: PFDashboardContentView

    init() {
        _serviceStore = StateObject(wrappedValue: PlanetPublishedServiceStore.shared)
        _contentView = State(wrappedValue: PFDashboardContentView(url: .constant(Bundle.main.url(forResource: "NoSelection.html", withExtension: "")!)))
    }

    var body: some View {
        VStack {
            if let selectedID = serviceStore.selectedFolderID, let folder = serviceStore.publishedFolders.first(where: { $0.id == selectedID }) {
                if !FileManager.default.fileExists(atPath: folder.url.path) {
                    missingPublishedFolderView(folder: folder)
                } else if serviceStore.publishingFolders.contains(folder.id) {
                    publishingFolderView(folder: folder)
                } else if let _ = folder.published {
                    contentView
                } else {
                    readyToPublishFolderView(folder: folder)
                }
            } else {
                noPublishedFolderSelectedView()
            }
        }
        .edgesIgnoringSafeArea(.top)
        .frame(minWidth: PlanetUI.WINDOW_CONTENT_WIDTH_MIN, idealWidth: PlanetUI.WINDOW_CONTENT_WIDTH_MIN, maxWidth: .infinity, minHeight: PlanetUI.WINDOW_CONTENT_HEIGHT_MIN, idealHeight: PlanetUI.WINDOW_CONTENT_HEIGHT_MIN, maxHeight: .infinity, alignment: .center)
        .onReceive(NotificationCenter.default.publisher(for: .dashboardResetWebViewHistory)) { n in
            guard let targetFolderID = n.object as? UUID else { return }
            if let selectedID = self.serviceStore.selectedFolderID, let folder = self.serviceStore.publishedFolders.first(where: { $0.id == selectedID }) {
                guard targetFolderID == selectedID else { return }
                self.url = folder.url
                self.contentView = PFDashboardContentView(url: self.$url)
            }
        }
        .onReceive(serviceStore.timer, perform: { _ in
            serviceStore.updateWindowTitles()
        })
        .task {
            serviceStore.restoreSelectedFolderNavigation()
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
                Task { @MainActor in
                    await self.serviceStore.prepareToPublishFolder(folder, skipCIDCheck: true)
                }
            } label: {
                Text("Publish Folder")
            }
        }
    }
    
    @ViewBuilder
    private func publishingFolderView(folder: PlanetPublishedFolder) -> some View {
        VStack(spacing: 8) {
            Text(folder.url.path)
            HStack(spacing: 4) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.small)
                Text("Publishing...")
            }
        }
        .foregroundColor(.secondary)
    }
}

struct PublishedFoldersDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        PFDashboardView()
    }
}
