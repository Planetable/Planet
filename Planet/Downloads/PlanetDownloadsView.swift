//
//  PlanetDownloadsView.swift
//  Planet
//
//  Created by Kai on 8/1/22.
//

import SwiftUI


struct PlanetDownloadsView: View {
    @StateObject private var downloadsViewModel: PlanetDownloadsViewModel

    init() {
        _downloadsViewModel = StateObject(wrappedValue: PlanetDownloadsViewModel.shared)
    }

    var body: some View {
        VStack (spacing: 0) {
            List(downloadsViewModel.downloads.sorted(by: { $0.created < $1.created }), id: \.id, selection: $downloadsViewModel.selectedDownloadID) { item in
                PlanetDownloadsItemView(item: item)
                    .environmentObject(downloadsViewModel)
            }
            HStack {
                Spacer()
                Button {
                    downloadsViewModel.removeAllDownloads()
                } label: {
                    Text("Clear")
                }
                .disabled(downloadsViewModel.downloads.count == 0)
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 16)
            .frame(height: 32)
            .background(Color.secondary.opacity(0.05))
        }
        .padding(0)
        .frame(minWidth: 320, idealWidth: 320, maxWidth: 640, minHeight: 480, idealHeight: 480, maxHeight: .infinity)
    }
}


struct PlanetDownloadsView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetDownloadsView()
            .frame(width: 320, height: 320)
    }
}
