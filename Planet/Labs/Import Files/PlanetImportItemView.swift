//
//  PlanetImportItemView.swift
//  Planet
//
//  Created by Kai on 6/27/25.
//

import Foundation
import SwiftUI


struct PlanetImportItemView: View {
    @EnvironmentObject private var viewModel: PlanetImportViewModel

    @State private var isValid: Bool = true

    var url: URL

    var body: some View {
        HStack {
            VStack {
                HStack {
                    Text(url.lastPathComponent)
                        .font(.subheadline)
                    Spacer()
                }
                HStack {
                    Text(url.absoluteString)
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                    Spacer()
                }
            }
            Spacer(minLength: 16)
            if !isValid {
                Button {
                    Task { @MainActor in
                        viewModel.previewURL = url
                        viewModel.showingPreview = true
                    }
                } label: {
                    Label("Missing Resources", systemImage: "exclamationmark.circle")
                        .foregroundStyle(Color.orange)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.bottom, 6)
        .padding(.horizontal, 0)
        .task {
            do {
                let valid = try await viewModel.validateMarkdown(url)
                await MainActor.run {
                    isValid = valid
                }
            } catch {
                await MainActor.run {
                    isValid = false
                }
            }
        }
    }
}
