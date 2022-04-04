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

struct SmartFeedView: View {
    var feedType: SmartFeedType
    
    var body: some View {
        HStack(spacing: 4) {
            switch (feedType) {
            case .today:
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(Color.black)
                    .frame(width: 14, height: 14)
                    .padding(.top, 4)
                    .padding(.bottom, 4)
                    .padding(.leading, 4)
                    .padding(.trailing, 4)
                Text("Today")
                    .font(.body)
                    .foregroundColor(.primary)
            case .unread:
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(Color.black)
                    .frame(width: 14, height: 14)
                    .padding(.top, 4)
                    .padding(.bottom, 4)
                    .padding(.leading, 4)
                    .padding(.trailing, 4)
                Text("Unread")
                    .font(.body)
                    .foregroundColor(.primary)
            case .starred:
                Image(systemName: "star.fill")
                    .renderingMode(.original)
                    .frame(width: 14, height: 14)
                    .padding(.top, 4)
                    .padding(.bottom, 4)
                    .padding(.leading, 4)
                    .padding(.trailing, 4)
                Text("Starred")
                    .font(.body)
                    .foregroundColor(.primary)
            case .custom:
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(Color.black)
                    .frame(width: 14, height: 14)
                    .padding(.top, 4)
                    .padding(.bottom, 4)
                    .padding(.leading, 4)
                    .padding(.trailing, 4)
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
