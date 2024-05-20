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
            } else {
                offlineView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.secondary.opacity(0.05))
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
        let items = getChartItems()
        if items.count > 0 {
            IPFSTrafficChartView(items: items)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .environmentObject(ipfsState)
        } else {
            VStack {
                Text("No data available")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func getChartItems() -> [IPFSTrafficChartItem] {
        var items: [IPFSTrafficChartItem] = []
        let keys = ipfsState.bandwidths.keys.sorted(by: { $0 > $1 })
        for k in keys {
            guard let bandwidth = ipfsState.bandwidths[k] else { continue }
            let item = IPFSTrafficChartItem(id: UUID(), created: k, rateIn: UInt64(bandwidth.rateIn), rateOut: UInt64(bandwidth.rateOut))
            items.append(item)
        }
        return items
    }
}

#Preview {
    IPFSTrafficView()
}
