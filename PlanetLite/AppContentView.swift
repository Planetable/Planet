//
//  AppContentView.swift
//  PlanetLite
//

import SwiftUI

// TODO: Put all the modifiers in a separate file
struct CapsuleBar: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(8)
            .background(
                .thinMaterial,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color("BorderColor"), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct AppContentView: View {
    @StateObject private var planetStore: PlanetStore

    static let itemWidth: CGFloat = 128

    let dropDelegate: AppContentDropDelegate

    let timer = Timer.publish(every: 300, on: .current, in: .common).autoconnect()

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
                            /*
                            AppContentGridView(
                                planet: planet,
                                itemSize: NSSize(width: Self.itemWidth, height: Self.itemWidth)
                            )
                            .edgesIgnoringSafeArea(.top)
                            */

                            ScrollView() {
                                LazyVGrid(
                                    columns: [
                                        GridItem(.adaptive(minimum: 128, maximum: 256), spacing: 20)
                                    ],
                                    alignment: .center,
                                    spacing: 20
                                ) {
                                    ForEach(planet.articles, id: \.self) { article in
                                        MyArticleGridView(article: article)
                                    }

                                }
                                .padding([.top], 20)
                                .padding([.leading], 20)
                                .padding([.trailing], 20)
                                .padding([.bottom], 20)
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
        .onReceive(NotificationCenter.default.publisher(for: .copiedIPNS)) { n in
            Task {
                withAnimation(.easeInOut) {
                    self.isShowingCopiedIPNS = true
                }
                await Task.sleep(1_000_000_000)
                withAnimation(.easeInOut) {
                    self.isShowingCopiedIPNS = false
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
        .onDrop(of: [.image], delegate: dropDelegate)  // TODO: Video and Audio support
        .onReceive(timer) { _ in
            Task {
                await planetStore.aggregate()
            }
        }
        .sheet(isPresented: $planetStore.isConfiguringCPN) {
            if case .myPlanet(let planet) = planetStore.selectedView {
                CPNSettings(planet: planet)
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
            if isShowingCopiedIPNS {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "square.on.square")
                        Text("IPNS copied to clipboard")
                    }
                    .modifier(CapsuleBar())

                    Spacer()
                }
                .transition(AnyTransition.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .padding(.leading, 16)
        .padding(.top, 16)
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
