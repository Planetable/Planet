//
//  MigrationProgressView.swift
//  Planet
//
//  Created by Xin Liu on 7/7/22.
//

import SwiftUI

struct MigrationProgressView: View {
    var body: some View {
        VStack(spacing: 10) {
            Text("Migrating data to the new format")
            ProgressView()
                .progressViewStyle(.linear)
        }
        .frame(width: PlanetUI.SHEET_WIDTH_PROGRESS_VIEW)
        .padding(PlanetUI.SHEET_PADDING)
    }
}

struct MigrationProgressView_Previews: PreviewProvider {
    static var previews: some View {
        MigrationProgressView()
    }
}
