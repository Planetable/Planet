import SwiftUI

struct MyPlanetSidebarItem: View {
    @EnvironmentObject var planetStore: PlanetStore
    @ObservedObject var planet: MyPlanetModel
    @State var isShowingDeleteConfirmation = false

    var body: some View {
        HStack(spacing: 4) {
            if let image = planet.avatar {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24, alignment: .center)
                    .cornerRadius(12)
            } else {
                Text(planet.nameInitials)
                    .font(Font.custom("Arial Rounded MT Bold", size: 12))
                    .foregroundColor(Color.white)
                    .contentShape(Rectangle())
                    .frame(width: 24, height: 24, alignment: .center)
                    .background(LinearGradient(
                        gradient: ViewUtils.getPresetGradient(from: planet.id),
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .cornerRadius(12)
            }
            Text(planet.name)
                .font(.body)
                .foregroundColor(.primary)
            Spacer()
            LoadingIndicatorView()
                .opacity(planet.isPublishing ? 1.0 : 0.0)
        }
            .contextMenu {
                VStack {
                    Button {
                        do {
                            try WriterStore.shared.newArticle(for: planet)
                        } catch {
                            PlanetStore.shared.alert(title: "Failed to launch writer")
                        }
                    } label: {
                        Text("New Article")
                    }

                    Button {
                        Task {
                            try await planet.publish()
                        }
                    } label: {
                        Text(planet.isPublishing ? "Publishing" : "Publish Planet")
                    }
                        .disabled(planet.isPublishing)

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString("planet://\(planet.ipns)", forType: .string)
                    } label: {
                        Text("Copy URL")
                    }

                    Button {
                        if let url = planet.browserURL {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Text("Open in Public Gateway")
                    }

                    Divider()

                    Button {
                        isShowingDeleteConfirmation = true
                    } label: {
                        Text("Delete Planet")
                    }
                }
            }
            .confirmationDialog(
                Text("Are you sure you want to delete this planet? This action cannot be undone."),
                isPresented: $isShowingDeleteConfirmation
            ) {
                Button(role: .destructive) {
                    planet.delete()
                    if case .myPlanet(let selectedPlanet) = planetStore.selectedView,
                       planet == selectedPlanet {
                        planetStore.selectedView = nil
                    }
                } label: {
                    Text("Delete")
                }
            }
    }
}
