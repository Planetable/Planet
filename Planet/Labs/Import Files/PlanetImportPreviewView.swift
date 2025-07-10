//
//  PlanetImportPreviewView.swift
//  Planet
//
//  Created by Kai on 6/27/25.
//

import Foundation
import Cocoa
import SwiftUI


struct PlanetImportPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: PlanetImportViewModel

    var markdownURL: URL

    var body: some View {
        VStack(spacing: 0) {
            let key = markdownURL.absoluteString.md5()
            let missing = viewModel.missingResources[key] ?? []
            HStack {
                let img = NSWorkspace.shared.icon(forFile: markdownURL.path)
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)
                VStack {
                    Text(markdownURL.lastPathComponent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(markdownURL.absoluteString)
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer()
            }
            .padding(PlanetUI.SHEET_PADDING)

            Divider()
                .foregroundStyle(Color.secondary)
                .padding(0)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(missing.sorted(by: { $0.absoluteString > $1.absoluteString }), id: \.self) { url in
                        PlanetImportPreviewItemView(url: url, markdownURL: markdownURL)
                            .environmentObject(viewModel)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
                .foregroundStyle(Color.secondary)
                .padding(0)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Text("Dismiss")
                }
                Spacer()
                if missing.count > 0 {
                    Text("Missing Resources: \(missing.count)")
                        .foregroundStyle(Color.secondary)
                }
                Spacer()
                Button {
                    Task { @MainActor in
                        viewModel.reloadResources()
                    }
                } label: {
                    Text("Reload")
                }
                .disabled(viewModel.validating.count > 0)
            }
            .padding(PlanetUI.SHEET_PADDING)
        }
        .frame(minWidth: PlanetImportWindow.windowMinWidth, idealWidth: PlanetImportWindow.windowMinWidth, maxWidth: .infinity, minHeight: PlanetImportWindow.windowMinHeight, idealHeight: PlanetImportWindow.windowMinHeight, maxHeight: .infinity)
        .padding(0)
    }
}
