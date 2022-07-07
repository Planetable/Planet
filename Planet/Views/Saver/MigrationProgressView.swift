//
//  MigrationProgressView.swift
//  Planet
//
//  Created by Xin Liu on 7/7/22.
//

import SwiftUI


struct IndeterminateProgressView: NSViewRepresentable {
    func makeNSView(context: Context) -> some NSView {
        let progressView = NSProgressIndicator()
        progressView.isIndeterminate = true
        progressView.startAnimation(nil)
        return progressView
    }
    
    func updateNSView(_ nsView: NSViewType, context: Context) {
    }
}

struct MigrationProgressView: View {
    var body: some View {
        VStack(spacing: 10) {
            Text("Migrating data to the new format")
            IndeterminateProgressView()
                .frame(width: 300)
        }
        .padding(20)
        .background(Color(.white))
    }
}

struct MigrationProgressView_Previews: PreviewProvider {
    static var previews: some View {
        MigrationProgressView()
    }
}
