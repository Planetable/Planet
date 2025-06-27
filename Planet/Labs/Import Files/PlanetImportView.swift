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
            let isValidating = viewModel.validating.count > 0
            ScrollView {
                ForEach(viewModel.markdownURLs, id: \.self) { url in
                    PlanetImportItemView(url: url)
                        .environmentObject(viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            ZStack {
                HStack {
                    Spacer()
                    Text("Total Files: \(viewModel.markdownURLs.count)")
                        .foregroundStyle(Color.secondary)
                    Spacer()
                }
                HStack {
                    Button {
                        viewModel.cancelImport()
                    } label: {
                        Text("Cancel")
                    }
                    Spacer()
                    Group {
                        if isValidating {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .controlSize(.small)
                                .frame(width: 24)
                        } else {
                            Spacer(minLength: 24)
                        }
                    }
                    .frame(width: 24)
                    Button {
                        // next step
                    } label: {
                        Text("Next")
                    }
                    .disabled(viewModel.markdownURLs.count == 0 || isValidating)
                }
            }
        }
        .frame(minWidth: PlanetImportWindow.windowMinWidth, idealWidth: PlanetImportWindow.windowMinWidth, maxWidth: .infinity, minHeight: PlanetImportWindow.windowMinHeight, idealHeight: PlanetImportWindow.windowMinHeight, maxHeight: .infinity)
        .padding(PlanetUI.SHEET_PADDING)
        .sheet(isPresented: $viewModel.showingPreview, onDismiss: {
            // reload
        }, content: {
            if let previewURL = viewModel.previewURL {
                PlanetImportPreviewView(url: previewURL)
            }
        })
        .task {
            do {
                try await viewModel.prepareToImport()
            } catch {
                failedToImport(error: error)
            }
        }
    }

    // MARK: -

    private func failedToImport(error: Error) {
        let alert = NSAlert()
        alert.messageText = "Failed to Import Files"
        alert.informativeText = error.localizedDescription
        alert.runModal()
        viewModel.cancelImport()
    }
}
