import Foundation
import Cocoa


class PlanetDockPlugIn: NSObject, NSDockTilePlugIn {
    var targetPackageName: String = UserDefaults.standard.string(forKey: "PlanetDockIconLastPackageName") ?? ""
    
    func setDockTile(_ dockTile: NSDockTile?) {
//        let bundle = Bundle(identifier: "xyz.planetable.Planet.PlanetDockPlugIn")
//        let theDockTile = PlanetDockTile(dockTile: dockTile)
        let notificationName = Notification.Name("xyz.planetable.Planet.PlanetDockIconSyncPackageName")
        DistributedNotificationCenter.default().addObserver(forName: notificationName, object: nil, queue: nil) { [weak self] n in
            guard let selectedPackageName = n.object as? String else { return }
            UserDefaults.standard.set(selectedPackageName, forKey: "PlanetDockIconLastPackageName")
            self?.targetPackageName = selectedPackageName
            self?.updateDock(forDockTile: dockTile, packageName: selectedPackageName)
//            theDockTile.update(withPackageName: selectedPackageName, andBundle: bundle)
        }
//        theDockTile.update(withPackageName: targetPackageName, andBundle: bundle)
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
//        theDockTile.update(with: targetPackageName, bundle: bundle)
    }
}
