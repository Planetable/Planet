//
//  IPFSTrafficView.swift
//  Planet
//

import SwiftUI

struct IPFSTrafficView: View {
    @EnvironmentObject private var ipfsState: IPFSState

    var body: some View {
        VStack(spacing: 0) {
            if ipfsState.online {
                titleView()
                chartsView()
            }
            else {
                offlineView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor))
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color("BorderColor"), lineWidth: 1)
        )

    }

    @ViewBuilder
    private func offlineView() -> some View {
        Text("IPFS Daemon Offline")
            .font(.caption)
            .foregroundStyle(Color.secondary)
    }

    @ViewBuilder
    private func titleView() -> some View {
        HStack {
            Text("Bandwidth")
                .font(.subheadline)
                .fontWeight(.medium)
            Spacer(minLength: 1)
            if let now = ipfsState.bandwidths.keys.max(), let stats = ipfsState.bandwidths[now] {
                let i = IPFSState.formatter.string(fromByteCount: Int64(stats.totalIn))
                let o = IPFSState.formatter.string(fromByteCount: Int64(stats.totalOut))
                Text("Total In: \(i) Out: \(o)")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 16)
        .background(Color.secondary.opacity(0.1))
    }

    @ViewBuilder
    private func chartsView() -> some View {
        IPFSTrafficChartView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .environmentObject(ipfsState)
    }

}

#Preview{
    IPFSTrafficView()
}
