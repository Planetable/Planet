//
//  AppContentItemView.swift
//  PlanetLite
//

import SwiftUI
import ASMediaView


struct AppContentItemView: View {
    @ObservedObject private var planetStore: PlanetStore = PlanetStore.shared
    
    var article: MyArticleModel
    
    @State private var isShowingDeleteConfirmation = false
    @State private var isSharingLink: Bool = false
    @State private var isGIF: Bool = false
    @State private var sharedLink: String?
    @State private var thumbnail: NSImage?
    @State private var thumbnailCachedPath: URL?
    @State private var attachmentURLs: [URL]?
    
    var body: some View {
        itemPreviewImageView(forArticle: self.article)
            .onTapGesture {
                if let attachmentURLs {
                    processAttachments(attachmentURLs)
                } else {
                    let urls = self.getAttachments(fromArticle: article)
                    processAttachments(urls)
                    Task { @MainActor in
                        self.attachmentURLs = urls
                    }
                }
            }
            .contextMenu {
                AppContentItemMenuView(isShowingDeleteConfirmation: $isShowingDeleteConfirmation, isSharingLink: $isSharingLink, sharedLink: $sharedLink, article: article)
            }
            .confirmationDialog(
                Text("Are you sure you want to delete this post?\n\n\(article.title)?\n\nThis action cannot be undone."),
                isPresented: $isShowingDeleteConfirmation
            ) {
                Button(role: .destructive) {
                    do {
                        if let planet = article.planet {
                            ASMediaManager.shared.deactivateView(byID: article.id)
                            article.delete()
                            planet.updated = Date()
                            try planet.save()
                            Task {
                                try await planet.savePublic()
                                try await planet.publish()
                            }
                            Task(priority: .background) {
                                if let thumbnailCachedPath = thumbnailCachedPath {
                                    try? FileManager.default.removeItem(at: thumbnailCachedPath)
                                }
                            }
                        }
                    } catch {
                        PlanetStore.shared.alert(title: "Failed to delete article: \(error)")
                    }
                } label: {
                    Text("Delete")
                }
            }
            .background(
                SharingServicePicker(isPresented: $isSharingLink, sharingItems: [sharedLink ?? ""])
            )
            .task(id: article.id, priority: .utility) {
                guard attachmentURLs == nil else { return }
                attachmentURLs = getAttachments(fromArticle: article)
            }
    }
    
    private func getAttachments(fromArticle article: MyArticleModel) -> [URL] {
        var urls: [URL] = []
        if let attachmentNames: [String] = article.attachments {
            for name in attachmentNames {
                if let url = article.getAttachmentURL(name: name), FileManager.default.fileExists(atPath: url.path) {
                    urls.append(url)
                }
            }
        }
        return urls
    }
    
    private func processAttachments(_ urls: [URL]) {
        if article.hasVideo {
            ASMediaManager.shared.activateVideoView(withVideos: urls, title: article.title, andID: article.id)
        } else {
            ASMediaManager.shared.activatePhotoView(withPhotos: urls, title: article.title, andID: article.id)
        }
    }
    
    @ViewBuilder
    private func itemPreviewImageView(forArticle article: MyArticleModel) -> some View {
        ZStack {
            Rectangle()
                .fill(.secondary.opacity(0.15))
            if let thumbnail = thumbnail {
                GeometryReader { g in
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: g.size.width, height: g.size.height)
                        .clipShape(Rectangle())
                }
            } else {
                if let heroImageName = article.getHeroImage() {
                    let cachedHeroImageName = article.id.uuidString + "-" + heroImageName
                    let cachedPath = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(cachedHeroImageName)!
                    if let cachedHeroImage = NSImage(contentsOf: cachedPath) {
                        GeometryReader { g in
                            Image(nsImage: cachedHeroImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: g.size.width, height: g.size.height)
                                .clipShape(Rectangle())
                                .task(priority: .background) {
                                    let heroImagePath = article.publicBasePath.appendingPathComponent(heroImageName)
                                    guard let heroImage = NSImage(contentsOf: heroImagePath) else { return }
                                    if ASMediaManager.shared.imageIsGIF(image: heroImage) {
                                        await MainActor.run {
                                            self.isGIF = true
                                        }
                                    }
                                }
                        }
                    } else {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .frame(width: 16, height: 16, alignment: .center)
                            .task(id: article.id, priority: .background) {
                                let heroImagePath = article.publicBasePath.appendingPathComponent(heroImageName)
                                guard let heroImage = NSImage(contentsOf: heroImagePath) else {
                                    await MainActor.run {
                                        self.thumbnail = nil
                                    }
                                    return
                                }
                                if let image = heroImage.resizeSquare(maxLength: 512) {
                                    Task(priority: .background) {
                                        do {
                                            try image.PNGData?.write(to: cachedPath)
                                            self.thumbnailCachedPath = cachedPath
                                        } catch {
                                            debugPrint("failed to save cached thumbnail for article: \(error)")
                                        }
                                    }
                                    await MainActor.run {
                                        self.thumbnail = image
                                    }
                                }
                                if ASMediaManager.shared.imageIsGIF(image: heroImage) {
                                    await MainActor.run {
                                        self.isGIF = true
                                    }
                                }
                            }
                    }
                } else {
                    if let summary = article.summary, summary != "" {
                        Text(article.summary!)
                    } else {
                        Text(article.title)
                    }
                }
            }
            if isGIF {
                GIFIndicatorView()
            }
            if let attachmentURLs, attachmentURLs.count > 1 {
                GroupIndicatorView()
            }
        }
        .contentShape(Rectangle())
        .cornerRadius(6)
    }
    
}
