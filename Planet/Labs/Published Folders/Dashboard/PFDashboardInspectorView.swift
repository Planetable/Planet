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
            Text("Inspector")
        }
    }
}

struct PFDashboardInspectorView_Previews: PreviewProvider {
    static var previews: some View {
        PFDashboardInspectorView()
    }
}
