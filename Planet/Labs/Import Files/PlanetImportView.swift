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
            Spacer()
            HStack {
                Button {
                    viewModel.cancelImport()
                } label: {
                    Text("Cancel")
                }
                Spacer()
                Button {
                    Task {
                        do {
                            try await viewModel.prepareToImport()
                        } catch {
                            debugPrint("failed to process and import: \(error)")
                        }
                    }
                } label: {
                    Text("Next")
                }
                .disabled(viewModel.markdownURLs.count == 0)
            }
        }
        .frame(minWidth: PlanetImportWindow.windowMinWidth, idealWidth: PlanetImportWindow.windowMinWidth, maxWidth: .infinity, minHeight: PlanetImportWindow.windowMinHeight, idealHeight: PlanetImportWindow.windowMinHeight, maxHeight: .infinity)
        .padding(PlanetUI.SHEET_PADDING)
    }
}
