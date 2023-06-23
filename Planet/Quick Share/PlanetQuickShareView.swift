//
//  PlanetQuickShareView.swift
//  Planet
//
//  Created by Kai on 4/12/23.
//

import SwiftUI

struct PlanetQuickShareView: View {
    @StateObject private var viewModel: PlanetQuickShareViewModel

    init() {
        _viewModel = StateObject(wrappedValue: PlanetQuickShareViewModel.shared)
    }

    var body: some View {
        VStack {
            headerSection()
                .padding(.top, 16)
                .padding(.horizontal, 16)

            attachmentSection()
                .frame(height: 180)

            articleContentSection()
                .padding(.horizontal, 14)

            Spacer(minLength: 1)

            footerSection()
                .padding(.bottom, PlanetStore.shared.isQuickSharing ? 16 : -12)
                .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func headerSection() -> some View {
        HStack {
            Text("New Post")
                .font(.title)
            Spacer()
            Picker("To", selection: $viewModel.selectedPlanetID) {
                ForEach(viewModel.myPlanets, id: \.id) { planet in
                    Text(planet.name)
                        .tag(planet.id)
                }
            }
            .onChange(
                of: viewModel.selectedPlanetID,
                perform: { newValue in
                    viewModel.selectedPlanetID = newValue
                }
            )
            .frame(width: 200)
        }
    }

    @ViewBuilder
    private func attachmentSection() -> some View {
        if viewModel.fileURLs.count == 0 {
            VStack {
                Text("No Attachments.")
                    .foregroundColor(.secondary)
                Button {
                    addAttachmentsAction()
                } label: {
                    Text("Add Attachments...")
                }
            }
        } else {
            GeometryReader { g in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .center) {
                        ForEach(viewModel.fileURLs, id: \.self) { url in
                            if let img = NSImage(contentsOf: url) {
                                Image(nsImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 180, height: 180)
                            }
                        }
                    }
                    .frame(width: g.size.width)
                }
            }
        }
    }

    @ViewBuilder
    private func articleContentSection() -> some View {
        VStack {
            HStack {
                TextField("Title", text: $viewModel.title)
                    .textFieldStyle(.roundedBorder)
                Spacer(minLength: 1)
            }
            .padding(.top, 2)
            TextEditor(text: $viewModel.content)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .disableAutocorrection(true)
                .frame(height: 82)
                .cornerRadius(6)
                .padding(1)
                .shadow(color: .secondary.opacity(0.75), radius: 0.5, x: 0, y: 0.5)
            /*
            HStack {
                TextField("Optional Link", text: $viewModel.externalLink)
                    .textFieldStyle(.roundedBorder)
                Spacer(minLength: 1)
            }.padding(.bottom, 8)
            */
        }
    }

    @ViewBuilder
    private func footerSection() -> some View {
        HStack {
            Button {
                dismissAction()
            } label: {
                Text("Close")
            }
            .keyboardShortcut(.escape, modifiers: [])
            Spacer()
            Button {
                do {
                    try viewModel.send()
                }
                catch {
                    let alert = NSAlert()
                    alert.messageText = "Failed to Create Post"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                    return
                }
                dismissAction()
            } label: {
                Text("Post")
            }
            .keyboardShortcut(.return, modifiers: [])
            .keyboardShortcut(.end, modifiers: [])
            .disabled(viewModel.getTargetPlanet() == nil)
        }
    }

    private func addAttachmentsAction() {
        let panel = NSOpenPanel()
        panel.message = "Choose attachments to publish"
        panel.prompt = "Choose"
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.image]
        panel.canChooseDirectories = false
        panel.showsHiddenFiles = false
        let response = panel.runModal()
        guard response == .OK, panel.urls.count > 0 else { return }
        Task { @MainActor in
            PlanetQuickShareViewModel.shared.fileURLs = panel.urls
        }
    }

    private func dismissAction() {
        NotificationCenter.default.post(name: .cancelQuickShare, object: nil)
        Task { @MainActor in
            PlanetStore.shared.isQuickSharing = false
            PlanetQuickShareViewModel.shared.cleanup()
        }
    }

}

struct PlanetQuickShareView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetQuickShareView()
    }
}
