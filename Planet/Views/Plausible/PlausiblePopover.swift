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
                Button {
                    let plausibleServer = planet.plausibleAPIServer ?? "plausible.io"
                    let url = URL(string: "https://\(plausibleServer)/\(String(plausibleDomain.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""))")!
                    if NSWorkspace.shared.open(url) {
                    }
                } label: {
                    Text("Open Dashboard")
                    Image(systemName: "chevron.right.circle.fill")
                }.buttonStyle(.link)
            }
        }.padding()
    }
}
