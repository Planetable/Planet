//
//  IPFSTrafficView.swift
//  Planet
//

import SwiftUI
import Charts


struct IPFSTrafficView: View {
    @EnvironmentObject private var ipfsState: IPFSState

    var body: some View {
        VStack {
            Text("Traffic View")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.secondary.opacity(0.1))
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    IPFSTrafficView()
}
