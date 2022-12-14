//
//  PFDashboardSidebarView.swift
//  PublishedFoldersDashboard
//
//  Created by Kai on 11/25/22.
//

import SwiftUI

struct PFDashboardSidebarView: View {
    var body: some View {
        VStack {
            List {
                ForEach(0..<100) { i in
                    HStack {
                        Text("[SwiftUI] Sidebar \(i)")
                        Spacer()
                    }
                }
            }
            .listStyle(.sidebar)
        }
        .frame(width: .sidebarWidth)
    }
}

struct PFDashboardSidebarView_Previews: PreviewProvider {
    static var previews: some View {
        PFDashboardSidebarView()
    }
}
