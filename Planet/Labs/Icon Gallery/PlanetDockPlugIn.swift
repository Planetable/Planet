import Foundation
import Cocoa


class PlanetDockPlugIn: NSObject, NSDockTilePlugIn {
    var targetPackageName: String = UserDefaults.standard.string(forKey: "PlanetDockIconLastPackageName") ?? ""
    
    func setDockTile(_ dockTile: NSDockTile?) {
        DistributedNotificationCenter.default().addObserver(forName: Notification.Name("PlanetDockIconSyncPackageName"), object: nil, queue: nil) { [weak self] n in
            guard let selectedPackageName = n.object as? String else { return }
            UserDefaults.standard.set(selectedPackageName, forKey: "PlanetDockIconLastPackageName")
            self?.targetPackageName = selectedPackageName
            self?.updateDock(forDockTile: dockTile, packageName: selectedPackageName)
        }
        updateDock(forDockTile: dockTile, packageName: targetPackageName)
    }
    
    private func updateDock(forDockTile dockTile: NSDockTile?, packageName: String = "") {
        guard packageName != "" else {
            dockTile?.contentView = nil
            dockTile?.display()
            return
        }
        let iconName = packageName
        let bundle = Bundle(identifier: "xyz.planetable.Planet.PlanetDockPlugIn")
        guard let targetImage = bundle?.image(forResource: iconName) else { return }
        let targetImageView = NSImageView(image: targetImage)
        dockTile?.contentView = targetImageView
        dockTile?.display()
    }
}
