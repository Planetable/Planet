//
//  PFDashboardSidebarItemView.swift
//  Planet
//
//  Created by Kai on 12/17/22.
//

import SwiftUI


struct PFDashboardSidebarItemView: View {
    @EnvironmentObject private var serviceStore: PlanetPublishedServiceStore
    @EnvironmentObject private var planetStore: PlanetStore
    
    var folder: PlanetPublishedFolder
    
    var body: some View {
        let folderIsPublishing: Bool = serviceStore.publishingFolders.contains(folder.id)
        HStack (spacing: 4) {
            Text(folder.url.lastPathComponent)
                .font(.body)
                .foregroundColor(.primary)
                .lineLimit(2)
            Spacer()
            LoadingIndicatorView()
                .environmentObject(planetStore)
                .opacity(folderIsPublishing ? 1.0 : 0.0)
        }
        .contextMenu {
            if folderIsPublishing {
                Text("Publishing ...")
            } else {
                Button {
                    Task {
                        do {
                            try await self.serviceStore.publishFolder(folder, skipCIDCheck: true)
                        } catch {
                            debugPrint("failed to publish folder: \(folder), error: \(error)")
                        }
                    }
                } label: {
                    Text("Publish Folder")
                }
            }
        }
    }
}

struct PFDashboardSidebarItemView_Previews: PreviewProvider {
    static var previews: some View {
        PFDashboardSidebarItemView(folder: .init(id: UUID(), url: URL(fileURLWithPath: "sample"), created: Date()))
    }
}
