//
//  PFDashboardView.swift
//  PublishedFoldersDashboard
//
//  Created by Kai on 11/25/22.
//

import SwiftUI


struct PFDashboardView: View {
    @StateObject private var serviceStore: PlanetPublishedServiceStore

    init() {
        _serviceStore = StateObject(wrappedValue: PlanetPublishedServiceStore.shared)
    }

    var body: some View {
        VStack {
            if let selectedID = serviceStore.selectedFolderID, let folder = serviceStore.publishedFolders.first(where: { $0.id == selectedID }) {
                let folderIsPublishing: Bool = serviceStore.publishingFolders.contains(folder.id)
                if folderIsPublishing {
                    Text(folder.url.path)
                    Text("Publishing ...")
                        .foregroundColor(.secondary)
                        .font(.caption)
                } else if let _ = folder.published, let publishedLink = folder.publishedLink, let url = URL(string: "\(IPFSDaemon.shared.gateway)/ipns/\(publishedLink)") {
                    PFDashboardContentView(url: url)
                } else {
                    Text(folder.url.path)
                    Button {
                        
                    } label: {
                        Text("Publish Folder")
                    }
                }
            } else {
                Text("No Published Folder Selected")
            }
        }
        .frame(minWidth: .contentWidth, idealWidth: .contentWidth, maxWidth: .infinity, minHeight: 320, idealHeight: 320, maxHeight: .infinity, alignment: .center)
    }
}

struct PublishedFoldersDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        PFDashboardView()
    }
}
