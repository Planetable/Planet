//
//  NewOnboardingView.swift
//  Planet
//
//  Created by Xin Liu on 4/29/25.
//

import SwiftUI

struct NewOnboardingView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("showOnboardingScreen") private var showOnboardingScreen: Bool = true

    private let BANNER_WIDTH: CGFloat = 720
    private let BANNER_HEIGHT: CGFloat = 160
    private let PADDING_LEFT: CGFloat = 30
    private let ICON_WIDTH: CGFloat = 120

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Image("OnboardingBanner")
                    .resizable()
                    .frame(width: BANNER_WIDTH, height: BANNER_HEIGHT)
                    .aspectRatio(contentMode: .fit)

                HStack {
                    Text("Welcome to your websites on your Mac")
                        .font(.title)
                        .padding(.top, (ICON_WIDTH / 2) + 20)
                        .padding(.leading, PADDING_LEFT)

                    Spacer()
                }

                HStack(alignment: .top, spacing: 20) {
                    VStack(alignment: .leading, spacing: 5) {
                        feature(
                            icon: "feature.markdown-editor",
                            title: "Markdown Editor",
                            description: "Two-column Markdown editor for easily previewing changes. Drag-n-drop images, audio, or video. To-do list syntax is supported.",
                            url: "https://planetable.eth.limo/"
                            // TODO: Build a new page about Markdown editor
                        )

                        feature(
                            icon: "feature.templates",
                            title: "Templates",
                            description: "Choose from multiple artfully designed templates, or build your own template.",
                            url: "https://planetable.eth.limo/templates/"
                        )

                        feature(
                            icon: "feature.ipfs",
                            title: "IPFS Publishing",
                            description: "Publish your websites directly to the Internet with IPFS.",
                            url: "https://www.planetable.xyz/guides/local-gateway/"
                            // TODO: Build a new page about IPFS
                        )
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 5) {
                        feature(
                            icon: "feature.rss",
                            title: "Follow Updates",
                            description: "Follow updates from other Planet sites, or RSS. Atom and JSON feeds are also supported.",
                            url: "https://www.planetable.xyz/guides/follow-planet/"
                        )

                        feature(
                            icon: "feature.ens",
                            title: "ENS .eth / SNS .sol",
                            description: "Link your IPFS websites to your blockchain names like Ethereum name (.eth) or Solana name (.sol).",
                            url: "https://www.planetable.xyz/guides/ens/"
                        )

                        feature(
                            icon: "feature.api-access",
                            title: "API Access",
                            description: "Automate, integrate with other systems, do creative things, with Planet RESTful API.",
                            url: "https://github.com/Planetable/Planet/blob/main/Technotes/API.md"
                            // TODO: Build a new page for API
                        )
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.top, 20)
                .padding(.leading, PADDING_LEFT - 10)
                .padding(.trailing, PADDING_LEFT - 10)
                .padding(.bottom, 20)

                Spacer()

                Divider().padding(0)

                HStack(spacing: 0) {
                    Button {
                        Task {
                            try? await FollowingPlanetModel.followFeaturedSources()
                        }
                    } label: {
                        Text("Follow Featured")
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        if (showOnboardingScreen) {
                            Image(systemName: "checkmark.circle.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 16, height: 16)
                                .foregroundColor(.accentColor)
                        } else {
                            Image(systemName: "circle")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 16, height: 16)
                                .foregroundColor(.secondary)
                        }
                        Text("Show this screen when app starts")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .onTapGesture {
                        showOnboardingScreen.toggle()
                    }

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Text("OK")
                        .frame(minWidth: 50)
                    }.buttonStyle(.borderedProminent)
                }.padding(10)
            }

            VStack() {
                HStack {
                    logo()

                    Spacer()
                }

                Spacer()
            }

        }.frame(width: BANNER_WIDTH, height: 640)
    }

    @ViewBuilder
    private func logo() -> some View {
        Image("AppLogo-Original")
            .interpolation(.high)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: ICON_WIDTH, height: ICON_WIDTH)
            .cornerRadius(ICON_WIDTH / 2)
            // 5px border using text background color
            .overlay(
                Circle()
                    .stroke(Color(nsColor: .textBackgroundColor), lineWidth: 5)
            )
            .padding(.top, BANNER_HEIGHT - (ICON_WIDTH / 2))
            .padding(.leading, PADDING_LEFT)
    }

    @ViewBuilder
    private func feature(icon: String, title: String, description: String, url: String) -> some View {
        ClickableHStack(url: url) {
            Image(icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.title2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(description)
                    .font(.body)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ClickableHStack<Content: View>: View {
    let urlString: String
    let content: () -> Content

    @State private var isHovering = false

    init(url: String, @ViewBuilder content: @escaping () -> Content) {
        self.urlString = url
        self.content = content
    }

    var body: some View {
        if #available(macOS 15.0, *) {
            HStack(alignment: .top, spacing: 10) {
                content()
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovering ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.1) : Color.clear)
            )
            .onHover { hovering in
                isHovering = hovering
            }
            .pointerStyle(.link)
            .onTapGesture {
                if let url = URL(string: urlString) {
                    NSWorkspace.shared.open(url)
                }
            }
        } else {
            HStack(alignment: .top, spacing: 10) {
                content()
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovering ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.1) : Color.clear)
            )
            .onHover { hovering in
                isHovering = hovering
            }
            .onTapGesture {
                if let url = URL(string: urlString) {
                    NSWorkspace.shared.open(url)
                }
            }
        }

    }
}

struct NewOnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NewOnboardingView()
        }
    }
}
