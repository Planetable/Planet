import SwiftUI

struct FollowingPlanetSidebarItem: View {
    @EnvironmentObject var planetStore: PlanetStore
    @ObservedObject var planet: FollowingPlanetModel
    @State var isShowingArchiveConfirmation = false
    @State var isShowingUnfollowConfirmation = false

    var body: some View {
        HStack(spacing: 4) {
            planet.avatarView(size: 24)
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
                    NSPasteboard.general.setString(planet.shareLink.absoluteString, forType: .string)
                } label: {
                    Text("Copy URL")
                }

                Divider()

                Button {
                    isShowingArchiveConfirmation = true
                } label: {
                    Text("Archive Planet")
                }

                Button {
                    isShowingUnfollowConfirmation = true
                } label: {
                    Text("Unfollow")
                }
            }
        }
        .confirmationDialog(
            Text("Are you sure you want to archive this planet? Archived planets will not be auto updated. You can later unarchive it from settings."),
            isPresented: $isShowingArchiveConfirmation
        ) {
            Button() {
                planet.archive()
                if case .followingPlanet(let selectedPlanet) = planetStore.selectedView,
                   planet == selectedPlanet {
                    planetStore.selectedView = nil
                }
                PlanetStore.shared.followingPlanets.removeAll { $0.id == planet.id }
                Task(priority: .background) {
                    PlanetSettingsViewModel.shared.followingArchivedPlanets.insert(planet, at: 0)
                }
            } label: {
                Text("Archive")
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
