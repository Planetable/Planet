import SwiftUI

struct PlausiblePopoverView: View {
    @ObservedObject var planet: MyPlanetModel

    var body: some View {
        VStack(spacing: 10) {
            if let metrics = planet.metrics {
                HStack {
                    Text("Visitors Today")
                        .frame(width: 120, alignment: .leading)
                    Text("\(metrics.visitorsToday)")
                        .fontWeight(.bold)
                        .frame(width: 60, alignment: .trailing)
                }
                HStack {
                    Text("Pageviews Today")
                        .frame(width: 120, alignment: .leading)
                    Text("\(metrics.pageviewsToday)")
                        .fontWeight(.bold)
                        .frame(width: 60, alignment: .trailing)
                }
            } else {
                HStack(spacing: 10) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.5, anchor: .center)
                    Text("Loading Analytics Data")
                }
            }
            if let plausibleDomain = planet.plausibleDomain {
                Divider()
                Button("Full Analytics on Plausible.io") {
                    let url = URL(string: "https://plausible.io/\(plausibleDomain)")!
                    if NSWorkspace.shared.open(url) {
                    }
                }.buttonStyle(.link)
            }
        }.padding()
    }
}
