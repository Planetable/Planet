//
//  PlanetImportPreviewItemView.swift
//  Planet
//
//  Created by Kai on 7/3/25.
//

import Foundation
import SwiftUI


struct PlanetImportPreviewItemView: View {
    @EnvironmentObject private var viewModel: PlanetImportViewModel

    var key: String
    var url: URL

    var body: some View {
        HStack {
            Text(url.path)
                .foregroundStyle(Color.orange)
            Spacer(minLength: 8)
            Button {
                locateAction()
            } label: {
                Text("Locate")
            }
            .controlSize(.small)
        }
        .frame(height: 32)
        .padding(.horizontal, 16)
    }

    private func locateAction() {
        let panel = NSOpenPanel()
        panel.message = "Select Resource to Update"
        panel.prompt = "Select"
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        let response = panel.runModal()
        guard response == .OK, panel.urls.count > 0, let updatedURL = panel.urls.first else { return }
        Task { @MainActor in
            viewModel.updateResource(updatedURL, forKey: key)
        }
    }
}
