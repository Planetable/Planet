import SwiftUI

struct FollowingPlanetInfoView: View {
    @Environment(\.dismiss) private var dismiss

    @EnvironmentObject var planetStore: PlanetStore
    @ObservedObject var planet: FollowingPlanetModel
    @State private var isSharing = false

    var body: some View {
        ZStack {
            VStack(alignment: .center, spacing: 10) {
                FollowingPlanetAvatarView(planet: planet)
                    .padding(.top, 20)
                    .padding(.bottom, 5)

                HStack(spacing: 8) {
                    Text(planet.name)
                    .font(.title)
                    if planet.planetType == .ens {
                        Image("ENS").resizable().frame(width: 16, height: 16)
                    }
                }

                if let attributedString = try? AttributedString(
                    markdown: planet.about
                ) {
                    Text(attributedString)
                        .lineLimit(4)
                        .font(.body)
                        .padding(.leading, 10)
                        .padding(.trailing, 10)
                        .fixedSize(horizontal: false, vertical: true)
                }
                else {
                    Text(planet.about)
                        .lineLimit(4)
                        .font(.body)
                        .font(.body)
                        .padding(.leading, 10)
                        .padding(.trailing, 10)
                        .fixedSize(horizontal: false, vertical: true)
                }

                planet.socialViews()

                Divider()

                HStack {
                    Button {
                        isSharing = true
                    } label: {
                        Text("Share")
                    }
                }.padding(.bottom, 10)
            }
            .background(
                SharingServicePicker(isPresented: $isSharing, sharingItems: [planet.shareLink])
            )

            VStack {
                HStack {
                    Text(lastUpdatedText())
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 16, height: 16, alignment: .center)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .keyboardShortcut(.cancelAction)
                }
                Spacer()
            }.padding(10)
        }
        .padding(0)
        .frame(width: 320, height: nil, alignment: .center)
    }

    private func lastUpdatedText() -> String {
        "Updated " + planet.lastRetrieved.relativeDateDescription()
    }
}
