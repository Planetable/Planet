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

    var url: URL

    var body: some View {
        VStack(spacing: 0) {
            let key = url.absoluteString.md5()
            let missing = viewModel.missingResources[key] ?? []

            HStack {
                let img = NSWorkspace.shared.icon(forFile: url.path)
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)
                VStack {
                    Text(url.lastPathComponent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(url.absoluteString)
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
                ForEach(missing.sorted(by: { $0.absoluteString > $1.absoluteString }), id: \.self) { url in
                    PlanetImportPreviewItemView(key: key, url: url)
                        .environmentObject(viewModel)
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
