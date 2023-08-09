//
//  PlanetQuickShareView.swift
//  Planet
//
//  Created by Kai on 4/12/23.
//

import SwiftUI
import ASMediaView


struct PlanetQuickShareView: View {
    @StateObject private var viewModel: PlanetQuickShareViewModel
    
    @State private var isPosting: Bool = false

    init() {
        _viewModel = StateObject(wrappedValue: PlanetQuickShareViewModel.shared)
    }

    var body: some View {
        VStack {
            headerSection()
                .padding(.top, 16)
                .padding(.horizontal, 16)
                .frame(height: 44)

            attachmentSection()
                .frame(height: 180)

            articleContentSection()
                .padding(.horizontal, 14)

            footerSection()
                .padding(.top, 8)
                .padding(.bottom, 16)
                .padding(.horizontal, 16)
                .frame(height: 42)
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
                Button {
                    addAttachmentsAction()
                } label: {
                    Text("Add Attachments...")
                }
                Text("Or drag and drop images here.")
                    .foregroundColor(.secondary)
            }
        } else if viewModel.fileURLs.count == 1, let url = viewModel.fileURLs.first, let img = NSImage(contentsOf: url) {
            HStack {
                ZStack {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                    if PlanetStore.shared.app == .lite && ASMediaManager.shared.imageIsGIF(image: img) {
                        GIFIndicatorView()
                            .frame(width: 180, height: 180 / (img.size.width / img.size.height))
                    }
                }
                .frame(width: 180, height: 180)
            }
        } else {
            ScrollView(.horizontal) {
                LazyHStack(alignment: .center) {
                    ForEach(viewModel.fileURLs, id: \.self) { url in
                        if let img = NSImage(contentsOf: url) {
                            ZStack {
                                Image(nsImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                if PlanetStore.shared.app == .lite && ASMediaManager.shared.imageIsGIF(image: img) {
                                    GIFIndicatorView()
                                        .frame(width: 180, height: 180 / (img.size.width / img.size.height))
                                }
                            }
                            .frame(width: 180, height: 180)
                        }
                    }
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
            .padding(.bottom, 6)

            TextEditor(text: $viewModel.content)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .disableAutocorrection(true)
                .cornerRadius(6)
                .padding(1)
                .shadow(color: .secondary.opacity(0.75), radius: 0.5, x: 0, y: 0.5)
        }
    }

    @ViewBuilder
    private func footerSection() -> some View {
        HStack {
            Button {
                dismissAction()
            } label: {
                Text("Cancel")
            }
            .keyboardShortcut(.escape, modifiers: [])

            Spacer()
            
            HStack {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.5, anchor: .center)
            }
            .padding(.trailing, 2)
            .frame(height: 10)
            .opacity(viewModel.sending ? 1.0 : 0.0)

            Button {
                isPosting = true
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
            .disabled(isPosting || viewModel.getTargetPlanet() == nil)
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
        Task { @MainActor in
            PlanetStore.shared.isQuickSharing = false
            PlanetQuickShareViewModel.shared.cleanup()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                self.isPosting = false
            }
        }
    }

}

struct PlanetQuickShareView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetQuickShareView()
    }
}
