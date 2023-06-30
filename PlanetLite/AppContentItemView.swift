//
//  AppContentItemView.swift
//  PlanetLite
//

import SwiftUI
import ImageIO
import ASMediaView


struct AppContentItemView: View {
    @EnvironmentObject private var planetStore: PlanetStore

    var article: MyArticleModel
    var size: NSSize
    var imageProcessor: AppContentItemHeroImageProcessor

    @State private var isShowingDeleteConfirmation = false
    @State private var isSharingLink: Bool = false
    @State private var sharedLink: String?
    @State private var thumbnail: NSImage?

    init(article: MyArticleModel, size: NSSize) {
        self.article = article
        self.size = size
        self.imageProcessor = AppContentItemHeroImageProcessor(size: size)
    }

    var body: some View {
        itemPreviewImageView(forArticle: self.article)
            .onTapGesture {
                ASMediaManager.shared.activatePhotoView(withPhotos: getPhotos(fromArticle: article), title: article.title, andID: article.id)
            }
            .contextMenu {
                AppContentItemMenuView(isShowingDeleteConfirmation: $isShowingDeleteConfirmation, isSharingLink: $isSharingLink, sharedLink: $sharedLink, article: article)
            }
            .confirmationDialog(
                Text("Are you sure you want to delete this post?"),
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
                                try planet.savePublic()
                                try await planet.publish()
                            }
                            Task { @MainActor in
                                planetStore.selectedView = .myPlanet(planet)
                            }
                            Task(priority: .background) {
                                if let heroImageName = self.article.getHeroImage() {
                                    let cachedHeroImageName = self.article.id.uuidString + "-" + heroImageName
                                    let cachedPath = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(cachedHeroImageName)!
                                    do {
                                        try FileManager.default.removeItem(at: cachedPath)
                                    } catch {
                                        debugPrint("failed to remove cached thumbnail: \(error)")
                                    }
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
    }

    private func getPhotos(fromArticle article: MyArticleModel) -> [URL] {
        var photoURLs: [URL] = []
        if let attachmentNames: [String] = article.attachments {
            for name in attachmentNames {
                if let url = article.getAttachmentURL(name: name), FileManager.default.fileExists(atPath: url.path) {
                    photoURLs.append(url)
                }
            }
        }
        return photoURLs
    }

    @ViewBuilder
    private func itemPreviewImageView(forArticle article: MyArticleModel) -> some View {
        VStack {
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
                                Task.detached(priority: .utility) {
                                    let image = await self.imageProcessor.generateThumbnail(forImage: heroImage, imageName: heroImageName, imagePath: heroImagePath, articleID: article.id)
                                    await MainActor.run {
                                        self.thumbnail = image == nil ? nil : image!
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
        }
        .contentShape(Rectangle())
        .frame(width: size.width, height: size.height)
        .background(Color.secondary.opacity(0.15))
        .cornerRadius(4)
    }

}


actor AppContentItemHeroImageProcessor {
    var size: NSSize

    init(size: NSSize) {
        self.size = size
    }

    func generateThumbnail(forImage image: NSImage, imageName: String, imagePath: URL, articleID: UUID) async -> NSImage? {
        let ratio: CGFloat = image.size.width / image.size.height
        let targetSize = NSSize(width: size.width * 2, height: size.width * 2 / ratio)
        let sourceOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        let imageOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: size.width * 2
        ]
        guard let imageSource = CGImageSourceCreateWithURL(imagePath as NSURL, sourceOptions as CFDictionary), let targetCGImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, imageOptions as CFDictionary) else {
            return nil
        }
        let targetImage = NSImage(cgImage: targetCGImage, size: targetSize)
        let targetImageName = articleID.uuidString + "-" + imageName
        let cachedPath = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(targetImageName)!
        Task (priority: .background) {
            do {
                try targetImage.PNGData?.write(to: cachedPath)
            } catch {
                debugPrint("failed to save cached thumbnail for article: \(error)")
            }
        }
        return targetImage
    }
}
