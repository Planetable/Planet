//
//  AppContentDetailsView.swift
//  PlanetLite
//
//  Created by Kai on 5/23/23.
//

import SwiftUI


struct AppContentDetailsView: View {
    var article: MyArticleModel

    var body: some View {
        ScrollView {
            LazyVStack (spacing: 16) {
                HStack {
                    Text(article.title)
                        .font(.title)
                    Spacer(minLength: 1)
                }
                HStack {
                    Text(article.created.dateDescription())
                        .foregroundColor(.secondary)
                    Spacer(minLength: 1)
                }
                if let attachments: [String] = article.attachments {
                    ForEach(attachments, id: \.self) { attachment in
                        if let url = article.getAttachmentURL(name: attachment), let image = NSImage(contentsOf: url) {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: image.size.width, maxHeight: image.size.height)
                        }
                    }
                }
                if let externalLink = article.externalLink {
                    HStack {
                        Button {
                            if let link = URL(string: externalLink) {
                                NSWorkspace.shared.open(link)
                            }
                        } label: {
                            Text(externalLink)
                        }
                        .buttonStyle(.link)
                        Spacer(minLength: 1)
                    }
                }
            }
            .padding(16)
        }
        .frame(minWidth: PlanetUI.WINDOW_CONTENT_WIDTH_MIN, maxWidth: .infinity, minHeight: PlanetUI.WINDOW_CONTENT_HEIGHT_MIN, maxHeight: .infinity)
    }
}
