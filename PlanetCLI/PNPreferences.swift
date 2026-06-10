import Foundation

enum PNPreferences {
    static let bundleIdentifier = "xyz.planetable.Planet"
    static let environmentContainerDataPath = "PLANET_CLI_CONTAINER_DATA_PATH"
    static let environmentIPFSRepositoryPath = "PLANET_CLI_IPFS_REPOSITORY_PATH"
    static let environmentIPFSExecutablePath = "PLANET_CLI_IPFS_EXECUTABLE"
    static let settingsLibraryLocation = "PlanetSettingsLibraryLocationKey"
    static let settingsAPIEnabled = "PlanetSettingsAPIEnabledKey"
    static let settingsAPIUsesPasscode = "PlanetSettingsAPIUsesPasscodeKey"
    static let settingsAPIPort = "PlanetSettingsAPIPortKey"
    static let settingsAPIUsername = "PlanetSettingsAPIUsernameKey"
    static let settingsAPIPasscode = "PlanetSettingsAPIPasscodeKey"
    static let myPlanetsOrderKey = "myPlanetsOrder"

    static var homeURL: URL {
        URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
    }

    static var containerDataURL: URL {
        if let override = environmentURL(environmentContainerDataPath, isDirectory: true) {
            return override
        }
        return homeURL
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Containers", isDirectory: true)
            .appendingPathComponent(bundleIdentifier, isDirectory: true)
            .appendingPathComponent("Data", isDirectory: true)
    }

    static var defaultLibraryURL: URL {
        containerDataURL
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("Planet", isDirectory: true)
    }

    static var ipfsRepositoryURL: URL {
        if let override = environmentURL(environmentIPFSRepositoryPath, isDirectory: true) {
            return override
        }
        return containerDataURL
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("ipfs", isDirectory: true)
    }

    static var ipfsExecutableOverrideURL: URL? {
        environmentURL(environmentIPFSExecutablePath, isDirectory: false)
    }

    static var preferencesURL: URL {
        containerDataURL
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Preferences", isDirectory: true)
            .appendingPathComponent("\(bundleIdentifier).plist", isDirectory: false)
    }

    static var preferences: [String: Any] {
        guard FileManager.default.fileExists(atPath: preferencesURL.path),
              let data = try? Data(contentsOf: preferencesURL),
              let object = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let preferences = object as? [String: Any]
        else {
            return [:]
        }
        return preferences
    }

    static func libraryURL(override: URL?) -> URL {
        if let override {
            return override.standardizedFileURL
        }
        if let path = preferences[settingsLibraryLocation] as? String, !path.isEmpty {
            let libraryURL = URL(fileURLWithPath: path, isDirectory: true)
            let planetURL = libraryURL.appendingPathComponent("Planet", isDirectory: true)
            if FileManager.default.fileExists(atPath: planetURL.path) {
                return planetURL.standardizedFileURL
            }
        }
        return defaultLibraryURL.standardizedFileURL
    }

    static func apiPort() -> Int {
        if let value = preferences[settingsAPIPort] as? String, let port = Int(value) {
            return port
        }
        if let value = preferences[settingsAPIPort] as? NSNumber {
            return value.intValue
        }
        return 8086
    }

    static func apiURL(override: URL?) -> URL {
        override ?? URL(string: "http://127.0.0.1:\(apiPort())")!
    }

    static func apiUsesPasscode() -> Bool {
        (preferences[settingsAPIUsesPasscode] as? Bool) ?? false
    }

    static func apiUsername() -> String {
        (preferences[settingsAPIUsername] as? String)?.pnNilIfEmpty ?? "Planet"
    }

    private static func environmentURL(_ name: String, isDirectory: Bool) -> URL? {
        guard let rawValue = getenv(name),
              let value = String(validatingUTF8: rawValue)?.pnNilIfEmpty
        else {
            return nil
        }
        return URL(fileURLWithPath: value, isDirectory: isDirectory).standardizedFileURL
    }
}
