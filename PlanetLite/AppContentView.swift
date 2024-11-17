//
//  AppContentView.swift
//  PlanetLite
//

import SwiftUI

struct AppContentView: View {
    @StateObject private var planetStore: PlanetStore

    static let itemWidth: CGFloat = 128

    let dropDelegate: AppContentDropDelegate

    let timer = Timer.publish(every: 300, on: .current, in: .common).autoconnect()

    @State private var isSharing: Bool = false
    @State private var sharingItem: URL?
    @State private var isShowingTaskProgressIndicator: Bool = false
    @State private var isShowingCopiedIPNS: Bool = false

    init() {
        _planetStore = StateObject(wrappedValue: PlanetStore.shared)
        dropDelegate = AppContentDropDelegate()
    }

    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                if planetStore.myPlanets.count == 0 {
                    // Default empty view of the Lite app
                    Button {
                        planetStore.isCreatingPlanet = true
                    } label: {
                        Text("Create First Site")
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle)
                    .controlSize(.large)
                    .disabled(planetStore.isCreatingPlanet)
                    Text("Learn more about [Croptop](https://croptop.eth.limo)")
                        .foregroundColor(.secondary)
                }
                else {
                    switch planetStore.selectedView {
                    case .myPlanet(let planet):
                        if planet.articles.count == 0 {
                            // TODO: Add an illustration here
                            Text("Drag and drop a picture here to start.")
                                .foregroundColor(.secondary)
                        }
                        else {
                            ScrollView(.vertical) {
                                LazyVGrid(
                                    columns: [
                                        GridItem(
                                            .adaptive(minimum: 128, maximum: 256),
                                            spacing: 16
                                        )
                                    ],
                                    alignment: .center,
                                    spacing: 16
                                ) {
                                    ForEach(planet.articles, id: \.self) { article in
                                        MyArticleGridView(article: article)
                                    }

                                }
                                .padding(16)
                            }
                        }
                    default:
                        Text("No Content")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(0)
            .frame(
                minWidth: PlanetUI.WINDOW_CONTENT_WIDTH_MIN,
                idealWidth: PlanetUI.WINDOW_CONTENT_WIDTH_MIN,
                maxWidth: .infinity,
                minHeight: PlanetUI.WINDOW_CONTENT_HEIGHT_MIN,
                idealHeight: PlanetUI.WINDOW_CONTENT_HEIGHT_MIN,
                maxHeight: .infinity,
                alignment: .center
            )
            .background(Color(NSColor.textBackgroundColor))

            copiedIPNS()
            taskProgress()
        }
        .navigationTitle(
            Text(planetStore.navigationTitle)
        )
        .navigationSubtitle(
            Text(planetStore.navigationSubtitle)
        )
        .task {
            if case .myPlanet(let planet) = planetStore.selectedView {
                let liteSubtitle = "ipns://\(planet.ipns.shortIPNS())"
                Task { @MainActor in
                    self.planetStore.navigationSubtitle = liteSubtitle
                }
            }
        }
        .onChange(of: planetStore.isAggregating) { newValue in
            debugPrint("PlanetStore: new value of isAggregating: \(newValue)")
            Task { @MainActor in
                withAnimation(.easeInOut) {
                    self.isShowingTaskProgressIndicator = newValue
                }
            }
        }
        .onDrop(of: [.image, .pdf, .movie, .mp3], delegate: dropDelegate)  // TODO: Audio support
        .onReceive(timer) { _ in
            Task {
                await planetStore.aggregate()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                // action
                Menu {
                    Button {
                        if case .myPlanet(let planet) = planetStore.selectedView {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(planet.ipns, forType: .string)
                            Task {
                                withAnimation(.easeInOut) {
                                    self.isShowingCopiedIPNS = true
                                }
                                try? await Task.sleep(nanoseconds: 1_000_000_000)
                                withAnimation(.easeInOut) {
                                    self.isShowingCopiedIPNS = false
                                }
                            }
                        }
                    } label: {
                        Text("Copy IPNS")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .help("Action")

                // show info
                Button {
                    guard planetStore.isShowingPlanetInfo == false else { return }
                    planetStore.isShowingPlanetInfo = true
                } label: {
                    Image(systemName: "info.circle")
                }
                .help("Show Info")

                // share
                Button {
                    if case .myPlanet(let planet) = planetStore.selectedView {
                        sharingItem = URL(string: "planet://\(planet.ipns)")
                        isSharing.toggle()
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .background(
                    SharingServicePicker(
                        isPresented: $isSharing,
                        sharingItems: [
                            sharingItem ?? URL(string: "https://planetable.eth.limo")!
                        ]
                    )
                )
                .help("Share Site")

                // add
                Button {
                    switch planetStore.selectedView {
                    case .myPlanet(let planet):
                        Task { @MainActor in
                            PlanetQuickShareViewModel.shared.myPlanets = PlanetStore.shared.myPlanets
                            PlanetQuickShareViewModel.shared.selectedPlanetID = planet.id
                            self.planetStore.isQuickSharing = true
                        }
                    default:
                        break
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .help("New Post")
            }
        }
        .sheet(isPresented: $planetStore.isConfiguringMint) {
            if case .myPlanet(let planet) = planetStore.selectedView {
                MintSettings(planet: planet)
            }
        }
        .sheet(isPresented: $planetStore.isConfiguringAggregation) {
            if case .myPlanet(let planet) = planetStore.selectedView {
                AggregationSettings(planet: planet)
            }
        }
        .sheet(isPresented: $planetStore.isShowingPlanetIPNS) {
            if case .myPlanet(let planet) = planetStore.selectedView {
                MyPlanetIPNSView(planet: planet)
            }
        }
    }

    /// Show for 1 second when the IPNS is copied to clipboard
    @ViewBuilder
    private func copiedIPNS() -> some View {
        VStack {
            Spacer()
            if isShowingCopiedIPNS {
                HStack {
                    Spacer()

                    HStack(spacing: 8) {
                        Image(systemName: "square.on.square")
                        Text("IPNS copied to clipboard")
                    }
                    .modifier(CapsuleBar())

                    Spacer()
                }
                .transition(AnyTransition.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.bottom, 10)
    }

    /// Show the task progress, when aggregating
    @ViewBuilder
    private func taskProgress() -> some View {
        VStack {
            Spacer()
            if isShowingTaskProgressIndicator {
                HStack(spacing: 8) {
                    switch planetStore.currentTaskProgressIndicator {
                    case .none:
                        Spacer()
                            .frame(width: 16, height: 16)
                    case .progress:
                        ProgressView()
                            .progressViewStyle(.circular)
                            .controlSize(.small)
                    case .done:
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 16))
                    }
                    Text(PlanetStore.shared.currentTaskMessage)
                        .font(.footnote)
                }
                .modifier(CapsuleBar())
                .transition(AnyTransition.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.bottom, 10)
    }
}

struct AppContentView_Previews: PreviewProvider {
    static var previews: some View {
        AppContentView()
    }
}
