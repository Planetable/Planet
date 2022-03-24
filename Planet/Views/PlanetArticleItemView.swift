//
//  PlanetArticleItemView.swift
//  Planet
//
//  Created by Xin Liu on 3/24/22.
//

import SwiftUI

struct PlanetArticleItemView: View {
    var article: PlanetArticle
    
    var body: some View {
        VStack {
            HStack {
                Text(article.title ?? "")
                    .foregroundColor(.primary)
                Spacer()
            }
            HStack {
                Text(article.created?.dateDescription() ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
    }
}

/*
struct PlanetArticleItemView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetArticleItemView()
    }
}
*/
