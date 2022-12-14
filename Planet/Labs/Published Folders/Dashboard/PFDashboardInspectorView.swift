//
//  PFDashboardInspectorView.swift
//  PublishedFoldersDashboard
//
//  Created by Kai on 11/25/22.
//

import SwiftUI

struct PFDashboardInspectorView: View {
    var body: some View {
        VStack {
            List {
                ForEach(0..<100) { i in
                    HStack {
                        Text("[SwiftUI] Inspector \(i)")
                        Spacer()
                    }
                }
            }
        }
        .frame(width: .inspectorWidth)
    }
}

struct PFDashboardInspectorView_Previews: PreviewProvider {
    static var previews: some View {
        PFDashboardInspectorView()
    }
}
