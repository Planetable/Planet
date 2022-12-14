//
//  PFDashboardView.swift
//  PublishedFoldersDashboard
//
//  Created by Kai on 11/25/22.
//

import SwiftUI


struct PFDashboardView: View {
    @State private var isAlert: Bool = false

    var body: some View {
        VStack {
            List {
                Button {
                    isAlert = true
                } label: {
                    Text("Alert")
                }
                ForEach(0..<100) { i in
                    HStack {
                        Text("[SwiftUI] Content \(i)")
                        Spacer()
                    }
                }
            }
        }
        .frame(minWidth: .contentWidth, idealWidth: .contentWidth, maxWidth: .infinity, minHeight: 320, idealHeight: 320, maxHeight: .infinity, alignment: .center)
        .sheet(isPresented: $isAlert) {
            VStack {
                HStack {
                    Text("Hello")
                    Spacer()
                }
                Spacer()
                Button {
                    isAlert = false
                } label: {
                    Text("Dismiss")
                }
            }
            .frame(width: 400, height: 200)
        }
    }
}

struct PublishedFoldersDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        PFDashboardView()
    }
}
