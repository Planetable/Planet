import SwiftUI


struct LoadingIndicatorView: View {
    private let indicatorTimer = Timer.publish(every: 1.25, tolerance: 0.25, on: .current, in: .default).autoconnect()

    @State private var tick = 0
    @State private var icon = "hourglass.bottomhalf.filled"

    var body: some View {
        VStack {
            Image(systemName: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 12, height: 12, alignment: .center)
        }
        .onReceive(indicatorTimer) { _ in
            switch tick {
            case 1:
                icon = "hourglass"
            case 2:
                icon = "hourglass.tophalf.filled"
            default:
                icon = "hourglass.bottomhalf.filled"
            }
            tick += 1
            if tick > 2 {
                tick = 0
            }
        }
    }
}
