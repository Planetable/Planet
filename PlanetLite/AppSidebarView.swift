//
//  AppSidebarView.swift
//  PlanetLite
//

import SwiftUI


struct AppSidebarView: View {
    @StateObject private var ipfsState: IPFSState
    @StateObject private var planetStore: PlanetStore

    let timer1m = Timer.publish(every: 60, on: .current, in: .common).autoconnect()
    let timer3m = Timer.publish(every: 180, on: .current, in: .common).autoconnect()

    init() {
        _ipfsState = StateObject(wrappedValue: IPFSState.shared)
        _planetStore = StateObject(wrappedValue: PlanetStore.shared)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            List(selection: $planetStore.selectedView) {
                ForEach(planetStore.myPlanets) { planet in
                    AppSidebarItemView(planet: planet)
                        .environmentObject(planetStore)
                        .tag(PlanetDetailViewType.myPlanet(planet))
                }
                .onMove { (indexes, dest) in
                    withAnimation {
                        planetStore.moveMyPlanets(fromOffsets: indexes, toOffset: dest)
                    }
                }
            }
            .listStyle(.sidebar)

            HStack(spacing: 6) {
                if ipfsState.isOperating {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.small)
                    Spacer()
                } else {
                    Circle()
                        .frame(width: 11, height: 11, alignment: .center)
                        .foregroundColor(ipfsState.online ? Color.green : Color.red)
                    Text(ipfsState.online ? "Online" : "Offline")
                        .font(.body)

                    Spacer()

                    Button {
                        planetStore.isCreatingPlanet = true
                    } label: {
                        Image(systemName: "plus")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 14, height: 14, alignment: .center)
                    }
                    .disabled(planetStore.isCreatingPlanet)
                    .buttonStyle(.plain)
                }
            }
            .frame(height: 44)
            .padding(.leading, 16)
            .padding(.trailing, 10)
            .background(Color.secondary.opacity(0.05))
            .contentShape(Rectangle())
            .onTapGesture {
                guard !ipfsState.isOperating else { return }
                Task { @MainActor in
                    self.ipfsState.isShowingStatus.toggle()
                }
            }
            .popover(
                isPresented: $ipfsState.isShowingStatus,
                arrowEdge: .top
            ) {
                IPFSStatusView()
                    .environmentObject(ipfsState)
            }
        }
        .toolbar {
            ToolbarItem {
                Button(action: toggleSidebar) {
                    Image(systemName: "sidebar.left")
                        .help("Toggle Sidebar")
                }
            }
        }
        .alert(isPresented: $planetStore.isShowingAlert) {
            Alert(
                title: Text(PlanetStore.shared.alertTitle),
                message: Text(PlanetStore.shared.alertMessage),
                dismissButton: Alert.Button.cancel(Text("OK")) {
                    PlanetStore.shared.alertTitle = ""
                    PlanetStore.shared.alertMessage = ""
                }
            )
        }
        .sheet(isPresented: $planetStore.isCreatingPlanet) {
            CreatePlanetView()
                .environmentObject(planetStore)
        }
        .sheet(isPresented: $planetStore.isShowingPlanetInfo) {
            if case .myPlanet(let planet) = planetStore.selectedView {
                MyPlanetInfoView(planet: planet)
                    .environmentObject(planetStore)
            }
        }
        .sheet(isPresented: $planetStore.isEditingPlanet) {
            if case .myPlanet(let planet) = planetStore.selectedView {
                MyPlanetEditView(planet: planet)
                    .environmentObject(planetStore)
            }
        }
        .sheet(isPresented: $planetStore.isRebuilding) {
            RebuildProgressView()
        }
        .sheet(isPresented: $planetStore.isQuickSharing) {
            PlanetQuickShareView()
                .frame(width: .sheetWidth)
                .frame(minHeight: .sheetHeight)
        }
        .sheet(isPresented: $planetStore.isShowingMyArticleSettings) {
            if let article: MyArticleModel = planetStore.selectedArticle as? MyArticleModel {
                MyArticleSettingsView(article: article)
            }
        }
        .sheet(isPresented: $planetStore.isEditingPlanetCustomCode) {
            if case .myPlanet(let planet) = planetStore.selectedView {
                MyPlanetCustomCodeView(planet: planet)
            }
        }
        .sheet(isPresented: $planetStore.isShowingPlanetPicker) {
            MyArticleModel.planetPickerView()
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
        .frame(minWidth: PlanetUI.WINDOW_SIDEBAR_WIDTH_MIN, idealWidth: PlanetUI.WINDOW_SIDEBAR_WIDTH_MIN, maxHeight: .infinity)
        .onReceive(timer1m) { _ in
            Task {
                await planetStore.checkPinnable()
            }
        }
        .onReceive(timer3m) { _ in
            Task {
                await planetStore.pin()
            }
        }
    }

    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?
            .tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
}

struct AppSidebarView_Previews: PreviewProvider {
    static var previews: some View {
        AppSidebarView()
    }
}
