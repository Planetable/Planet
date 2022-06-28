//
//  PlanetSidebarView.swift
//  Planet
//
//  Created by Kai on 2/20/22.
//

import SwiftUI

struct PlanetSidebarView: View {
    @EnvironmentObject var planetStore: PlanetStore
    @StateObject var ipfs = IPFSState.shared

    @State var isShowingDeleteConfirmation = false

    var body: some View {
        VStack {
            List {
                Section(header: Text("Smart Feeds")) {
                    NavigationLink(
                        destination: ArticleListView(articles: getTodayArticles()),
                        tag: PlanetDetailViewType.today,
                        selection: $planetStore.selectedView
                    ) {
                        SmartFeedView(feedType: .today)
                    }
                    NavigationLink(
                        destination: ArticleListView(articles: getUnreadArticles()),
                        tag: PlanetDetailViewType.unread,
                        selection: $planetStore.selectedView
                    ) {
                        SmartFeedView(feedType: .unread)
                    }
                    NavigationLink(
                        destination: ArticleListView(articles: getStarredArticles()),
                        tag: PlanetDetailViewType.starred,
                        selection: $planetStore.selectedView
                    ) {
                        SmartFeedView(feedType: .starred)
                    }
                }

                Section(header: Text("My Planets")) {
                    ForEach(planetStore.myPlanets) { planet in
                        NavigationLink(
                            destination: ArticleListView(articles: planet.articles),
                            tag: PlanetDetailViewType.myPlanet(planet),
                            selection: $planetStore.selectedView
                        ) {
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

                Section(header: Text("Following Planets")) {
                    ForEach(planetStore.followingPlanets) { planet in
                        NavigationLink(
                            destination: ArticleListView(articles: planet.articles),
                            tag: PlanetDetailViewType.followingPlanet(planet),
                            selection: $planetStore.selectedView
                        ) {
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
                                if planet.isUpdating {
                                    LoadingIndicatorView()
                                }
                            }
                                .badge(planet.articles.filter { $0.read == nil }.count)
                        }
                            .contextMenu {
                                VStack {
                                    Button {
                                        Task {
                                            try await planet.update()
                                            try planet.save()
                                        }
                                    } label: {
                                        Text(planet.isUpdating ? "Updating..." : "Check for update")
                                    }
                                        .disabled(planet.isUpdating)

                                    Button {
                                        planet.articles.forEach { $0.read = Date() }
                                        try? planet.save()
                                    } label: {
                                        Text("Mark All as Read")
                                    }

                                    Button {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString("planet://\(planet.link)", forType: .string)
                                    } label: {
                                        Text("Copy URL")
                                    }

                                    Divider()

                                    Button {
                                        planetStore.followingPlanets.removeAll { $0.id == planet.id }
                                        planet.delete()
                                        if case .followingPlanet(let selectedPlanet) = planetStore.selectedView,
                                           planet == selectedPlanet {
                                            planetStore.selectedView = nil
                                        }
                                    } label: {
                                        Text("Unfollow")
                                    }
                                }
                            }
                    }
                }
            }
                .listStyle(.sidebar)

            HStack(spacing: 6) {
                Circle()
                    .frame(width: 11, height: 11, alignment: .center)
                    .foregroundColor(ipfs.online ? Color.green : Color.red)
                Text(ipfs.online ? "Online (\(ipfs.peers))" : "Offline")
                    .font(.body)

                Spacer()

                Menu {
                    Button {
                        planetStore.isCreatingPlanet = true
                    } label: {
                        Label("Create Planet", systemImage: "plus")
                    }
                        .disabled(planetStore.isCreatingPlanet)

                    Divider()

                    Button {
                        planetStore.isFollowingPlanet = true
                    } label: {
                        Label("Follow Planet", systemImage: "plus")
                    }
                } label: {
                    Image(systemName: "plus")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24, alignment: .center)
                }
                    .padding(EdgeInsets(top: 2, leading: 10, bottom: 2, trailing: 0))
                    .frame(width: 24, height: 24, alignment: .center)
                    .menuStyle(BorderlessButtonMenuStyle())
                    .menuIndicator(.hidden)
            }
                .frame(height: 44)
                .padding(.leading, 16)
                .padding(.trailing, 10)
                .background(Color.secondary.opacity(0.05))
        }
            .padding(.bottom, 0)
            .sheet(isPresented: $planetStore.isFollowingPlanet) {
                FollowPlanetView()
            }
            .sheet(isPresented: $planetStore.isCreatingPlanet) {
                CreatePlanetView()
            }
    }

    func getTodayArticles() -> [ArticleModel] {
        var articles: [ArticleModel] = []
        articles.append(contentsOf: planetStore.followingPlanets.flatMap { myPlanet in
            myPlanet.articles.filter { $0.created.timeIntervalSinceNow > -86400 }
        })
        articles.append(contentsOf: planetStore.myPlanets.flatMap { followingPlanet in
            followingPlanet.articles.filter { $0.created.timeIntervalSinceNow > -86400 }
        })
        articles.sort { $0.created > $1.created }
        return articles
    }

    func getUnreadArticles() -> [ArticleModel] {
        var articles = planetStore.followingPlanets.flatMap { followingPlanet in
            followingPlanet.articles.filter { $0.read == nil }
        }
        articles.sort { $0.created > $1.created }
        return articles
    }

    func getStarredArticles() -> [ArticleModel] {
        var articles: [ArticleModel] = []
        articles.append(contentsOf: planetStore.followingPlanets.flatMap { myPlanet in
            myPlanet.articles.filter { $0.starred != nil }
        })
        articles.append(contentsOf: planetStore.myPlanets.flatMap { followingPlanet in
            followingPlanet.articles.filter { $0.starred != nil }
        })
        articles.sort { $0.starred! > $1.starred! }
        return articles
    }
}
