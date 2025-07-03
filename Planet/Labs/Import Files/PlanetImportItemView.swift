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
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 12, height: 12)
                        Text("Missing Resources")
                            .fontWeight(.light)
                    }
                    .foregroundStyle(Color.orange)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.orange, lineWidth: 1)
                )
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
        .onChange(of: viewModel.previewUpdated) { _ in
            Task.detached(priority: .userInitiated) {
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
}
