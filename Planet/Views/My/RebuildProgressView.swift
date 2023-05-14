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
                Text("Rebuilding")
                Spacer()
                Text("\(completed)/\(total) items done")
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
        .frame(width: PlanetUI.SHEET_WIDTH_PROGRESS_VIEW)
        .padding(PlanetUI.SHEET_PADDING)
    }
}
