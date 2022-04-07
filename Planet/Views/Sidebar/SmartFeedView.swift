//
//  SmartFeedView.swift
//  Planet
//
//  Created by Livid on 4/4/22.
//

import SwiftUI

enum SmartFeedType: Int32 {
    case today = 0
    case unread = 1
    case starred = 2
    case custom = 3
}

let SMART_FEED_ITEM_SIZE: CGFloat = 18
let SMART_FEED_ITEM_PADDING: CGFloat = 2


struct SmartFeedView: View {
    var feedType: SmartFeedType
    
    var body: some View {
        HStack(spacing: 4) {
            switch (feedType) {
            case .today:
                Image(systemName: "sun.max.fill")
                    .resizable()
                    .foregroundColor(Color.orange)
                    .frame(width: SMART_FEED_ITEM_SIZE, height: SMART_FEED_ITEM_SIZE)
                    .padding(.top, SMART_FEED_ITEM_PADDING)
                    .padding(.bottom, SMART_FEED_ITEM_PADDING)
                    .padding(.leading, SMART_FEED_ITEM_PADDING)
                    .padding(.trailing, SMART_FEED_ITEM_PADDING)
                Text("Today")
                    .font(.body)
                    .foregroundColor(.primary)
            case .unread:
                Image(systemName: "circle.inset.filled")
                    .resizable()
                    .foregroundColor(Color.blue)
                    .frame(width: SMART_FEED_ITEM_SIZE, height: SMART_FEED_ITEM_SIZE)
                    .padding(.top, SMART_FEED_ITEM_PADDING)
                    .padding(.bottom, SMART_FEED_ITEM_PADDING)
                    .padding(.leading, SMART_FEED_ITEM_PADDING)
                    .padding(.trailing, SMART_FEED_ITEM_PADDING)
                Text("Unread")
                    .font(.body)
                    .foregroundColor(.primary)
            case .starred:
                Image(systemName: "star.fill")
                    .resizable()
                    .renderingMode(.original)
                    .frame(width: SMART_FEED_ITEM_SIZE, height: SMART_FEED_ITEM_SIZE)
                    .padding(.top, SMART_FEED_ITEM_PADDING)
                    .padding(.bottom, SMART_FEED_ITEM_PADDING)
                    .padding(.leading, SMART_FEED_ITEM_PADDING)
                    .padding(.trailing, SMART_FEED_ITEM_PADDING)
                Text("Starred")
                    .font(.body)
                    .foregroundColor(.primary)
            case .custom:
                Image(systemName: "questionmark.circle.fill")
                    .resizable()
                    .foregroundColor(Color.primary)
                    .frame(width: SMART_FEED_ITEM_SIZE, height: SMART_FEED_ITEM_SIZE)
                    .padding(.top, SMART_FEED_ITEM_PADDING)
                    .padding(.bottom, SMART_FEED_ITEM_PADDING)
                    .padding(.leading, SMART_FEED_ITEM_PADDING)
                    .padding(.trailing, SMART_FEED_ITEM_PADDING)
                Text("Custom")
                    .font(.body)
                    .foregroundColor(.primary)
            }
            
        }
    }
}

struct SmartFeedView_Previews: PreviewProvider {
    static var previews: some View {
        SmartFeedView(feedType: .starred)
    }
}
