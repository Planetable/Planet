import SwiftUI

struct FollowPlanetView: View {
    @Environment(\.dismiss) var dismiss

    @EnvironmentObject var planetStore: PlanetStore
    @State var link = ""
    @State var isFollowing = false
    @State var isCancelled = false

    var body: some View {
        VStack (spacing: 0) {
            HStack {
                Text("Follow Planet")
                .frame(height: 34, alignment: .leading)
                .padding(.bottom, 2)
                .padding(.horizontal, 16)
                .font(.system(size: 15, weight: .regular, design: .default))
                .background(.clear)

                Spacer()

                HelpLinkButton(helpLink: URL(string: "https://www.planetable.xyz/guides/follow-planet/")!)
                .padding(.horizontal, 16)
            }

            Divider()

            VStack {
                if isFollowing {
                    Text("Following \(link)")
                    ProgressView()
                        .progressViewStyle(.linear)
                } else {
                    TextEditor(text: $link)
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .lineSpacing(4)
                        .disableAutocorrection(true)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.25), lineWidth: 1.0)
                        )
                }
            }
            .frame(height: 60)
            .padding(.all, 16)

            Divider()

            HStack {
                Button {
                    cancelAction()
                } label: {
                    Text("Cancel")
                }
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                Button {
                    followAction()
                } label: {
                    Text("Follow")
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(isFollowing)
            }
            .padding(16)
        }
        .frame(width: 480, alignment: .center)
        .task {
            // Follow a new planet from internal planet link.
            Task { @MainActor in
                guard self.planetStore.followingPlanetLink != "" else { return }
                self.link = self.planetStore.followingPlanetLink
                self.followAction()
            }
        }
    }

    private func processInput() -> String {
        let link = self.link.trimmingCharacters(in: .whitespacesAndNewlines)
        if link.hasPrefix("https://") || link.hasPrefix("http://") {
            if let url = URL(string: link) {
                // If a user pastes a URL like `https://ohlife.eth.sucks/`, we should extract only the ENS part from it: `ohlife.eth`.
                if let host: String = url.host {
                    if host.hasSuffix(".eth.sucks") {
                        return String(host.dropLast(6))
                    }
                    if host.hasSuffix(".eth.limo") {
                        return String(host.dropLast(5))
                    }
                    if host.hasSuffix(".bit.site") {
                        return String(host.dropLast(5))
                    }
                }
            }
        }
        return link
    }

    private func cancelAction() {
        isCancelled = true
        isFollowing = false
        dismiss()
        Task { @MainActor in
            self.planetStore.followingPlanetLink = ""
        }
    }

    private func followAction() {
        isFollowing = true
        let link = processInput()
        debugPrint("Follow Planet: Target \(link)")
        Task {
            do {
                let planet = try await FollowingPlanetModel.follow(link: link)
                if isCancelled {
                    planet.delete()
                } else {
                    planetStore.followingPlanets.insert(planet, at: 0)
                    Task {
                        await planetStore.saveFollowingPlanetsOrder()
                    }
                    Task {
                        await planet.refreshIcon()
                    }
                    Task {
                        await planet.findWalletAddress()
                    }
                    Task.detached(priority: .background) {
                        await planet.pin()
                    }
                    planetStore.selectedView = .followingPlanet(planet)
                }
            } catch PlanetError.PlanetExistsError {
                // ignore
            } catch PlanetError.ENSNoContentHashError {
                if !isCancelled {
                    PlanetStore.shared.alert(
                        title: "Unable to follow planet",
                        message: "This ENS has no contenthash."
                    )
                }
            } catch {
                if !isCancelled {
                    PlanetStore.shared.alert(
                        title: "Failed to follow planet",
                        message: error.localizedDescription
                    )
                }
            }
            isCancelled = false
            isFollowing = false
            dismiss()
            Task { @MainActor in
                self.planetStore.followingPlanetLink = ""
            }
        }
    }
}
