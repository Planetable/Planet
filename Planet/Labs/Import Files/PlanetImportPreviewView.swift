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
    var url: URL

    var body: some View {
        VStack {
            Text(url.lastPathComponent)
                .font(.subheadline)
            Text(url.absoluteString)
                .font(.footnote)
                .foregroundStyle(Color.secondary)
            Spacer()
            HStack {
                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                }
                Spacer()
                Button {
                    update()
                } label: {
                    Text("Update")
                }
            }
        }
        .frame(minWidth: PlanetImportWindow.windowMinWidth, idealWidth: PlanetImportWindow.windowMinWidth, maxWidth: .infinity, minHeight: PlanetImportWindow.windowMinHeight, idealHeight: PlanetImportWindow.windowMinHeight, maxHeight: .infinity)
        .padding(PlanetUI.SHEET_PADDING)
    }

    // MARK: -

    private func update() {
        //
        dismiss()
    }
}
