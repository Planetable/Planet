//
//  PlanetKeyManagerView.swift
//  Planet
//
//  Created by Kai on 3/9/23.
//

import SwiftUI


struct PlanetKeyManagerView: View {
    @StateObject private var keyManagerViewModel: PlanetKeyManagerViewModel
    
    init() {
        _keyManagerViewModel = StateObject(wrappedValue: PlanetKeyManagerViewModel.shared)
    }

    var body: some View {
        VStack {
            Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
        }
        .frame(minWidth: 320, idealWidth: 320, maxWidth: 640, minHeight: 480, idealHeight: 480, maxHeight: .infinity)
    }
}

struct PlanetKeyManagerView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetKeyManagerView()
    }
}
