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
                    Spacer()
                }
                HStack {
                    Text(url.absoluteString)
                        .foregroundStyle(Color.secondary)
                    Spacer()
                }
            }
            Spacer(minLength: 16)
            if !isValid {
                Button {
                    Task { @MainActor in
                        viewModel.previewMarkdownURL = url
                        viewModel.showingPreview = true
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 12, height: 12)
                        Text("Missing Resources")
                            .fontWeight(.light)
                    }
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.bottom, 6)
        .padding(.horizontal, 0)
        .task {
            await validateAction()
        }
        .onChange(of: viewModel.previewUpdated) { _ in
            Task.detached(priority: .userInitiated) {
                await validateAction()
            }
        }
    }

    private func validateAction() async {
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
