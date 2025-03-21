//
//  PlanetDockTile.swift
//  Planet
//
//  Created by Kai on 3/21/25.
//

import Foundation
import Cocoa


class PlanetDockTile: @unchecked Sendable {
    private weak var dockTile: NSDockTile?

    init(dockTile: NSDockTile?) {
        self.dockTile = dockTile
    }

    func update(with packageName: String, bundle: Bundle?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let dockTile = self.dockTile else { return }
            guard !packageName.isEmpty,
                  let targetImage = bundle?.image(forResource: packageName) else {
                dockTile.contentView = nil
                dockTile.display()
                return
            }
            let targetImageView = NSImageView(image: targetImage)
            dockTile.contentView = targetImageView
            dockTile.display()
        }
    }
}
