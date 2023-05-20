//
//  AppSidebarView.swift
//  PlanetLite
//
//  Created by Kai on 5/20/23.
//

import SwiftUI


struct AppSidebarView: View {
    @StateObject private var appViewModel: AppViewModel
    
    init() {
        _appViewModel = StateObject(wrappedValue: AppViewModel.shared)
    }

    var body: some View {
        List(selection: $appViewModel.selectedViewName) {
            Text("Content A")
                .tag("Content A")
            Text("Content B")
                .tag("Content B")
            Text("Content C")
                .tag("Content C")
        }
        .listStyle(.sidebar)
        .frame(minWidth: AppUI.WINDOW_SIDEBAR_WIDTH_MIN, idealWidth: AppUI.WINDOW_SIDEBAR_WIDTH_MIN, maxWidth: AppUI.WINDOW_SIDEBAR_WIDTH_MAX, minHeight: AppUI.WINDOW_CONTENT_HEIGHT_MIN, idealHeight: AppUI.WINDOW_CONTENT_HEIGHT_MIN, maxHeight: .infinity)
    }
}

struct AppSidebarView_Previews: PreviewProvider {
    static var previews: some View {
        AppSidebarView()
    }
}
