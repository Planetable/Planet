//
//  PlanetImportView.swift
//  Planet
//
//  Created by Kai on 6/20/25.
//

import Foundation
import Cocoa
import SwiftUI


struct PlanetImportView: View {
    @StateObject private var viewModel: PlanetImportViewModel

    init() {
        _viewModel = StateObject(wrappedValue: PlanetImportViewModel.shared)
    }

    var body: some View {
        VStack {
            Text("Import Markdown Files: \(viewModel.markdownURLs.count)")
        }
        .frame(minWidth: PlanetImportWindow.windowMinWidth, idealWidth: PlanetImportWindow.windowMinWidth, maxWidth: .infinity, minHeight: PlanetImportWindow.windowMinHeight, idealHeight: PlanetImportWindow.windowMinHeight, maxHeight: .infinity)
    }
}
