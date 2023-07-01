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
    @State private var sharedLink: String?
    @State private var thumbnail: NSImage?
    @State private var thumbnailCachedPath: URL?
    
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
        .cornerRadius(6)
    }

}
