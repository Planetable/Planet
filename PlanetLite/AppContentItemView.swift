//
//  AppContentItemView.swift
//  PlanetLite
//

import SwiftUI


struct AppContentItemView: View {
    @EnvironmentObject private var planetStore: PlanetStore
    
    var article: MyArticleModel
    var width: CGFloat
    
    @State private var isShowingDeleteConfirmation = false

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
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .cornerRadius(4)
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .onTapGesture {
            Task { @MainActor in
                AppContentDetailsWindowManager.shared.activateWindowController(forArticle: self.article)
            }
        }
        .contextMenu {
            Button {
                isShowingDeleteConfirmation = true
            } label: {
                Text("Delete Article")
            }
        }
        .confirmationDialog(
            Text("Are you sure you want to delete this article?"),
            isPresented: $isShowingDeleteConfirmation
        ) {
            Button(role: .destructive) {
                do {
                    if let planet = article.planet {
                        article.delete()
                        planet.updated = Date()
                        try planet.save()
                        try planet.savePublic()
                        Task { @MainActor in
                            AppContentDetailsWindowManager.shared.deactivateWindowController(forArticle: article)
                            planetStore.selectedView = .myPlanet(planet)
                        }
                    }
                } catch {
                    PlanetStore.shared.alert(title: "Failed to delete article: \(error)")
                }
            } label: {
                Text("Delete")
            }
        }
    }
}
