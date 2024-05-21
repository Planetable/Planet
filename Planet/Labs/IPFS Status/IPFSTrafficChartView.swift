//
//  IPFSTrafficChartView.swift
//  Planet
//

import SwiftUI


struct IPFSTrafficChartItem: Identifiable, Hashable {
    var id: UUID
    var created: Int
    var rateIn: UInt64
    var rateOut: UInt64
    
    static var sampleData: [Self] = {
        let now = Date()
        var its: [Self] = []
        for index in 0..<120 {
            let randomIn = UInt64.random(in: 0..<1000000)
            let randomOut = UInt64.random(in: 0..<1000000)
            let now = Int(now.addingTimeInterval(5).timeIntervalSince1970)
            let it = IPFSTrafficChartItem(id: UUID(), created: now, rateIn: randomIn, rateOut: randomOut)
            its.append(it)
        }
        return its
    }()
    
    static var halfSampleData: [Self] = {
        let now = Date()
        var its: [Self] = []
        for index in 0..<60 {
            let randomIn = UInt64.random(in: 0..<1000000)
            let randomOut = UInt64.random(in: 0..<1000000)
            let now = Int(now.addingTimeInterval(5).timeIntervalSince1970)
            let it = IPFSTrafficChartItem(id: UUID(), created: now, rateIn: randomIn, rateOut: randomOut)
            its.append(it)
        }
        return its
    }()
}


struct IPFSTrafficChartView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var ipfsState: IPFSState

    var items: [IPFSTrafficChartItem]
    
    static let itemSpacing: CGFloat = 0.5
    static let inBGColor: Color = Color.blue.opacity(0.25)
    static let inBGColorDark: Color = Color.blue.opacity(0.45)
    static let inLabelColor: Color = Color.primary.opacity(0.8)
    static let outBGColor: Color = Color.red.opacity(0.35)
    static let outBGColorDark: Color = Color.red.opacity(0.5)
    static let outLabelColor: Color = Color.primary.opacity(0.7)

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { g in
                VStack(spacing: 0) {
                    trafficIn(size: g.size)
                    trafficOut(size: g.size)
                }
            }
            timelineLabel()
        }
        .padding(0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func trafficIn(size: CGSize) -> some View {
        let width = size.width
        let height = size.height / 2.0
        ZStack {
            timelineTraffic(width: width, height: height, isInTraffic: true)
            timelineTrafficLabel(width: width, height: height, isInTraffic: true)
        }
    }
    
    @ViewBuilder
    private func trafficOut(size: CGSize) -> some View {
        let width = size.width
        let height = size.height / 2.0
        ZStack {
            timelineTraffic(width: width, height: height, isInTraffic: false)
            timelineTrafficLabel(width: width, height: height, isInTraffic: false)
        }
    }
    
    @ViewBuilder
    private func timelineLabel() -> some View {
        HStack {
            Text("10m ago")
            Spacer()
            Text("5m ago")
            Spacer()
            Text("Now")
        }
        .foregroundStyle(Color.secondary)
        .font(.footnote)
        .padding(.horizontal, 4)
        .frame(height: 14)
    }
    
    @ViewBuilder
    private func timelineTrafficLabel(width: CGFloat, height: CGFloat, isInTraffic: Bool) -> some View {
        let rate: String = {
            let prefix = isInTraffic ? "In" : "Out"
            if let now = ipfsState.bandwidths.keys.max(), let stats = ipfsState.bandwidths[now] {
                let o = IPFSState.formatter.string(fromByteCount: Int64(isInTraffic ? stats.rateIn : stats.rateOut))
                return prefix + " \(o)/s"
            } else {
                return prefix
            }
        }()
        VStack {
            if !isInTraffic {
                Spacer()
                Text(rate)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .foregroundStyle(Self.outLabelColor)
                    .padding(.trailing, 8)
                    .padding(.bottom, 4)
            } else {
                Text(rate)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .foregroundStyle(Self.outLabelColor)
                    .padding(.trailing, 8)
                    .padding(.top, 4)
                Spacer()
            }
        }
        .frame(width: width, height: height, alignment: .trailing)
    }
    
    @ViewBuilder
    private func timelineTraffic(width: CGFloat, height: CGFloat, isInTraffic: Bool) -> some View {
        let max: CGFloat = {
            var rates: [CGFloat] = items.map { it in
                return CGFloat(it.rateIn)
            }
            rates.append(contentsOf: items.map { it in
                return CGFloat(it.rateOut)
            })
            return rates.max()!
        }()
        let maxItemWidth: CGFloat = {
            let w = width / 120.0 - Self.itemSpacing
            if w <= 1 {
                return 1
            }
            return w
        }()
        let itemWidth: CGFloat = {
            let w = width / CGFloat(items.count) - Self.itemSpacing
            if w <= 0 {
                return maxItemWidth
            }
            return w
        }()
        let bgColor: Color = {
            if colorScheme == .dark {
                return isInTraffic ? Self.inBGColorDark : Self.outBGColorDark
            } else {
                return isInTraffic ? Self.inBGColor : Self.outBGColor
            }
        }()
        HStack(spacing: Self.itemSpacing) {
            ForEach(items, id: \.id) { item in
                VStack(spacing: 0) {
                    let itemHeight: CGFloat = {
                        let h = CGFloat(isInTraffic ? item.rateIn : item.rateOut) / max * height
                        if h < 1.0 {
                            return 1.0
                        }
                        return h
                    }()
                    if isInTraffic {
                        Spacer(minLength: 0)
                        Rectangle()
                            .frame(maxWidth: maxItemWidth)
                            .frame(width: itemWidth, height: itemHeight)
                            .foregroundStyle(bgColor)
                    } else {
                        Rectangle()
                            .frame(maxWidth: maxItemWidth)
                            .frame(width: itemWidth, height: itemHeight)
                            .foregroundStyle(bgColor)
                        Spacer(minLength: 0)
                    }
                }
                .frame(maxWidth: maxItemWidth)
                .frame(height: height)
            }
        }
        .frame(width: width, height: height, alignment: .trailing)
    }
}


#Preview {
    IPFSTrafficChartView(items: IPFSTrafficChartItem.sampleData)
        .frame(width: 320, height: 100)
        .environmentObject(IPFSState.shared)
}

#Preview {
    IPFSTrafficChartView(items: IPFSTrafficChartItem.halfSampleData)
        .frame(width: 320, height: 100)
        .environmentObject(IPFSState.shared)
}

#Preview {
    IPFSTrafficChartView(items: IPFSTrafficChartItem.sampleData)
        .frame(width: 480, height: 180)
        .environmentObject(IPFSState.shared)
}
