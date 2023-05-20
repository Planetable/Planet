//
//  AppContentView.swift
//  PlanetLite
//
//  Created by Kai on 5/20/23.
//

import SwiftUI


struct AppContentView: View {
    @StateObject private var appViewModel: AppViewModel
    
    init() {
        _appViewModel = StateObject(wrappedValue: AppViewModel.shared)
    }

    var body: some View {
        VStack {
            Text("Content View: \(appViewModel.selectedViewName ?? "")")
        }
        .navigationTitle(appViewModel.selectedViewName ?? "")
        .navigationSubtitle("")
        .frame(minWidth: AppUI.WINDOW_CONTENT_WIDTH_MIN, idealWidth: AppUI.WINDOW_CONTENT_WIDTH_MIN, maxWidth: .infinity, minHeight: AppUI.WINDOW_CONTENT_HEIGHT_MIN, idealHeight: AppUI.WINDOW_CONTENT_HEIGHT_MIN, maxHeight: .infinity, alignment: .center)
    }
}

struct AppContentView_Previews: PreviewProvider {
    static var previews: some View {
        AppContentView()
    }
}
