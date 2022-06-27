import SwiftUI

struct AboutFollowingPlanetView: View {
    @Environment(\.dismiss) private var dismiss

    @EnvironmentObject var planetStore: PlanetStore
    @ObservedObject var planet: FollowingPlanetModel
    @State private var isSharing = false
    @State private var planetIPNS = "planet://"

    var body: some View {
        ZStack {
            VStack(alignment: .center) {
                FollowingPlanetAvatarView(planet: planet)
                .padding(.top, 20)
                .padding(.bottom, 5)

                Text(planet.name)
                    .font(.title)

                Text(planet.about)
                    .font(.body)

                Spacer()

                HStack {
                    Button {
                        isSharing = true
                        planetIPNS = "planet://" + planet.link
                    } label: {
                        Text("Share")
                    }

                    Button {
                        Task {
                            try await planet.update()
                            dismiss()
                        }
                    } label: {
                        Text(planet.isUpdating ? "Updating" : "Update")
                    }
                        .disabled(planet.isUpdating)

                    Spacer()

                    Button {
                        planetStore.followingPlanets.removeAll { $0.id == planet.id }
                        planet.delete()
                    } label: {
                        Text("Unfollow")
                    }

                }
            }
                .background(
                    SharingServicePicker(isPresented: $isSharing, sharingItems: [planetIPNS])
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
            }
        }
            .padding()
            .frame(width: 320, height: 260, alignment: .center)
    }

    private func lastUpdatedText() -> String {
        "Updated " + planet.lastRetrieved.relativeDateDescription()
    }
}
