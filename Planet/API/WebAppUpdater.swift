//
//  WebAppUpdater.swift
//  Planet
//
//  Created by Xin Liu on 12/23/24.
//

import Foundation

class WebAppUpdater {
    static let shared = WebAppUpdater()

    static let webAppPath: String = {
        if #available(macOS 13.0, *) {
            return URLUtils.repoPath().appendingPathComponent("Public", conformingTo: .folder)
                .appendingPathComponent("app", conformingTo: .folder).path()
        }
        else {
            return URLUtils.repoPath().appendingPathComponent("Public", conformingTo: .folder)
                .appendingPathComponent("app", conformingTo: .folder).path
        }
    }()

    func updateWebApp() {
        debugPrint("Web App updater: about to check for updates")

        // If there .git in current web app folder then skip the update
        if FileManager.default.fileExists(atPath: "\(WebAppUpdater.webAppPath)/.git") {
            debugPrint("Web App updater: skip update because the current web app has a git repo")
            return
        }

        // Check the latest release at https://github.com/livid/planet-web
        // Download the zip file and unzip it to a temporary folder
        // Read its info.json if found, if not found just simply return
        // Compare the version with the current version
        // If the version is newer, move the files to the web app folder
        // If the version is the same, just simply return
        let url = URL(string: "https://api.github.com/repos/livid/planet-web/releases/latest")!
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                debugPrint("Web App updater: failed to fetch latest release info")
                return
            }

            debugPrint("Web App updater: latest release info fetched \(data.count) bytes")

            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: [])
                    as? [String: Any],
                    let assets = json["assets"] as? [[String: Any]],
                    let zipAsset = assets.first(where: {
                        ($0["name"] as? String)?.hasSuffix(".zip") == true
                    }),
                    let zipUrlString = zipAsset["browser_download_url"] as? String,
                    let zipUrl = URL(string: zipUrlString)
                {
                    debugPrint("Web App updater: latest release zip url: \(zipUrl)")

                    let zipData = try Data(contentsOf: zipUrl)
                    let tempDir = FileManager.default.temporaryDirectory
                    let tempZipUrl = tempDir.appendingPathComponent("latest_web_app.zip")
                    if FileManager.default.fileExists(atPath: tempZipUrl.path) {
                        try FileManager.default.removeItem(at: tempZipUrl)
                    }
                    try zipData.write(to: tempZipUrl)

                    let unzipDir = tempDir.appendingPathComponent("latest_web_app")
                    if FileManager.default.fileExists(atPath: unzipDir.path) {
                        try FileManager.default.removeItem(at: unzipDir)
                    }
                    try FileManager.default.createDirectory(
                        at: unzipDir,
                        withIntermediateDirectories: true,
                        attributes: nil
                    )

                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
                    process.arguments = [tempZipUrl.path, "-d", unzipDir.path]
                    try process.run()
                    process.waitUntilExit()

                    debugPrint("Web App updater: latest release unzipped to \(unzipDir.path)")

                    let infoJsonUrl = unzipDir.appendingPathComponent("info.json")
                    guard let infoData = try? Data(contentsOf: infoJsonUrl),
                          let infoJson = try JSONSerialization.jsonObject(with: infoData, options: [])
                            as? [String: Any],
                          let newVersion = infoJson["version"] as? String
                    else {
                        debugPrint("Web App updater: info.json not found or invalid")
                        return
                    }
                    debugPrint("Web App updater: new version found: \(newVersion)")

                    let currentVersion: String
                    let currentInfoJsonUrl = URL(fileURLWithPath: "\(WebAppUpdater.webAppPath)/info.json")
                    if let currentInfoData = try? Data(contentsOf: currentInfoJsonUrl),
                       let currentInfoJson = try JSONSerialization.jsonObject(with: currentInfoData, options: [])
                        as? [String: Any] {
                        currentVersion = currentInfoJson["version"] as? String ?? "0"
                    }
                    else {
                        debugPrint("Web App updater: current info.json not found or invalid")
                        currentVersion = "0"
                    }

                    // Convert version strings to integers for comparison
                    let newVersionInt = Int(newVersion) ?? 0
                    let currentVersionInt = Int(currentVersion) ?? 0

                    // If the new version is newer than the current version
                    // remove current web app and move the unzipped folder as the new web app
                    if newVersionInt > currentVersionInt {
                        if FileManager.default.fileExists(atPath: WebAppUpdater.webAppPath) {
                            try FileManager.default.removeItem(atPath: WebAppUpdater.webAppPath)
                        }
                        try FileManager.default.moveItem(at: unzipDir, to: URL(fileURLWithPath: WebAppUpdater.webAppPath))
                        debugPrint("Web App updater: updated to version \(newVersion)")
                    }
                    else {
                        debugPrint("Web App updater: no update needed")
                    }
                } else {
                    debugPrint("Web App updater: failed to parse release info")
                }
            }
            catch {
                print("Web App updater: error during update: \(error)")
            }
        }
        task.resume()
    }
}
