//
//  PFDashboardAccessoryStatusView.swift
//  PublishedFoldersDashboard
//
//  Created by Kai on 11/25/22.
//

import SwiftUI

struct PFDashboardAccessoryStatusView: View {
    var body: some View {
        HStack {
            Text("Accessory Status View")
        }
        .frame(minWidth: .contentWidth, idealWidth: .contentWidth, maxWidth: .infinity, minHeight: 24, idealHeight: 24, maxHeight: 48, alignment: .center)
    }
}

struct PFDashboardAccessoryStatusView_Previews: PreviewProvider {
    static var previews: some View {
        PFDashboardAccessoryStatusView()
    }
}
