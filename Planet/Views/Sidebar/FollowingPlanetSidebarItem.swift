import SwiftUI

struct FollowingPlanetSidebarItem: View {
    @EnvironmentObject var planetStore: PlanetStore
    @ObservedObject var planet: FollowingPlanetModel
    @State var isShowingUnfollowConfirmation = false

    var body: some View {
        HStack(spacing: 4) {
            if let image = planet.avatar {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24, alignment: .center)
                    .cornerRadius(12)
            }
            else {
                Text(planet.nameInitials)
                    .font(Font.custom("Arial Rounded MT Bold", size: 12))
                    .foregroundColor(Color.white)
                    .contentShape(Rectangle())
                    .frame(width: 24, height: 24, alignment: .center)
                    .background(
                        LinearGradient(
                            gradient: ViewUtils.getPresetGradient(from: planet.id),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(12)
            }
            Text(planet.name)
                .font(.body)
                .foregroundColor(.primary)
            Spacer()
            if planet.isUpdating {
                LoadingIndicatorView()
            }
        }
        .badge(planet.articles.filter { $0.read == nil }.count)
        .contextMenu {
            VStack {
                Button {
                    Task {
                        try await planet.update()
                        planetStore.refreshSelectedArticles()
                    }
                } label: {
                    Text(planet.isUpdating ? "Updating..." : "Check for update")
                }
                .disabled(planet.isUpdating)

                Button {
                    planet.articles.forEach {
                        $0.read = Date()
                        try? $0.save()
                    }
                } label: {
                    Text("Mark All as Read")
                }

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(planet.shareLink, forType: .string)
                } label: {
                    Text("Copy URL")
                }

                Divider()

                Button {
                    isShowingUnfollowConfirmation = true
                } label: {
                    Text("Unfollow")
                }
            }
        }
        .confirmationDialog(
            Text("Are you sure you want to unfollow this planet?"),
            isPresented: $isShowingUnfollowConfirmation
        ) {
            Button(role: .destructive) {
                planetStore.followingPlanets.removeAll { $0.id == planet.id }
                planet.delete()
                if case .followingPlanet(let selectedPlanet) = planetStore.selectedView,
                    planet == selectedPlanet
                {
                    planetStore.selectedView = nil
                }
            } label: {
                Text("Unfollow")
            }
        }

    }
}
