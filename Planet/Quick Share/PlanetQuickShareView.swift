//
//  PlanetQuickShareView.swift
//  Planet
//
//  Created by Kai on 4/12/23.
//

import AVKit
import ASMediaView
import SwiftUI
import UniformTypeIdentifiers
import WrappingHStack

struct PlanetQuickShareView: View {
    @StateObject private var viewModel: PlanetQuickShareViewModel

    @State private var isPosting: Bool = false
    @State private var updatingTags: Bool = false

    @State private var player: AVPlayer?

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

    // TODO: move this func to MyPlanetModel
    // TODO: Consolidate duplicated code in MyArticleItemView
    private func articleItemAvatarImage(fromPlanet planet: MyPlanetModel) -> NSImage? {
        let size = CGSize(width: 16, height: 16)
        let img = NSImage(size: size)
        img.lockFocus()
        defer {
            img.unlockFocus()
        }
        if let image = planet.avatar {
            if let ctx = NSGraphicsContext.current {
                ctx.imageInterpolation = .high
                let targetRect = NSRect(origin: .zero, size: size)
                let radius: CGFloat = size.width / 2.0
                let path: NSBezierPath = NSBezierPath(
                    roundedRect: targetRect,
                    xRadius: radius,
                    yRadius: radius
                )
                path.addClip()
                image.draw(
                    in: targetRect,
                    from: NSRect(origin: .zero, size: image.size),
                    operation: .copy,
                    fraction: 1.0
                )
            }
            return img
        }
        else if let font = NSFont(name: "Arial Rounded MT Bold", size: size.width / 2.0) {
            let t = NSAttributedString(
                string: planet.nameInitials,
                attributes: [
                    NSAttributedString.Key.font: font,
                    NSAttributedString.Key.foregroundColor: NSColor.white,
                ]
            )
            let drawPoint = NSPoint(
                x: (size.width - t.size().width) / 2.0,
                y: (size.height - t.size().height) / 2.0
            )
            let leastSignificantUInt8 = planet.id.uuid.15
            let index = Int(leastSignificantUInt8) % ViewUtils.presetGradients.count
            let gradient = ViewUtils.presetGradients[index]
            if let ctx = NSGraphicsContext.current {
                ctx.imageInterpolation = .high
                let targetRect = NSRect(origin: .zero, size: size)
                let radius: CGFloat = size.width / 2.0
                let path: NSBezierPath = NSBezierPath(
                    roundedRect: targetRect,
                    xRadius: radius,
                    yRadius: radius
                )
                path.addClip()
                let gradient = NSGradient(
                    starting: NSColor(gradient.stops.first?.color ?? .white),
                    ending: NSColor(gradient.stops.last?.color ?? .gray)
                )
                gradient?.draw(in: targetRect, angle: -90)
                t.draw(at: drawPoint)
            }
            return img
        }
        return nil
    }

    @ViewBuilder
    private func headerSection() -> some View {
        HStack {
            Text("New Post")
                .font(.title)
            Spacer()
            Picker("To", selection: $viewModel.selectedPlanetID) {
                ForEach(viewModel.myPlanets, id: \.id) { planet in
                    HStack(spacing: 4) {
                        if let image = articleItemAvatarImage(fromPlanet: planet) {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        }
                        Text(planet.name)
                        Spacer(minLength: 4)
                    }
                    .tag(planet.id)
                }
            }
            .onChange(
                of: viewModel.selectedPlanetID,
                perform: { newValue in
                    viewModel.selectedPlanetID = newValue
                }
            )
            .pickerStyle(.menu)
            .frame(width: 200)
        }
    }

