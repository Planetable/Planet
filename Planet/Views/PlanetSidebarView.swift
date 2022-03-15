//
//  PlanetSidebarView.swift
//  Planet
//
//  Created by Kai on 2/20/22.
//

import SwiftUI


struct PlanetSidebarLoadingIndicatorView: View {
    @EnvironmentObject private var planetStore: PlanetStore

    @State private var timerState: Int = 0
    @State private var hourglass: String = "hourglass.bottomhalf.filled"

    var body: some View {
        VStack {
            Image(systemName: hourglass)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 12, height: 12, alignment: .center)
        }
        .padding(0)
        .onReceive(planetStore.indicatorTimer) { t in
            if timerState > 2 {
                timerState = 0
            }
            switch timerState {
            case 1:
                hourglass = "hourglass"
            case 2:
                hourglass = "hourglass.tophalf.filled"
            default:
                hourglass = "hourglass.bottomhalf.filled"
            }
            timerState += 1
        }
    }
}


struct PlanetSidebarToolbarButtonView: View {
    @EnvironmentObject private var planetStore: PlanetStore
    @Environment(\.managedObjectContext) private var context

    var body: some View {
        Button {
            planetStore.isShowingPlanetInfo = true
        } label: {
            Image(systemName: "info.circle")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16, alignment: .center)
        }
        .disabled(planetStore.currentPlanet == nil)

        Button {
            if let planet = planetStore.currentPlanet, planet.isMyPlanet() {
                launchWriterIfNeeded(forPlanet: planet)
            }
        } label: {
            Image(systemName: "square.and.pencil")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16, alignment: .center)
        }
        .disabled(planetStore.currentPlanet == nil || !planetStore.currentPlanet.isMyPlanet())
    }

    private func launchWriterIfNeeded(forPlanet planet: Planet) {
        let articleID = planet.id!

        if planetStore.writerIDs.contains(articleID) {
            DispatchQueue.main.async {
                self.planetStore.activeWriterID = articleID
            }
            return
        }

        let writerView = PlanetWriterView(articleID: articleID)
        let writerWindow = PlanetWriterWindow(rect: NSMakeRect(0, 0, 720, 480), maskStyle: [.closable, .miniaturizable, .resizable, .titled, .fullSizeContentView], backingType: .buffered, deferMode: false, articleID: articleID)
        writerWindow.center()
        writerWindow.contentView = NSHostingView(rootView: writerView)
        writerWindow.makeKeyAndOrderFront(nil)
    }
}


struct PlanetSidebarView: View {
    @EnvironmentObject private var planetStore: PlanetStore

    @FetchRequest(sortDescriptors: [SortDescriptor(\.created, order: .reverse)], animation: Animation.easeInOut) var planets: FetchedResults<Planet>
    @FetchRequest(sortDescriptors: [SortDescriptor(\.created, order: .reverse)], animation: Animation.easeInOut) var articles: FetchedResults<PlanetArticle>
    @Environment(\.managedObjectContext) private var context

