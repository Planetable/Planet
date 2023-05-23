import SwiftUI

struct MyArticleItemView: View {
    @ObservedObject var article: MyArticleModel

    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        HStack {
            VStack {
                article.starView()
                    .visibility(article.starred != nil ? .visible : .invisible)
                Spacer()
            }
            VStack(alignment: .leading, spacing: 4) {
                VStack(alignment: .leading) {
                    Text(article.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    if let summary = article.summary, summary.count > 0 {
                        Text(summary.prefix(280))
                            .foregroundColor(.secondary)
                        if summary.count < 40 {
                            Spacer()
                        }
                    }
                    else if article.content.count > 0 {
                        Text(article.content.prefix(280))
                            .foregroundColor(.secondary)
                        if article.content.count < 40 {
                            Spacer()
                        }
                    }
                    else {
                        Spacer()
                    }
                }
                .frame(height: 48)
                HStack(spacing: 6) {
                    Text(article.created.mmddyyyy())
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if article.hasAudio {
                        Text(Image(systemName: "headphones"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if article.hasVideo {
                        Text(Image(systemName: "video"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if article.articleType == .page {
                        Text("Page")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                            .padding(.trailing, 4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color("BorderColor"), lineWidth: 1)
                            )
                    }
                    if let included = article.isIncludedInNavigation, included {
                        Text("Navigation \(article.navigationWeight ?? 1)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                            .padding(.trailing, 4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color("BorderColor"), lineWidth: 1)
                            )
                    }
                    Spacer()
                }
            }
        }
        .contentShape(Rectangle())
        .contextMenu {
            VStack {
                Button {
                    do {
                        try WriterStore.shared.editArticle(for: article)
                    }
                    catch {
                        PlanetStore.shared.alert(title: "Failed to launch writer")
                    }
                } label: {
                    Text("Edit Article")
                }
                Button {
                    PlanetStore.shared.selectedArticle = article
                    PlanetStore.shared.isShowingMyArticleSettings = true
                } label: {
                    Text("Settings")
                }

                Divider()
                moveArticleItem()
                Divider()

                Button {
                    isShowingDeleteConfirmation = true
                } label: {
                    Text("Delete Article")
                }
                Menu("Star") {
                    ArticleSetStarView(article: article)
                }
                if article.starred != nil {
                    Button {
                        article.starred = nil
                        try? article.save()
                    } label: {
                        Text("Remove Star")
                    }
                }
                Button {
                    if let url = article.browserURL {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(url.absoluteString, forType: .string)
                    }
                } label: {
                    Text("Copy Public Link")
                }
                Button {
                    if let url = article.browserURL {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Text("Open in Browser")
                }
            }
        }
        .confirmationDialog(
            Text("Are you sure you want to delete this article?"),
            isPresented: $isShowingDeleteConfirmation
        ) {
            Button(role: .destructive) {
                do {
                    if let planet = article.planet {
                        try article.delete()
                        planet.updated = Date()
                        Task {
                            try planet.save()
                            try planet.savePublic()
                        }
                        if PlanetStore.shared.selectedArticle == article {
                            PlanetStore.shared.selectedArticle = nil
                        }
                        if let selectedArticles = PlanetStore.shared.selectedArticleList,
                            selectedArticles.contains(article)
                        {
                            PlanetStore.shared.refreshSelectedArticles()
                        }
                    }
                }
                catch {
                    PlanetStore.shared.alert(title: "Failed to delete article: \(error)")
                }
            } label: {
                Text("Delete")
            }
        }
    }

    @ViewBuilder
    private func moveArticleItem() -> some View {
        let activePlanets: [MyPlanetModel] = PlanetStore.shared.myPlanets.filter { p in
            return (p.archived == nil || p.archived! == false) && article.planet != p
        }
        Menu("Move Article to") {
            ForEach(activePlanets, id: \.id) { targetPlanet in
                Button {
                    Task { @MainActor in
                        do {
                            try await PlanetStore.shared.moveMyArticle(
                                article,
                                toPlanet: targetPlanet
                            )
                        }
                        catch {
                            debugPrint("failed to move article: \(error)")
                            PlanetStore.shared.isShowingAlert = true
                            PlanetStore.shared.alertTitle = "Failed to Move Article"
                            switch error {
                            case PlanetError.MovePublishingPlanetArticleError:
                                PlanetStore.shared.alertMessage =
                                    "Please wait for the planet publishing completed then try again."
                            default:
                                PlanetStore.shared.alertMessage = error.localizedDescription
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        if let image = articleItemAvatarImage(fromPlanet: targetPlanet) {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        }
                        Text(targetPlanet.name)
                        Spacer(minLength: 4)
                    }
                }
            }
        }
    }

    private func articleItemAvatarImage(fromPlanet planet: MyPlanetModel) -> NSImage? {
        let size = CGSize(width: 24, height: 24)
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
}
