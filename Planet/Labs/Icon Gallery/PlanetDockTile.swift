//
//  PlanetDockTile.swift
//  Planet
//
//  Created by Kai on 3/21/25.
//

import Foundation
import Cocoa

/*
class PlanetDockTile: @unchecked Sendable {
    private weak var dockTile: NSDockTile?

    init(dockTile: NSDockTile?) {
        self.dockTile = dockTile
    }

    func update(withPackageName packageName: String, andBundle bundle: Bundle?) {
        DispatchQueue.main.async { [weak self] in
            guard let dockTile = self?.dockTile else { return }
            guard packageName != "", let targetImage = bundle?.image(forResource: packageName) else {
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
*/
