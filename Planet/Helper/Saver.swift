//
//  Saver.swift
//  Planet
//
//  Created by Xin Liu on 6/8/22.
//

import Foundation

// A simple program for saving data from Core Data to JSON files on disk

class Saver: NSObject {
    static let shared = Saver()

    static let applicationSupportDirectory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    static let documentDirectory: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

    static let planetsDirectory: URL = Saver.documentDirectory.appendingPathComponent("Planets", isDirectory: true)
    static let publicDirectory: URL = Saver.documentDirectory.appendingPathComponent("Public", isDirectory: true)

    static let myPlanetsDirectory: URL = Saver.planetsDirectory.appendingPathComponent("My", isDirectory: true)
    static let followingPlanetsDirectory: URL = Saver.planetsDirectory.appendingPathComponent("Following", isDirectory: true)

    private override init() {
        super.init()
    }

    func prepareAllDirectories() {
        let directories: [URL] = [
            Saver.planetsDirectory,
            Saver.publicDirectory,
            Saver.myPlanetsDirectory,
            Saver.followingPlanetsDirectory
        ]

        for directory in directories {
            if FileManager.default.fileExists(atPath: directory.path) == false {
                try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            }
        }
    }

    func savePlanets() {
        Saver.shared.prepareAllDirectories()

        let encoder = JSONEncoder()

        let planets = PlanetDataController.shared.getPlanets()

        for planet in planets {
            guard let planetID = planet.id else {
                debugPrint("Saver: failed to get planet.id for \(planet)")
                continue
            }
            let fileName: String = "planet.json"
            var planetURL: URL
            if planet.isMyPlanet() {
                planetURL = Saver.myPlanetsDirectory.appendingPathComponent(planetID.uuidString)
            } else {
                planetURL = Saver.followingPlanetsDirectory.appendingPathComponent(planetID.uuidString)
            }
            if FileManager.default.fileExists(atPath: planetURL.path) == false {
                try? FileManager.default.createDirectory(at: planetURL, withIntermediateDirectories: true, attributes: nil)
            }
            let fileURL = planetURL.appendingPathComponent(fileName)
            do {
                let data = try encoder.encode(planet)
                try data.write(to: fileURL)
                print("Saver: planet saved to \(fileURL)")
            } catch {
                print("Saver: failed to save planet: \(planet) \(error)")
            }

            let articles = PlanetDataController.shared.getArticles(byPlanetID: planetID)

            let articlesDirectory = planetURL.appendingPathComponent("Articles", isDirectory: true)
            if FileManager.default.fileExists(atPath: articlesDirectory.path) == false {
                try? FileManager.default.createDirectory(at: articlesDirectory, withIntermediateDirectories: true, attributes: nil)
            }

            // Copy legacy avatar.png over to new directory

            let legacyAvatarURL: URL = Saver.applicationSupportDirectory.appendingPathComponent("planets").appendingPathComponent(planetID.uuidString).appendingPathComponent("avatar.png")
            let newAvatarURL: URL = planetURL.appendingPathComponent("avatar.png")
            if FileManager.default.fileExists(atPath: legacyAvatarURL.path) {
                try? FileManager.default.copyItem(at: legacyAvatarURL, to: newAvatarURL)
                debugPrint("Saver: copied avatar.png from \(legacyAvatarURL) to \(newAvatarURL)")
            } else {
                debugPrint("Saver: no avatar.png found in \(planet)")
            }

            // Save articles

            for article in articles {
                guard let articleID = article.id else {
                    debugPrint("Saver: failed to get article.id for \(article)")
                    continue
                }
                let fileName: String = "\(articleID.uuidString).json"
                let fileURL = articlesDirectory.appendingPathComponent(fileName)
                do {
                    let data = try encoder.encode(article)
                    try data.write(to: fileURL)
                    print("Saver: article saved to \(fileURL)")
                } catch {
                    print("Saver: failed to save article: \(article) \(error)")
                }
            }
        }
    }

    func migratePublic() {
        // Migrate all files from my planets

        let planets = PlanetDataController.shared.getLocalPlanets()

        for planet in planets {
            guard let planetID = planet.id else {
                debugPrint("Saver: failed to get planet.id from \(planet)")
                continue
            }

            let legacyDirectory = Saver.applicationSupportDirectory.appendingPathComponent("planets").appendingPathComponent(planetID.uuidString)
            let newDirectory = Saver.publicDirectory.appendingPathComponent(planetID.uuidString)

            if FileManager.default.fileExists(atPath: legacyDirectory.path) {
                try? FileManager.default.copyItem(at: legacyDirectory, to: newDirectory)
                debugPrint("Saver: copied \(planetID) \(planet) from \(legacyDirectory) to \(newDirectory)")
            } else {
                debugPrint("Saver: no \(planetID) \(planet) found in \(legacyDirectory)")
            }
        }
    }
}
