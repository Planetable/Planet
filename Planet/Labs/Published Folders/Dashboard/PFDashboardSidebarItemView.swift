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
                            let alert = NSAlert()
                            alert.messageText = "Failed to Publish Folder"
                            alert.informativeText = error.localizedDescription
                            alert.alertStyle = .informational
                            alert.addButton(withTitle: "OK")
                            alert.runModal()
                        }
                    }
                } label: {
                    Text("Publish Folder")
                }
                
                Button {
                    serviceStore.revealFolderInFinder(folder)
                } label: {
                    Text("Reveal in Finder")
                }
                
                Divider()
                
                if let _ = folder.published, let _ = folder.publishedLink {
                    Button {
                        serviceStore.exportFolderKey(folder)
                    } label: {
                        Text("Backup Folder Key")
                    }
                    Divider()
                }
                
                Button {
                    guard !self.serviceStore.publishingFolders.contains(folder.id) else {
                        let alert = NSAlert()
                        alert.messageText = "Failed to Remove Folder"
                        alert.informativeText = "Folder is in publishing progress, please try again later."
                        alert.alertStyle = .informational
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                        return
                    }
                    self.serviceStore.addToRemovingPublishedFolderQueue(folder)
                    let updatedFolders = self.serviceStore.publishedFolders.filter { f in
                        return f.id != folder.id
                    }
                    Task { @MainActor in
                        self.serviceStore.updatePublishedFolders(updatedFolders)
                    }
                } label: {
                    Text("Remove Folder")
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
