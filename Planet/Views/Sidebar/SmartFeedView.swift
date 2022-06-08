//
//  SmartFeedView.swift
//  Planet
//
//  Created by Livid on 4/4/22.
//

import SwiftUI

enum SmartFeedType: Int {
    case today
    case unread
    case starred
    case custom
}

struct SmartFeedView: View {
    let item_size: CGFloat = 18
    let padding: CGFloat = 2

    var feedType: SmartFeedType

    var body: some View {
        HStack(spacing: 4) {
            switch (feedType) {
            case .today:
                Image(systemName: "sun.max.fill")
                    .resizable()
                    .foregroundColor(Color.orange)
                    .frame(width: item_size, height: item_size)
                    .padding(.all, padding)
                Text("Today")
                    .font(.body)
                    .foregroundColor(.primary)
            case .unread:
                Image(systemName: "circle.inset.filled")
                    .resizable()
                    .foregroundColor(Color.blue)
                    .frame(width: item_size, height: item_size)
                    .padding(.all, padding)
                Text("Unread")
                    .font(.body)
                    .foregroundColor(.primary)
            case .starred:
                Image(systemName: "star.fill")
                    .resizable()
                    .renderingMode(.original)
                    .frame(width: item_size, height: item_size)
                    .padding(.all, padding)
                Text("Starred")
                    .font(.body)
                    .foregroundColor(.primary)
            case .custom:
                Image(systemName: "questionmark.circle.fill")
                    .resizable()
                    .foregroundColor(Color.primary)
                    .frame(width: item_size, height: item_size)
                    .padding(.all, padding)
                Text("Custom")
                    .font(.body)
                    .foregroundColor(.primary)
            }
        }
    }
}
