//
//  AppContentItemView.swift
//  PlanetLite
//

import SwiftUI
import ASMediaView


struct AppContentItemView: View {
    @EnvironmentObject private var planetStore: PlanetStore

    var article: MyArticleModel
    var size: NSSize

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
            DispatchQueue.global(qos: .userInitiated).async {
                if let url = urls.first, ASMediaManager.shared.isSupportedVideo(url: url), let videoThumbnail = self.article.getVideoThumbnail(), !CGSizeEqualToSize(.zero, videoThumbnail.size) {
                    DispatchQueue.main.async {
                        ASMediaManager.shared.activateMediaView(withURLs: urls, title: self.article.title, id: self.article.id, defaultSize: videoThumbnail.size)
                    }
                } else {
                    DispatchQueue.main.async {
                        ASMediaManager.shared.activateMediaView(withURLs: urls, title: self.article.title, id: self.article.id)
                    }
                }
            }
        } else {
            ASMediaManager.shared.activateMediaView(withURLs: urls, title: article.title, id: article.id)
        }
    }

    @ViewBuilder
    private func itemPreviewImageView(forArticle article: MyArticleModel) -> some View {
        ZStack {
            Rectangle()
                .fill(.secondary.opacity(0.15))
            if let thumbnail = thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                if let heroImageName = article.getHeroImage() {
                    let cachedHeroImageName = article.id.uuidString + "-" + heroImageName
                    let cachedPath = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(cachedHeroImageName)!
                    if let cachedHeroImage = NSImage(contentsOf: cachedPath) {
                        Image(nsImage: cachedHeroImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .task(priority: .background) {
                                let heroImagePath = article.publicBasePath.appendingPathComponent(heroImageName)
                                guard let heroImage = NSImage(contentsOf: heroImagePath) else { return }
                                if ASMediaManager.shared.imageIsGIF(image: heroImage) {
                                    await MainActor.run {
                                        self.isGIF = true
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
                                if let image = heroImage.resizeSquare(maxLength: Int(size.width * 2)) {
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
        .frame(width: size.width, height: size.height)
        .cornerRadius(6)
    }

}