    var body: some View {
        VStack {
            List {
                Section(header:
                    HStack {
                        Text("My Planets")
                        Spacer()
                    }
                ) {
                    ForEach(planets.filter({ p in
                        return (p.keyName != nil && p.keyID != nil)
                    }), id: \.id) { planet in
                        NavigationLink(destination: PlanetArticleListView(planetID: planet.id!, articles: articles)
                                        .environmentObject(planetStore)
                                        .environment(\.managedObjectContext, context)
                                        .frame(minWidth: 200)
                                        .toolbar {
                                            ToolbarItemGroup {
                                                Spacer()
                                                PlanetSidebarToolbarButtonView()
                                                    .environmentObject(planetStore)
                                                    .environment(\.managedObjectContext, context)
                                            }
                                        }, tag: planet.id!.uuidString, selection: $planetStore.selectedPlanet) {
                            VStack {
                                HStack (spacing: 4) {
                                    PlanetAvatarView(planet: planet, size: CGSize(width: 24, height: 24))
                                    Text(planet.name ?? "")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    PlanetSidebarLoadingIndicatorView()
                                        .environmentObject(planetStore)
                                        .opacity(planetStore.publishingPlanets.contains(planet.id!) ? 1.0 : 0.0)
                                }
                            }
                        }
                        .contextMenu(menuItems: {
                            VStack {
                                Button {
                                    if let planet = planetStore.currentPlanet, planet.isMyPlanet() {
                                        launchWriterIfNeeded(forPlanet: planet)
                                    }
                                } label: {
                                    Text("New Article")
                                }

                                if !planetStore.publishingPlanets.contains(planet.id!) {
                                    Button {
                                        Task.init {
                                            await PlanetManager.shared.publishForPlanet(planet: planet)
                                        }
                                    } label: {
                                        Text("Publish Planet")
                                    }
                                } else {
                                    Button {
                                    } label: {
                                        Text("Publishing...")
                                    }
                                    .disabled(true)
                                }

                                Button {
                                    copyPlanetIPNSAction(planet: planet)
                                } label: {
                                    Text("Copy IPNS")
                                }

                                Divider()

                                Button {
                                    if let keyName = planet.keyName, keyName != "" {
                                        Task.init(priority: .background) {
                                            await PlanetManager.shared.deleteKey(withName: keyName)
                                        }
                                    }
                                    PlanetDataController.shared.removePlanet(planet: planet)
                                } label: {
                                    Text("Delete Planet")
                                }
                            }
                        })
                    }
                }

                Section(header:
                    HStack {
                        Text("Following Planets")
                        Spacer()
                    }
                ) {
                    ForEach(planets.filter({ p in
                        return (p.keyName == nil && p.keyID == nil)
                    }), id: \.id) { planet in
                        NavigationLink(destination: PlanetArticleListView(planetID: planet.id!, articles: articles)
                                        .environmentObject(planetStore)
                                        .environment(\.managedObjectContext, context)
                                        .frame(minWidth: 200)
                                        .toolbar {
                                            ToolbarItemGroup {
                                                Spacer()
                                                PlanetSidebarToolbarButtonView()
                                                    .environmentObject(planetStore)
                                                    .environment(\.managedObjectContext, context)
                                            }
                                        }, tag: planet.id!.uuidString, selection: $planetStore.selectedPlanet) {
                            VStack {
                                HStack (spacing: 4) {
                                    if planet.name == nil || planet.name == "" {
                                        Text(planetStore.updatingPlanets.contains(planet.id!) ? "Waiting for planet..." : "Unknown Planet")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    } else {
                                        PlanetAvatarView(planet: planet, size: CGSize(width: 24, height: 24))
                                        Text(planet.name ?? "")
                                            .font(.body)
                                            .foregroundColor(.primary)
                                    }
                                    Spacer()
                                    if planetStore.updatingPlanets.contains(planet.id!) {
                                        PlanetSidebarLoadingIndicatorView()
                                            .environmentObject(planetStore)
                                    }
                                }
                            }
                        }
                        .contextMenu(menuItems: {
                            VStack {
                                if !planetStore.updatingPlanets.contains(planet.id!) {
                                    Button {
                                        Task.init {
                                            await PlanetManager.shared.updateForPlanet(planet: planet)
                                        }
                                    } label: {
                                        Text("Check for update")
                                    }
                                } else {
                                    Button {
                                    } label: {
                                        Text("Updating...")
                                    }
                                    .disabled(true)
                                }

                                if articles.count > 0 {
                                    Button {
                                        let _ = articles.map() { a in
                                            PlanetManager.shared.updateArticleReadingStatus(article: a, read: true)
                                        }
                                    } label: {
                                        Text("Mark All as Read")
                                    }
                                }

                                Button {
                                    copyPlanetIPNSAction(planet: planet)
                                } label: {
                                    Text("Copy IPNS")
                                }

                                Divider()

                                Button {
                                    unfollowPlanetAction(planet: planet)
                                } label: {
                                    Text("Unfollow")
                                }
                            }
                        })
                    }
                }
            }
            .listStyle(.sidebar)

            HStack (spacing: 6) {
                Circle()
                    .frame(width: 11, height: 11, alignment: .center)
                    .foregroundColor((planetStore.daemonIsOnline && planetStore.peersCount > 0) ? Color.green : Color.red)
                Text(planetStore.peersCount == 0 ? "Offline" : "Online (\(planetStore.peersCount))")
                    .font(.body)

                Spacer()

                Menu {
                    Button(action: {
                        planetStore.isCreatingPlanet = true
                    }) {
                        Label("Create Planet", systemImage: "plus")
                    }
                    .disabled(planetStore.isCreatingPlanet)

                    Divider()

                    Button(action: {
                        planetStore.isFollowingPlanet = true
                    }) {
                        Label("Follow Planet", systemImage: "plus")
                    }
                } label: {
                    Image(systemName: "plus.app")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24, alignment: .center)
                }
                .padding(EdgeInsets(top: 2, leading: 10, bottom: 2, trailing: 0))
                .frame(width: 24, height: 24, alignment: .center)
                .menuStyle(BorderlessButtonMenuStyle(showsMenuIndicator: false))
            }
            .onTapGesture {
                guard planetStore.daemonIsOnline == false else { return }
                PlanetManager.shared.relaunchDaemon()
            }
            .frame(height: 44)
            .padding(.leading, 16)
            .padding(.trailing, 10)
            .background(Color.secondary.opacity(0.05))
        }
        .padding(.bottom, 0)
        .sheet(isPresented: $planetStore.isFollowingPlanet) {
        } content: {
            FollowPlanetView()
                .environmentObject(planetStore)
        }
        .sheet(isPresented: $planetStore.isCreatingPlanet) {
        } content: {
            CreatePlanetView()
                .environmentObject(planetStore)
        }
    }

    private func unfollowPlanetAction(planet: Planet) {
        PlanetDataController.shared.removePlanet(planet: planet)
    }

    private func copyPlanetIPNSAction(planet: Planet) {
        guard let ipns = planet.ipns else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(ipns, forType: .string)
    }

    private func launchWriterIfNeeded(forPlanet planet: Planet) {
        let articleID = planet.id!

        if planetStore.writerIDs.contains(articleID) {
            DispatchQueue.main.async {
                self.planetStore.activeWriterID = articleID
            }
            return
        }

        let writerView = PlanetWriterView(articleID: articleID)
        let writerWindow = PlanetWriterWindow(rect: NSMakeRect(0, 0, 720, 480), maskStyle: [.closable, .miniaturizable, .resizable, .titled, .fullSizeContentView], backingType: .buffered, deferMode: false, articleID: articleID)
        writerWindow.center()
        writerWindow.contentView = NSHostingView(rootView: writerView)
        writerWindow.makeKeyAndOrderFront(nil)
    }
}


struct PlanetSidebarView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetSidebarView()
    }
}
