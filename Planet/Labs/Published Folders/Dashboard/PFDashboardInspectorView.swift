//
//  PFDashboardInspectorView.swift
//  PublishedFoldersDashboard
//
//  Created by Kai on 11/25/22.
//

import SwiftUI

struct PFDashboardInspectorView: View {
    @StateObject private var serviceStore: PlanetPublishedServiceStore
    @StateObject private var planetStore: PlanetStore
    
    @State private var isHoveringInDirectorySection: Bool = false

    init() {
        _serviceStore = StateObject(wrappedValue: PlanetPublishedServiceStore.shared)
        _planetStore = StateObject(wrappedValue: PlanetStore.shared)
    }
    
    var body: some View {
        VStack {
            if let selectedID = serviceStore.selectedFolderID, let folder = serviceStore.publishedFolders.first(where: { $0.id == selectedID }) {
                inspectorView(forFolder: folder)
            } else {
                noInspectorView()
            }
        }
        .frame(minWidth: .inspectorWidth, maxWidth: .infinity, minHeight: 320, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func noInspectorView() -> some View {
        Text("No Published Folder Selected")
    }
    
    @ViewBuilder
    private func inspectorView(forFolder folder: PlanetPublishedFolder) -> some View {
        ScrollView {
            Section("General") {
                sectionInformationView(name: "Name", content: folder.url.lastPathComponent)
                
                Divider()
                
                ZStack {
                    sectionInformationView(name: "Directory", content: folder.url.path)
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                debugPrint("reveal in finder")
                            } label: {
                                Image(systemName: "magnifyingglass.circle.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 11, height: 11)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        Spacer()
                    }
                    .opacity(isHoveringInDirectorySection ? 1.0 : 0.0)
                }
                .onHover { hovering in
                    self.isHoveringInDirectorySection = hovering
                }
                
                Divider()
                
                sectionInformationView(name: "Last Published", content: folder.published?.dateDescription() ?? "Never")
            }
            .padding(.top, 8)
        }
    }
    
    @ViewBuilder
    private func sectionInformationView(name: String, content: String) -> some View {
        VStack {
            HStack {
                Text(name)
                Spacer(minLength: 1)
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            
            HStack {
                Text(content)
                Spacer(minLength: 1)
            }
            .font(.subheadline)
        }
        .padding(.horizontal, 8)
    }
}

struct PFDashboardInspectorView_Previews: PreviewProvider {
    static var previews: some View {
        PFDashboardInspectorView()
    }
}
