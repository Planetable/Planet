//
//  MyArticleGridView.swift
//  Planet
//
//  Created by Xin Liu on 11/10/23.
//

import ASMediaView
import SwiftUI

struct MyArticleGridView: View {
    @ObservedObject var article: MyArticleModel
    @State private var isSharing = false
    @State private var isDeleting = false

    var body: some View {
        ZStack {
            if article.hasHeroGrid == true {
                if let image = article.heroGridImage {
                    imageView(image)
                }
                else {
                    textView()
                }
            }
            else {
                textView()
            }
        }
        .onTapGesture {
            if article.hasVideo {
                DispatchQueue.global(qos: .userInitiated).async {
                    if let url = article.videoURL, ASMediaManager.shared.isSupportedVideo(url: url),
                        let videoThumbnail = self.article.getVideoThumbnail(),
                        !CGSizeEqualToSize(.zero, videoThumbnail.size)
                    {
                        DispatchQueue.main.async {
                            ASMediaManager.shared.activateMediaView(
                                withURLs: article.attachmentURLs,
                                title: article.title,
                                id: article.id,
                                defaultSize: videoThumbnail.size
                            )
                        }
                    }
                    else {
                        DispatchQueue.main.async {
                            ASMediaManager.shared.activateMediaView(
                                withURLs: article.attachmentURLs,
                                title: article.title,
                                id: article.id
                            )
                        }
                    }
                }
            }
            else {
                ASMediaManager.shared.activateMediaView(
                    withURLs: article.attachmentURLs,
                    title: article.title,
                    id: article.id
                )
            }
        }
        .background(
            SharingServicePicker(
                isPresented: $isSharing,
                sharingItems: [
                    article.browserURL ?? URL(string: "https://planetable.eth.limo")!
                ]
            )
        )
        .confirmationDialog(
            "Are you sure you want to delete this post?\n\n\(article.title)\n\nThis action cannot be undone.",
            isPresented: $isDeleting
        ) {
            Button("Delete", role: .destructive) {
                ASMediaManager.shared.deactivateView(byID: article.id)
                article.delete()
                PlanetStore.shared.refreshSelectedArticles()
                article.planet.updated = Date()
                try? article.planet.save()

                Task(priority: .userInitiated) {
                    try? await article.planet.savePublic()
                    Task(priority: .background) {
                        try? await article.planet.publish()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .contextMenu {
            Button {
                do {
                    try WriterStore.shared.editArticle(for: article)
                }
                catch {
                    PlanetStore.shared.alert(title: "Failed to launch writer")
                }
            } label: {
                Text("Edit Post")
            }

            Button {
                PlanetStore.shared.selectedArticle = article
                PlanetStore.shared.isShowingMyArticleSettings = true
            } label: {
                Text("Settings")
            }

            Divider()

            if let attachments = article.attachments, let cids = article.cids {
                ForEach(attachments, id: \.self) { attachment in
                    if let cid = cids[attachment],
                        let url = URL(string: "\(IPFSDaemon.shared.gateway)/ipfs/\(cid)")
                    {
                        Button {
                            NSWorkspace.shared.open(url)
                        } label: {
                            Text("View `\(attachment)` on IPFS")
                        }
                    }
                }
            }

            Button {
                if let url = article.browserURL {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(url.absoluteString, forType: .string)
                }
            } label: {
                Text("Copy Shareable Link")
            }

            Button {
                if let url = article.browserURL {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Text("Open Shareable Link in Browser")
            }

            Button {
                if let url = article.localGatewayURL {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Text("Test Post in Browser")
            }

            Divider()

            Button {
                isSharing = true
            } label: {
                Text("Share")
            }

            Divider()

            Button {
                isDeleting = true
            } label: {
                Text("Delete Post")
            }
        }
    }

    @ViewBuilder
    private func imageView(_ image: NSImage) -> some View {
        Image(nsImage: image)
            .interpolation(.high)
            .resizable()
            .aspectRatio(
                1,
                contentMode: .fit
            )
            .frame(minWidth: 128, maxWidth: 256, minHeight: 128, maxHeight: 256)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color("BorderColor"), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        if article.hasGIF {
            GIFIndicatorView()
        }
        if article.attachmentURLs.count > 1 {
            GroupIndicatorView()
        }
    }

    @ViewBuilder
    private func loadingView() -> some View {
        Color(nsColor: NSColor.textBackgroundColor)
            .frame(minWidth: 128, maxWidth: 256, minHeight: 128, maxHeight: 256)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color("BorderColor"), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        ProgressView()
            .progressViewStyle(.circular)
            .controlSize(.small)
    }

    @ViewBuilder
    private func textView() -> some View {
        Color(nsColor: NSColor.textBackgroundColor)
            .frame(minWidth: 128, maxWidth: 256, minHeight: 128, maxHeight: 256)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color("BorderColor"), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)

        Text(article.title)
            .font(.system(size: 14))
            .foregroundColor(.secondary)
            .lineLimit(3)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
    }
}
