//
//  IPFSTrafficView.swift
//  Planet
//

import SwiftUI
import Charts


struct IPFSTrafficView: View {
    @EnvironmentObject private var ipfsState: IPFSState

    static let formatter = {
        let byteCountFormatter = ByteCountFormatter()
        byteCountFormatter.allowedUnits = .useAll
        byteCountFormatter.countStyle = .decimal
        return byteCountFormatter
    }()

    var body: some View {
        VStack {
            if ipfsState.online {
                titleView()
                chartsView()
            } else {
                offlineView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.secondary.opacity(0.1))
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    @ViewBuilder
    private func offlineView() -> some View {
        Text("IPFS Daemon Offline")
            .foregroundStyle(Color.secondary)
    }
    
    @ViewBuilder
    private func titleView() -> some View {
        HStack {
            Text("Bandwidth")
                .font(.subheadline)
                .fontWeight(.medium)
            Spacer(minLength: 1)
            if let now = ipfsState.bandwidths.keys.first, let stats = ipfsState.bandwidths[now] {
                let i = Self.formatter.string(fromByteCount: Int64(stats.totalIn))
                let o = Self.formatter.string(fromByteCount: Int64(stats.totalOut))
                Text("Total In: \(i) Out: \(o)")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 16)
        .background(Color.secondary.opacity(0.125))
    }
    
    @ViewBuilder
    private func chartsView() -> some View {
        VStack(spacing: 0) {
            if let now = ipfsState.bandwidths.keys.first, let latest = ipfsState.bandwidths[now] {
                Text("Now in: \(Self.formatter.string(fromByteCount: Int64(latest.rateIn))), out: \(Self.formatter.string(fromByteCount: Int64(latest.rateOut)))")
            } else {
                Text("No data available.")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    IPFSTrafficView()
}
