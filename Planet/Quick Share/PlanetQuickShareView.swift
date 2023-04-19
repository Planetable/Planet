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
                .padding(.bottom, 16 - 28)
                .padding(.horizontal, 16)
        }
        .frame(width: .sheetWidth, height: .sheetHeight)
        .edgesIgnoringSafeArea(.vertical)
    }

    @ViewBuilder
    private func headerSection() -> some View {
        HStack {
            Text("Quick Share")
                .font(.title)
            Spacer()
            Picker("To", selection: $viewModel.selectedPlanetID) {
                ForEach(viewModel.myPlanets, id: \.id) { planet in
                    Text(planet.name)
                        .tag(planet.id)
                }
            }
            .onChange(of: viewModel.selectedPlanetID, perform: { newValue in
                viewModel.selectedPlanetID = newValue
            })
            .frame(width: 200)
        }
    }

    @ViewBuilder
    private func attachmentSection() -> some View {
        if viewModel.fileURLs.count == 0 {
            Text("No Attachments.")
                .foregroundColor(.secondary)
        } else {
            GeometryReader { g in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack (alignment: .center) {
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
                .font(.system(size: 13, weight: .regular, design: .default))
                .lineSpacing(8)
                .disableAutocorrection(true)
                .cornerRadius(6)
                .frame(height: 82)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: NSColor.windowBackgroundColor).opacity(0.25), lineWidth: 1.0)
                )
                .padding(.horizontal, 1)
            HStack {
                TextField("Optional Link", text: $viewModel.externalLink)
                    .textFieldStyle(.roundedBorder)
                Spacer(minLength: 1)
            }.padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private func footerSection() -> some View {
        HStack {
            Button {
                NotificationCenter.default.post(name: .cancelQuickShare, object: nil)
            } label: {
                Text("Close")
            }
            .keyboardShortcut(.escape, modifiers: [])
            Spacer()
            Button {
                do {
                    try viewModel.send()
                } catch {
                    let alert = NSAlert()
                    alert.messageText = "Failed to Create Post"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                    return
                }
                NotificationCenter.default.post(name: .cancelQuickShare, object: nil)
            } label: {
                Text("Send")
            }
            .keyboardShortcut(.return, modifiers: [])
            .keyboardShortcut(.end, modifiers: [])
            .disabled(viewModel.getTargetPlanet() == nil || viewModel.title == "")
        }
    }
}


struct PlanetQuickShareView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetQuickShareView()
    }
}
