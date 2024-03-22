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
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 0) {
                        if article.pinned != nil {
                            Image(systemName: "pin.fill")
                                .font(.caption)
                                .foregroundColor(.accentColor)
                                .padding(.trailing, 4)
                        }
                        Text(article.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        Spacer()

                        Text(article.humanizeCreated())
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    if let summary = article.summary, summary.count > 0 {
                        Text(summary.prefix(280))
                            .foregroundColor(.secondary)
                        if String(summary.prefix(280)).width(usingFont: .body) < 160 {
                            Spacer()
                        }
                    }
                    else if article.content.count > 0 {
                        Text(article.content.prefix(280))
                            .foregroundColor(.secondary)
                        if String(article.content.prefix(280)).width(usingFont: .body) < 160 {
                            Spacer()
                        }
                    }
                    else {
                        Spacer()
                    }
                }
                .frame(height: 56)
                HStack(spacing: 6) {
                    article.mediaLabels(includeSpacers: false)
                    if article.articleType == .page {
                        Text("Page")
                            .lineLimit(1)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.init(top: 3, leading: 4, bottom: 3, trailing: 4))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color(.separatorColor), lineWidth: 1)
                            )
                    }
                    if let included = article.isIncludedInNavigation, included {
                        Text("Navigation \(article.navigationWeight ?? 1)")
                            .lineLimit(1)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.init(top: 3, leading: 4, bottom: 3, trailing: 4))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color(.separatorColor), lineWidth: 1)
                            )
                    }
                    // This is a hack to make the layout consistent
                    if article.hasNoSpecialContent() {
                        Text(" ")
                            .font(.caption)
                            .foregroundColor(.clear)
                        Spacer()
                        Text(" ")
                            .font(.caption)
                            .foregroundColor(.clear)
                    }
                }
            }
        }
        .padding(5)
        .contentShape(Rectangle())
        .contextMenu {
            VStack {
                if !article.isAggregated() {
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
                }
                else {
                    if let siteName = article.originalSiteName {
                        Section {
                            Text("Aggregated from " + siteName)
                        }
                    }
                }

                moveArticleItem()

                Menu("Export Article") {
                    Button {
                        do {
                            try article.exportArticle()
                        } catch {
                            Task { @MainActor in
                                PlanetStore.shared.isShowingAlert = true
                                PlanetStore.shared.alertTitle = "Failed to Export Article"
                                PlanetStore.shared.alertMessage = error.localizedDescription
                            }
                        }
                    } label: {
                        Text("Save as Planet Data File")
                    }
                    Button {
                        do {
                            try article.airDropArticle()
                        } catch {
                            Task { @MainActor in
                                PlanetStore.shared.isShowingAlert = true
                                PlanetStore.shared.alertTitle = "Failed to Share Article"
                                PlanetStore.shared.alertMessage = error.localizedDescription
                            }
                        }
                    } label: {
                        Text("Share via AirDrop")
                    }
                }

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
                if article.pinned == nil {
                    Button {
                        Task {
                            do {
                                try await updateArticlePinStatus(true)
                            } catch {
                                debugPrint("failed to pin article: \(error)")
                            }
                        }
                    } label: {
                        Text("Pin Article")
                    }
                }
                else {
                    Button {
                        Task {
                            do {
                                try await updateArticlePinStatus(false)
                            } catch {
                                debugPrint("failed to unpin article: \(error)")
                            }
                        }
                    } label: {
                        Text("Unpin Article")
                    }
                }

                Divider()

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
                        debugPrint("My Planet Browser URL: \(url.absoluteString)")
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Text("Open in Public Gateway")
                }

                Button {
                    if let url = article.localGatewayURL {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Text("Open in Local Gateway")
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
                            try await planet.savePublic()
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

    private func updateArticlePinStatus(_ flag: Bool) async throws {
        guard let planet = self.article.planet else {
            throw PlanetError.InternalError
        }
        self.article.pinned = flag ? Date() : nil
        try self.article.save()
        try self.article.savePublic()
        planet.updated = Date()
        planet.articles = planet.articles.sorted(by: { MyArticleModel.reorder(a: $0, b: $1) })
        try planet.save()
        try await planet.savePublic()
        Task(priority: .userInitiated) { @MainActor in
            PlanetStore.shared.selectedArticle = self.article
            withAnimation {
                PlanetStore.shared.selectedArticleList = planet.articles
            }
            try await Task.sleep(nanoseconds: 2_500_000_00)
            if flag {
                NotificationCenter.default.post(name: .scrollToTopArticleList, object: nil)
            } else {
                NotificationCenter.default.post(name: .scrollToArticle, object: self.article)
            }
        }
    }
}