    @ViewBuilder
    private func attachmentSectionPlaceholder() -> some View {
        VStack {
            Button {
                addAttachmentsAction()
            } label: {
                Text("Add Attachments...")
            }
            Text("Or drag and drop images here.")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func attachmentSection() -> some View {
        if viewModel.fileURLs.count == 0 {
            if PlanetStore.shared.app == .lite {
                ZStack {
                    let dropDelegate = PlanetQuickShareDropDelegate()
                    attachmentSectionPlaceholder()
                        .focusable()
                        .onDrop(of: [.image, .movie], delegate: dropDelegate)
                        .onPasteCommand(of: [.fileURL, .image, .movie], perform: PlanetQuickShareViewModel.shared.processPasteItems(_:))
                        .contextMenu {
                            PasteButton(supportedContentTypes: [.fileURL, .image, .movie], payloadAction: PlanetQuickShareViewModel.shared.processPasteItems(_:))
                        }
                }
            }
            else {
                attachmentSectionPlaceholder()
            }
        }
        else if viewModel.fileURLs.count == 1, let url = viewModel.fileURLs.first, AttachmentType.from(url) == .video {
            videoView(url: url)
        }
        else if viewModel.fileURLs.count == 1, let url = viewModel.fileURLs.first,
            let img = NSImage(contentsOf: url)
        {
            HStack {
                ZStack {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                    if PlanetStore.shared.app == .lite
                        && ASMediaManager.shared.imageIsGIF(image: img)
                    {
                        GIFIndicatorView()
                            .frame(width: 180, height: 180 / (img.size.width / img.size.height))
                    }
                }
                .frame(width: 180, height: 180)
            }
        }
        else {
            ScrollView(.horizontal) {
                LazyHStack(alignment: .center) {
                    ForEach(viewModel.fileURLs, id: \.self) { url in
                        if let img = NSImage(contentsOf: url) {
                            ZStack {
                                Image(nsImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                if PlanetStore.shared.app == .lite
                                    && ASMediaManager.shared.imageIsGIF(image: img)
                                {
                                    GIFIndicatorView()
                                        .frame(
                                            width: 180,
                                            height: 180 / (img.size.width / img.size.height)
                                        )
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
            HStack(spacing: 10) {
                TextField("Title", text: $viewModel.title)
                    .textFieldStyle(.roundedBorder)

                Button {
                    updatingTags.toggle()
                } label: {
                    Image(systemName: "tag")
                    if viewModel.tags.count > 0 {
                        Text("\(viewModel.tags.count)")
                            .font(.system(size: 12, weight: .regular, design: .default))
                            .foregroundColor(.secondary)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(4)
                    }
                }
                .buttonStyle(.plain)
                .help(viewModel.tags.values.joined(separator: ", "))
                .popover(isPresented: $updatingTags) {
                    tagsView()
                }
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
    private func videoView(url: URL) -> some View {
        HStack(spacing: 0) {
            VideoPlayer(player: player)
                .frame(minHeight: 180)
                .onAppear {
                    self.player = AVPlayer(url: url)
                    player?.play()
                }
        }
        .contextMenu {
            Button {
                player?.pause()
                viewModel.fileURLs.removeAll(where: { $0 == url })
            } label: {
                Text("Remove Video")
            }
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
        panel.allowedContentTypes = [.image, .movie]
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

    private func addTag() {
        let aTag = viewModel.newTag.trim()
        let normalizedTag = aTag.normalizedTag()
        if normalizedTag.count > 0 {
            if viewModel.tags.keys.contains(aTag) {
                // tag already exists
                return
            }
            viewModel.tags[normalizedTag] = aTag
            viewModel.newTag = ""
        }
    }

    @ViewBuilder
    private func tagsView() -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                HStack {
                    Text("Tags")
                }

                // Tag capsules
                WrappingHStack(
                    viewModel.tags.values.sorted(),
                    id: \.self,
                    alignment: .leading,
                    spacing: .constant(2),
                    lineSpacing: 4
                ) { tag in
                    TagView(tag: tag)
                        .onTapGesture {
                            viewModel.tags.removeValue(forKey: tag.normalizedTag())
                        }
                }
            }
            .padding(10)
            .background(Color(NSColor.textBackgroundColor))

            Divider()

            HStack(spacing: 10) {
                HStack {
                    Text("Add a Tag")
                    Spacer()
                }

                TextField("", text: $viewModel.newTag)
                    .onSubmit {
                        addTag()
                    }
                    .disableAutocorrection(true)
                    .textFieldStyle(.roundedBorder)

                Button {
                    addTag()
                } label: {
                    Text("Add")
                }
            }
            .padding(10)
        }
        .frame(width: 280)
    }
}

struct PlanetQuickShareView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetQuickShareView()
    }
}
