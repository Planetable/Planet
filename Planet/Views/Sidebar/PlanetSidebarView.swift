//
//  PlanetSidebarView.swift
//  Planet
//
//  Created by Kai on 2/20/22.
//

import SwiftUI

struct PlanetSidebarView: View {
    @EnvironmentObject var planetStore: PlanetStore
    @StateObject var ipfsState = IPFSState.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if planetStore.walletAddress.count > 0 {
                AccountBadgeView(walletAddress: planetStore.walletAddress)
            }
            List(selection: $planetStore.selectedView) {
                Section(header: Text("Smart Feeds")) {
                    HStack(spacing: 4) {
                        Image(systemName: "sun.max.fill")
                            .resizable()
                            .foregroundColor(Color.orange)
                            .frame(width: 18, height: 18)
                            .padding(.all, 2)
                        Text("Today")
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                    .tag(PlanetDetailViewType.today)

                    HStack(spacing: 4) {
                        Image(systemName: "circle.inset.filled")
                            .resizable()
                            .foregroundColor(Color.blue)
                            .frame(width: 18, height: 18)
                            .padding(.all, 2)
                        Text("Unread")
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                    .tag(PlanetDetailViewType.unread)

                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .resizable()
                            .renderingMode(.original)
                            .frame(width: 18, height: 18)
                            .padding(.all, 2)
                        Text("Starred")
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                    .tag(PlanetDetailViewType.starred)
                }

                Section(header: Text("My Planets")) {
                    ForEach(planetStore.myPlanets) { planet in
                        MyPlanetSidebarItem(planet: planet)
                            .tag(PlanetDetailViewType.myPlanet(planet))
                    }
                    .onMove { (indexes, dest) in
                        withAnimation {
                            planetStore.moveMyPlanets(fromOffsets: indexes, toOffset: dest)
                        }
                    }
                }

                Section(header: Text("Following Planets")) {
                    ForEach(planetStore.followingPlanets) { planet in
                        FollowingPlanetSidebarItem(planet: planet)
                            .tag(PlanetDetailViewType.followingPlanet(planet))
                    }
                }
            }
            .listStyle(.sidebar)

            HStack(spacing: 6) {
                Circle()
                    .frame(width: 11, height: 11, alignment: .center)
                    .foregroundColor(ipfsState.online ? Color.green : Color.red)
                Text(ipfsState.online ? "Online (\(ipfsState.peers))" : "Offline")
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
        .sheet(isPresented: $planetStore.isFollowingPlanet) {
            FollowPlanetView()
        }
        .sheet(isPresented: $planetStore.isCreatingPlanet) {
            CreatePlanetView()
        }
        .frame(minWidth: 200)
        .toolbar {
            ToolbarItem {
                Button(action: toggleSidebar) {
                    Image(systemName: "sidebar.left")
                        .help("Toggle Sidebar")
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .publishMyPlanet)) {
            aNotification in
            if let userObject = aNotification.object, let planet = userObject as? MyPlanetModel {
                Task(priority: .background) {
                    do {
                        try await planet.publish()
                    } catch {
                        debugPrint("Failed to publish: \(planet.name) id=\(planet.id)")
                    }
                }
            }
        }
    }

    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?
            .tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
}
