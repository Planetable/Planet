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
    @State private var isHoveringInCIDSection: Bool = false
    @State private var isHoveringInIPNSSection: Bool = false

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
        .frame(minWidth: PlanetUI.WINDOW_INSPECTOR_WIDTH_MIN, idealWidth: PlanetUI.WINDOW_INSPECTOR_WIDTH_MIN, maxWidth: .infinity, minHeight: PlanetUI.WINDOW_CONTENT_HEIGHT_MIN, idealHeight: PlanetUI.WINDOW_CONTENT_HEIGHT_MIN, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func noInspectorView() -> some View {
        Text("")
    }
    
    @ViewBuilder
    private func inspectorView(forFolder folder: PlanetPublishedFolder) -> some View {
        ScrollView {
            Section {
                ZStack {
                    sectionInformationView(name: "Name", content: folder.url.lastPathComponent)
                }
                
                Divider()
                
                ZStack {
                    sectionInformationView(name: "Directory", content: folder.url.path)
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                serviceStore.revealFolderInFinder(folder)
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
                
            } header: {
                sectionHeaderView(name: "General")
            }
            
            Section {
                ZStack {
                    sectionInformationView(name: "CID", content: serviceStore.loadPublishedFolderCID(byFolderID: folder.id) ?? "")
                    VStack {
                        HStack {
                            Spacer()
                            if let folderCID = serviceStore.loadPublishedFolderCID(byFolderID: folder.id) {
                                Button {
                                    let pboard = NSPasteboard.general
                                    pboard.clearContents()
                                    pboard.setString(folderCID, forType: .string)
                                } label: {
                                    Image(systemName: "doc.on.clipboard")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 11, height: 11)
                                }
                                .buttonStyle(.plain)
                                .help("Copy Folder CID")
                            }
                        }
                        .padding(.horizontal, 8)
                        Spacer()
                    }
                    .opacity(isHoveringInCIDSection ? 1.0 : 0.0)
                }
                .onHover { hovering in
                    self.isHoveringInCIDSection = hovering
                }
                
                Divider()
                
                ZStack {
                    if let ipns = folder.publishedLink {
                        sectionInformationView(name: "IPNS", content: ipns)
                    } else {
                        sectionInformationView(name: "IPNS", content: "")
                    }
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                if let ipns = folder.publishedLink {
                                    let pboard = NSPasteboard.general
                                    pboard.clearContents()
                                    pboard.setString(ipns, forType: .string)
                                }
                            } label: {
                                Image(systemName: "doc.on.clipboard")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 11, height: 11)
                            }
                            .buttonStyle(.plain)
                            .disabled(folder.publishedLink == nil)
                            .help("Copy Folder IPNS")
                        }
                        .padding(.horizontal, 8)
                        Spacer()
                    }
                    .opacity(isHoveringInIPNSSection ? 1.0 : 0.0)
                }
                .onHover { hovering in
                    self.isHoveringInIPNSSection = hovering
                }
            } header: {
                sectionHeaderView(name: "Advanced")
            }
        }
    }
    
    @ViewBuilder
    private func sectionHeaderView(name: String) -> some View {
        HStack {
            Text(name)
                .font(.headline)
            Spacer(minLength: 1)
        }
        .padding(7)
        .padding(.bottom, -7)
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
