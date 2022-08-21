import SwiftUI

struct MyPlanetInfoView: View {
    @Environment(\.dismiss) private var dismiss

    @EnvironmentObject var planetStore: PlanetStore
    @ObservedObject var planet: MyPlanetModel

    @State private var isSharing = false
    @State private var planetIPNS = "planet://"

    var body: some View {
        ZStack {
            VStack(alignment: .center) {
                MyPlanetAvatarView(planet: planet)
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
                        planetIPNS = "planet://\(planet.ipns)"
                    } label: {
                        Text("Share")
                    }

                    Button {
                        Task {
                            try await planet.publish()
                        }
                        dismiss()
                    } label: {
                        Text(planet.isPublishing ? "Publishing" : "Publish")
                    }
                        .disabled(planet.isPublishing)

                    Spacer()

                    Button {
                        planetStore.isEditingPlanet = true
                        dismiss()
                    } label: {
                        Text("Edit")
                    }
                }
            }

                .background(
                    SharingServicePicker(isPresented: $isSharing, sharingItems: [planetIPNS])
                )

            VStack {
                HStack {
                    Text(lastPublishedText())
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button {
                        NotificationCenter.default.post(name: .updateAvatar, object: nil)
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 16, height: 16, alignment: .center)
                    }
                        .buttonStyle(PlainButtonStyle())
                        .keyboardShortcut(.escape, modifiers: [])
                }
                Spacer()
            }
        }
            .padding()
            .frame(width: 320, height: 260, alignment: .center)
    }


    func lastPublishedText() -> String {
        if let published = planet.lastPublished {
            return "Published " + published.relativeDateDescription()
        }
        return "Never Published"
    }
}
