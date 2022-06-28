//
//  Saver.swift
//  Planet
//
//  Created by Xin Liu on 6/8/22.
//

import Foundation
import os

// A simple program for saving data from Core Data to JSON files on disk

class Saver: NSObject {
    static let shared = Saver()
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Saver")

    static let applicationSupportDirectory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    static let coreDataPath: URL = applicationSupportDirectory.appendingPathComponent("Planet").appendingPathComponent("Planet.sqlite")
    static let documentDirectory: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

    static let repoDirectory: URL = documentDirectory.appendingPathComponent("Planet", isDirectory: true)
    static let publicDirectory: URL = MyPlanetModel.publicPlanetsPath

    static let myPlanetsDirectory: URL = MyPlanetModel.myPlanetsPath
    static let followingPlanetsDirectory: URL = FollowingPlanetModel.followingPlanetsPath

    private override init() {
        super.init()
    }

    func isMigrationNeeded() -> Bool {
        if FileManager.default.fileExists(atPath: Saver.coreDataPath.path) {
            logger.info("found legacy Core Data container at \(Saver.coreDataPath.path)")
            if let migrationDone = UserDefaults.standard.value(forKey: "CoreDataMigrationDone") as? Bool {
                if migrationDone {
                    logger.info("migration has done previously, nothing to do now")
                    return false
                } else {
                    logger.info("migration for legacy Core Data container is needed")
                    return true
                }
            } else {
                logger.info("no CoreDataMigrationDone flag found, migration for legacy Core Data container is needed")
                return true
            }
        } else {
            logger.info("no legacy Core Data container found")
            return false
        }
    }

    func setMigrationDoneFlag(flag: Bool) {
        UserDefaults.standard.set(flag, forKey: "CoreDataMigrationDone")
    }

    func prepareAllDirectories() {
        let directories: [URL] = [
            Saver.repoDirectory,
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

        let planets = CoreDataPersistence.shared.getPlanets()

        for planet in planets {
            guard let planetID = planet.id else {
                logger.error("failed to get planet.id for \(planet)")
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
                var data: Data
                if planet.isMyPlanet() {
                    data = try encoder.encode(planet.asNewMyPlanet)
                } else {
                    data = try encoder.encode(planet.asNewFollowingPlanet)
                }
                try data.write(to: fileURL)
                logger.info("planet saved to \(fileURL)")
            } catch {
                logger.error("failed to save planet: \(planet)")
            }

            // Copy legacy avatar.png over to new directory

            let legacyAvatarURL: URL = Saver.applicationSupportDirectory.appendingPathComponent("planets").appendingPathComponent(planetID.uuidString).appendingPathComponent("avatar.png")
            let newAvatarURL: URL = planetURL.appendingPathComponent("avatar.png")
            if FileManager.default.fileExists(atPath: legacyAvatarURL.path) {
                try? FileManager.default.copyItem(at: legacyAvatarURL, to: newAvatarURL)
                logger.info("copied avatar.png from \(legacyAvatarURL) to \(newAvatarURL)")
            } else {
                logger.info("no avatar.png found in \(planet)")
            }

            // Save articles

            let articles = CoreDataPersistence.shared.getArticles(byPlanetID: planetID)

            let articlesDirectory = planetURL.appendingPathComponent("Articles", isDirectory: true)
            if FileManager.default.fileExists(atPath: articlesDirectory.path) == false {
                try? FileManager.default.createDirectory(at: articlesDirectory, withIntermediateDirectories: true, attributes: nil)
            }

            if planet.isMyPlanet() {
                let draftsDirectory = planetURL.appendingPathComponent("Drafts", isDirectory: true)
                if FileManager.default.fileExists(atPath: draftsDirectory.path) == false {
                    try? FileManager.default.createDirectory(at: draftsDirectory, withIntermediateDirectories: true, attributes: nil)
                }
            }

            for article in articles {
                guard let articleID = article.id else {
                    debugPrint("Saver: failed to get article.id for \(article)")
                    continue
                }
                let fileName: String = "\(articleID.uuidString).json"
                let fileURL = articlesDirectory.appendingPathComponent(fileName)
                do {
                    var data: Data
                    if planet.isMyPlanet() {
                        data = try encoder.encode(article.asNewMyArticle)
                    } else {
                        data = try encoder.encode(article.asNewFollowingArticle)
                    }
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

        let planets = CoreDataPersistence.shared.getLocalPlanets()

        for planet in planets {
            guard let planetID = planet.id else {
                logger.error("failed to get planet.id from \(planet)")
                continue
            }

            let legacyDirectory = Saver.applicationSupportDirectory.appendingPathComponent("planets").appendingPathComponent(planetID.uuidString)
            let newDirectory = Saver.publicDirectory.appendingPathComponent(planetID.uuidString)

            if FileManager.default.fileExists(atPath: legacyDirectory.path) {
                try? FileManager.default.copyItem(at: legacyDirectory, to: newDirectory)
                logger.info("copied \(planetID) \(planet) from \(legacyDirectory) to \(newDirectory)")
            } else {
                logger.info("no \(planetID) \(planet) found in \(legacyDirectory)")
            }
        }
    }

    func migrateTemplates() {
        // Migrate all templates from Application Support

        let templatesDirectory: URL = Saver.applicationSupportDirectory.appendingPathComponent("templates")
        let newTemplatesDirectory: URL = Saver.documentDirectory.appendingPathComponent("Templates")

        if FileManager.default.fileExists(atPath: templatesDirectory.path) {
            try? FileManager.default.copyItem(at: templatesDirectory, to: newTemplatesDirectory)
            logger.info("copied templates from \(templatesDirectory) to \(newTemplatesDirectory)")
        } else {
            logger.info("no templates found in \(templatesDirectory)")
        }
    }
}
