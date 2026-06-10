import AppKit
import Darwin
import Foundation

enum PNAppBridge {
    static func isPlanetRunning() -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: PNPreferences.bundleIdentifier).isEmpty
    }

    static func openAPIStart(port: Int) throws {
        guard var components = URLComponents(string: "planet://api/start") else {
            throw PNError.runtime("Unable to construct API start URL.")
        }
        components.queryItems = [URLQueryItem(name: "port", value: String(port))]
        guard let url = components.url else {
            throw PNError.runtime("Unable to construct API start URL.")
        }
        NSWorkspace.shared.open(url)
    }

    static func openAPIStop() throws {
        guard let url = URL(string: "planet://api/stop") else {
            throw PNError.runtime("Unable to construct API stop URL.")
        }
        NSWorkspace.shared.open(url)
    }

    static var executableURL: URL {
        var size: UInt32 = 0
        _NSGetExecutablePath(nil, &size)
        var buffer = [CChar](repeating: 0, count: Int(size))
        _NSGetExecutablePath(&buffer, &size)
        return URL(fileURLWithPath: String(cString: buffer)).resolvingSymlinksInPath()
    }

    static var appResourcesURL: URL? {
        let executable = executableURL
        let helpers = executable.deletingLastPathComponent()
        if helpers.lastPathComponent == "Helpers" {
            let contents = helpers.deletingLastPathComponent()
            let resources = contents.appendingPathComponent("Resources", isDirectory: true)
            if FileManager.default.fileExists(atPath: resources.path) {
                return resources
            }
        }
        let siblingAppResources = executable
            .deletingLastPathComponent()
            .appendingPathComponent("Planet.app", isDirectory: true)
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
        if FileManager.default.fileExists(atPath: siblingAppResources.path) {
            return siblingAppResources
        }
        return nil
    }
}
