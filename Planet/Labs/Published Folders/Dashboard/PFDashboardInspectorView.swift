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
            Text("Inspector")
        }
        .frame(minWidth: .inspectorWidth, maxWidth: .infinity, minHeight: 320, maxHeight: .infinity)
    }
}

struct PFDashboardInspectorView_Previews: PreviewProvider {
    static var previews: some View {
        PFDashboardInspectorView()
    }
}
