import SwiftUI
import Foundation
import CoreData
import FeedKit
import ENSKit
import SwiftSoup


enum PublicGateway: String {
    case cloudflare = "www.cloudflare-ipfs.com"
    case ipfs = "ipfs.io"
    case dweb = "dweb.link"
}

class CoreDataPersistence: NSObject {
    static let shared = CoreDataPersistence()

    // let enskit = ENSKit(jsonrpcClient: InfuraEthereumAPI(url: URL(string: "https://mainnet.infura.io/v3/<projectid>")!))
    let enskit = ENSKit(ipfsClient: GoIPFSGateway())

    var persistentContainer: NSPersistentContainer

    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    override init() {
        persistentContainer = NSPersistentContainer(name: "Planet")
        persistentContainer.loadPersistentStores { storeDescription, error in
            debugPrint("Store Description: \(storeDescription)")
            if let error = error {
                fatalError("Unable to load data store: \(error)")
            }
        }
        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
    }

    func save(context: NSManagedObjectContext? = nil) {
        if context == nil || context == persistentContainer.viewContext {
            Task { @MainActor in
                let ctx = persistentContainer.viewContext
                guard ctx.hasChanges else { return }
                do {
                    try ctx.save()
                } catch {
                    debugPrint("Failed to save main context: \(error)")
                }
            }
        } else {
            guard context!.hasChanges else { return }
            do {
                try context!.save()
            } catch {
                debugPrint("Failed to save given context: \(error)")
            }
        }
    }
    
    func getPlanets() -> [Planet] {
        let request: NSFetchRequest<Planet> = Planet.fetchRequest()
        request.predicate = NSPredicate(format: "softDeleted == nil")
        do {
            return try persistentContainer.viewContext.fetch(request)
        } catch {
            debugPrint("failed to get planets: \(error)")
            return []
        }
    }
    
    func getLocalPlanets(context: NSManagedObjectContext? = nil) -> Set<Planet> {
        let request: NSFetchRequest<Planet> = Planet.fetchRequest()
        request.predicate = NSPredicate(format: "keyName != nil && keyID != nil && softDeleted == nil")
        let ctx = context ?? persistentContainer.viewContext
        do {
            let planets: [Planet] = try ctx.fetch(request)
            return Set(planets)
        } catch {
            debugPrint("failed to get planets: \(error)")
        }
        return Set()
    }
}
