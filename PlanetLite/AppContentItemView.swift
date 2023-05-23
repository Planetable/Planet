//
//  AppContentItemView.swift
//  PlanetLite
//
//  Created by Kai on 5/22/23.
//

import SwiftUI


struct AppContentItemView: View {
    @EnvironmentObject private var planetStore: PlanetStore
    
    var article: MyArticleModel
    var width: CGFloat
    
    var body: some View {
        VStack {
            if let img = article.getHeroImage(), let heroImage = NSImage(contentsOf: article.publicBasePath.appendingPathComponent(img)) {
                Image(nsImage: heroImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width)
            } else {
                Text(article.summary ?? "No summary")
            }
        }
        .contentShape(Rectangle())
        .frame(width: width, height: width)
        .background(Color.secondary.opacity(0.15))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .onTapGesture {
            Task { @MainActor in
                AppContentDetailsWindowManager.shared.activateWindowController(forArticle: self.article)
            }
        }
    }
}
