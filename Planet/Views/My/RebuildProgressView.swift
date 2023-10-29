//
//  RebuildProgressView.swift
//  Planet
//
//  Created by Xin Liu on 5/12/23.
//

import SwiftUI

struct RebuildProgressView: View {
    @State var completed = 0
    @State var total = 0
    @State var progress: Double = 0

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                if case .myPlanet(let planet) = PlanetStore.shared.selectedView {
                    planet.smallAvatarAndNameView(label: "Rebuilding \(planet.name)")
                } else {
                    Text("Rebuilding")
                }
                Spacer()
                Text("\(completed)/\(total) items done")
                    // TODO: - use a better signal to update progress
                    .onReceive(NotificationCenter.default.publisher(for: .myArticleBuilt)) {
                        aNotification in
                        Task { @MainActor in
                            self.completed = self.completed + 1
                            if total == 0 {
                                self.progress = 0
                            } else {
                                self.progress = Double(completed) / Double(total) * 100
                            }
                        }
                    }
                    .onAppear {
                        self.total = PlanetStore.shared.rebuildTasks
                    }
            }
            ProgressView(value: progress, total: 100)
        }
        .frame(width: PlanetUI.SHEET_WIDTH_REBUILD_VIEW)
        .padding(PlanetUI.SHEET_PADDING)
    }
}
