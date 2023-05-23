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
            LazyVStack {
                Text(article.title)
                    .font(.title)
                Text(article.content)
                    .font(.body)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
