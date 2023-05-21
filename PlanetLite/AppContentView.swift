//
//  AppContentView.swift
//  PlanetLite
//

import SwiftUI


struct AppContentView: View {
    @StateObject private var planetStore: PlanetStore
    @StateObject private var appViewModel: AppViewModel
    
    init() {
        _planetStore = StateObject(wrappedValue: PlanetStore.shared)
        _appViewModel = StateObject(wrappedValue: AppViewModel.shared)
    }

    var body: some View {
        VStack {
            Text("Content View: \(appViewModel.selectedViewName ?? "")")
        }
        .navigationTitle(appViewModel.selectedViewName ?? "")
        .navigationSubtitle("")
        .frame(minWidth: PlanetUI.WINDOW_CONTENT_WIDTH_MIN, idealWidth: PlanetUI.WINDOW_CONTENT_WIDTH_MIN, maxWidth: .infinity, minHeight: PlanetUI.WINDOW_CONTENT_HEIGHT_MIN, idealHeight: PlanetUI.WINDOW_CONTENT_HEIGHT_MIN, maxHeight: .infinity, alignment: .center)
    }
}

struct AppContentView_Previews: PreviewProvider {
    static var previews: some View {
        AppContentView()
    }
}
