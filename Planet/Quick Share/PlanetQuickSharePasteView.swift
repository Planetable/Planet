//
//  PlanetQuickSharePasteView.swift
//  Planet
//

import Foundation
import SwiftUI


struct PlanetQuickSharePasteView: NSViewRepresentable {
    func makeNSView(context: Context) -> some NSView {
        let view = PasteView()
        return view
    }
    func updateNSView(_ nsView: NSViewType, context: Context) {}
}


extension PlanetQuickSharePasteView {
    static func handlePaste(_ itemProviders: [NSItemProvider]) {
        // MARK: TODO: handle paste item
    }
}


private class PasteView: NSView {
    init() {
        super.init(frame: .zero)
        self.focusRingType = .none
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
