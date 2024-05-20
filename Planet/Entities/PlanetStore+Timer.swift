//
//  PlanetStore+Timer.swift
//  Planet
//
//  Created by Livid on 9/14/23.
//

import Foundation

/// Scheduled operations
extension PlanetStore {
    /// Run every 300 seconds in Lite, fetch posts from other sites
    func aggregate() async {
        Task {
            await withTaskGroup(of: Void.self) { taskGroup in
                for myPlanet in myPlanets {
                    taskGroup.addTask {
                        await myPlanet.aggregate()
                    }
                }
            }
        }
    }

    /// Run every 180 seconds in Planet, pin the Planet to Pinnable.xyz
    func pin() async {
        debugPrint("Pinning to Pinnable...")
        Task {
            await withTaskGroup(of: Void.self) { taskGroup in
                for myPlanet in myPlanets {
                    if let enabled = myPlanet.pinnableEnabled, enabled {
                        taskGroup.addTask {
                            await myPlanet.callPinnable()
                        }
                    }
                }
            }
        }
    }

    /// Run every 60 seconds in Planet, check if Pinnable has pinned the Planets with Pinnable integration
    func checkPinnable() async {
        debugPrint("Checking Pinnable...")
        Task {
            await withTaskGroup(of: Void.self) { taskGroup in
                for myPlanet in myPlanets {
                    taskGroup.addTask {
                        if let status = await myPlanet.checkPinnablePinStatus() {
                            debugPrint("Pinnable status for \(myPlanet.name): \(status)")
                            if let cid = status.last_known_cid {
                                debugPrint("Pinnable CID for \(myPlanet.name): \(cid)")
                                if cid != myPlanet.pinnablePinCID {
                                    Task { @MainActor in
                                        myPlanet.pinnablePinCID = cid
                                    }
                                    do {
                                        try myPlanet.save()
                                        debugPrint("Saved Planet \(myPlanet.name) with new Pinnable Pin CID \(cid)")
                                    } catch {
                                        debugPrint("Failed to save Planet \(myPlanet.name) with new Pinnable Pin CID \(cid)")
                                    }

                                }
                            }
                        } else {
                            debugPrint("Pinnable status for \(myPlanet.name): nil")
                        }
                    }
                }
            }
        }
    }
}
