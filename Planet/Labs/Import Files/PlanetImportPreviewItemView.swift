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

    var url: URL
    var markdownURL: URL

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
        panel.message = "Select resource to update missing url: \(url.path)"
        panel.prompt = "Select"
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        let response = panel.runModal()
        guard response == .OK, panel.urls.count > 0, let updatedURL = panel.urls.first else { return }
        do {
            try viewModel.updateResource(updatedURL, originURL: url, forMarkdown: markdownURL)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Failed to Update Resource"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
}
