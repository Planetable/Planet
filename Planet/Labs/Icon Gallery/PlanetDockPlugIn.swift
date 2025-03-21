import Foundation
import Cocoa


class PlanetDockPlugIn: NSObject, NSDockTilePlugIn {
    var targetPackageName: String = UserDefaults.standard.string(forKey: "PlanetDockIconLastPackageName") ?? ""
    
    func setDockTile(_ dockTile: NSDockTile?) {
        let bundle = Bundle(identifier: "xyz.planetable.Planet.PlanetDockPlugIn")
        let theDockTile = PlanetDockTile(dockTile: dockTile)
        let notificationName = Notification.Name("xyz.planetable.Planet.PlanetDockIconSyncPackageName")
        DistributedNotificationCenter.default().addObserver(forName: notificationName, object: nil, queue: nil) { [weak self] n in
            guard let selectedPackageName = n.object as? String else { return }
            UserDefaults.standard.set(selectedPackageName, forKey: "PlanetDockIconLastPackageName")
            self?.targetPackageName = selectedPackageName
            theDockTile.update(with: selectedPackageName, bundle: bundle)
        }
        theDockTile.update(with: targetPackageName, bundle: bundle)
    }
}
