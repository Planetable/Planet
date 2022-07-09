import SwiftUI

struct FollowPlanetView: View {
    @Environment(\.dismiss) var dismiss

    @EnvironmentObject var planetStore: PlanetStore
    @State var link = "planet://"
    @State var isFollowing = false
    @State var isCancelled = false

    var body: some View {
        VStack (spacing: 0) {
            Text("Follow Planet")
                .frame(height: 34, alignment: .leading)
                .padding(.bottom, 2)
                .padding(.horizontal, 16)
                .font(.system(size: 15, weight: .regular, design: .default))
                .background(.clear)

            Divider()

            HStack {
                TextEditor(text: $link)
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .lineSpacing(4)
                    .disableAutocorrection(true)
                    .cornerRadius(6)
                    .frame(height: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.25), lineWidth: 1.0)
                    )
            }
            .padding(.all, 16)
            .frame(width: 480)

            Divider()

            HStack {
                Button {
                    isCancelled = true
                    isFollowing = false
                    dismiss()
                } label: {
                    Text("Dismiss")
                }
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                if isFollowing {
                    HStack {
                        ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.5, anchor: .center)
                    }
                    .padding(.horizontal, 4)
                    .frame(height: 10)
                }

                Button {
                    isFollowing = true
                    Task {
                        do {
                            let planet = try await FollowingPlanetModel.follow(link: link)
                            if isCancelled {
                                planet.delete()
                                isCancelled = false
                            } else {
                                planetStore.followingPlanets.insert(planet, at: 0)
                            }
                        } catch {
                            PlanetStore.shared.alert(title: "Failed to follow planet")
                        }
                        isFollowing = false
                        dismiss()
                    }
                } label: {
                    Text("Follow")
                }
                .disabled(isFollowing)
            }
            .padding(16)
        }
        .frame(alignment: .center)
    }
}
