//
//  PFDashboardSidebarView.swift
//  PublishedFoldersDashboard
//
//  Created by Kai on 11/25/22.
//

import SwiftUI

struct PFDashboardSidebarView: View {
    @StateObject private var serviceStore: PlanetPublishedServiceStore
    @StateObject private var planetStore: PlanetStore

    init() {
        _serviceStore = StateObject(wrappedValue: PlanetPublishedServiceStore.shared)
        _planetStore = StateObject(wrappedValue: PlanetStore.shared)
    }
    
    var body: some View {
        VStack (spacing: 18) {
            List(selection: $serviceStore.selectedFolderID) {
                ForEach(serviceStore.publishedFolders, id: \.id) { folder in
                    PFDashboardSidebarItemView(folder: folder)
                        .environmentObject(serviceStore)
                        .environmentObject(planetStore)
                }
            }
            .listStyle(.sidebar)
        }
        .frame(minWidth: PlanetUI.WINDOW_SIDEBAR_WIDTH_MIN, idealWidth: PlanetUI.WINDOW_SIDEBAR_WIDTH_MIN, maxWidth: PlanetUI.WINDOW_SIDEBAR_WIDTH_MAX, minHeight: PlanetUI.WINDOW_CONTENT_HEIGHT_MIN, idealHeight: PlanetUI.WINDOW_CONTENT_HEIGHT_MIN, maxHeight: .infinity)
    }
}

struct PFDashboardSidebarView_Previews: PreviewProvider {
    static var previews: some View {
        PFDashboardSidebarView()
    }
}
