//
//  PlanetPublishedServiceStore.swift
//  Planet
//
//  Created by Kai on 10/3/22.
//

import Foundation
import SwiftUI


class PlanetPublishedServiceStore: ObservableObject {
    static let shared = PlanetPublishedServiceStore()

    static let prefixKey: String = .folderPrefixKey
    static let removedListKey: String = .folderRemovedListKey
    static let pendingPrefixKey: String = .folderPendingPrefixKey

    static let ttlString: String = "7200h"
    static let ttl: Int = 3600*7200 - 60

    let timer = Timer.publish(every: 5, tolerance: 0.1, on: .current, in: RunLoop.Mode.default).autoconnect()

    @Published var timestamp: Int = Int(Date().timeIntervalSince1970)
    @Published var autoPublish: Bool = UserDefaults.standard.bool(forKey: String.folderAutoPublishOptionKey) {
        didSet {
            UserDefaults.standard.set(autoPublish, forKey: String.folderAutoPublishOptionKey)
            updateMonitoring()
        }
    }
    @Published var selectedFolderID: UUID? {
        willSet(newValue) {
            Task { @MainActor in
                self.restoreSelectedFolderNavigation()
            }
        }
        didSet {
            if let id = selectedFolderID {
                UserDefaults.standard.set(id.uuidString, forKey: String.selectedPublishedFolderID)
            } else {
                UserDefaults.standard.removeObject(forKey: String.selectedPublishedFolderID)
            }
            NotificationCenter.default.post(name: .dashboardRefreshToolbar, object: nil)
        }
    }
    
    @Published private(set) var selectedFolderIDChanged: Bool = false
    @Published private(set) var selectedFolderCanGoForward: Bool = false
    @Published private(set) var selectedFolderCanGoBackward: Bool = false
    @Published private(set) var selectedFolderBackwardURL: URL?
    @Published private(set) var selectedFolderForwardURL: URL?
    @Published private(set) var selectedFolderCurrentURL: URL?
    
    @Published private(set) var publishedFolders: [PlanetPublishedFolder] = [] {
        didSet {
            updateMonitoring()
        }
    }
    @Published private(set) var publishingFolders: [UUID] = []

    private var monitors: [PlanetPublishedServiceMonitor] = []
    
    private var cachedDirectoryResults: [URL: Bool] = [:]

    init() {
        do {
            publishedFolders = try loadPublishedFolders()
            if let value = UserDefaults.standard.object(forKey: String.selectedPublishedFolderID) as? String {
                selectedFolderID = UUID(uuidString: value)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                Task(priority: .background) {
                    let removedIDs: [String] = UserDefaults.standard.stringArray(forKey: Self.removedListKey) ?? []
                    for id in removedIDs {
                        do {
                            try await self.unpublishFolder(keyName: id)
                        } catch {
                            debugPrint("failed to unpublish folder with key id: \(id), error: \(error)")
                        }
                    }
                }
            }
        } catch {
            debugPrint("failed to load published folders: \(error)")
        }
    }
    
    func restoreSelectedFolderNavigation() {
        if let id = selectedFolderID, let folder = publishedFolders.first(where: { $0.id == id }), let _ = folder.published, let publishedLink = folder.publishedLink, let url = URL(string: "\(IPFSDaemon.shared.gateway)/ipns/\(publishedLink)") {
            NotificationCenter.default.post(name: .dashboardResetWebViewHistory, object: id)
            selectedFolderIDChanged = true
            NotificationCenter.default.post(name: .dashboardLoadPreviewURL, object: url)
        }
    }
    
    @MainActor
    func updateSelectedFolderNavigation(withCurrentURL currentURL: URL, canGoForward: Bool, forwardURL: URL?, canGoBackward: Bool, backwardURL: URL?) {
        guard let _ = selectedFolderID else { return }
        defer {
            NotificationCenter.default.post(name: .dashboardRefreshToolbar, object: nil)
        }
        guard selectedFolderIDChanged == false else {
            // reset web view backward history when switching between selected folders, leave current url unchanged.
            selectedFolderIDChanged = false
            selectedFolderCanGoForward = false
            selectedFolderForwardURL = nil
            selectedFolderCanGoBackward = false
            selectedFolderBackwardURL = nil
            return
        }

        selectedFolderCurrentURL = currentURL
        selectedFolderCanGoForward = canGoForward
        selectedFolderForwardURL = canGoForward ? forwardURL : nil
        selectedFolderCanGoBackward = canGoBackward
        selectedFolderBackwardURL = canGoBackward ? backwardURL : nil
        
        if currentURL == backwardURL {
            selectedFolderCanGoBackward = false
            selectedFolderBackwardURL = nil
        }
        if currentURL == forwardURL {
            selectedFolderCanGoForward = false
            selectedFolderForwardURL = nil
        }
        if selectedFolderCanGoBackward && selectedFolderBackwardURL?.lastPathComponent == "NoSelection.html" {
            selectedFolderCanGoBackward = false
            selectedFolderBackwardURL = nil
        }
    }

    func addToRemovingPublishedFolderQueue(_ folder: PlanetPublishedFolder) {
        // remove selected index if equals
        if selectedFolderID == folder.id {
            selectedFolderID = nil
        }
        // remove bookmark data
        removeBookmarkData(forFolder: folder)
        // remove monitor if exists
        monitors = monitors.filter { m in
            if m.url == folder.url {
                m.reset()
            }
            return m.url != folder.url
        }
        let isPublished: Bool = folder.publishedLink != nil && folder.published != nil
        if !isPublished {
            return
        }
        Task(priority: .background) {
            do {
                try await unpublishFolder(keyName: folder.id.uuidString)
            } catch {
                debugPrint("failed to unpublish folder: \(folder), error: \(error)")
            }
        }
    }

    func requestToPublishFolder(withURL url: URL) {
        Task { @MainActor in
            guard let folder = publishedFolders.first(where: { $0.url == url }) else { return }
            let key = Self.pendingPrefixKey + folder.id.uuidString
            let value = Int(Date().timeIntervalSince1970)
            UserDefaults.standard.set(value, forKey: key)
            debugPrint("content changed at: \(url), scheduled a pending publishing: \(key) at \(value)")
        }
    }

    func updatePendingPublishings() {
        guard autoPublish && publishedFolders.count > 0 else { return }
        let now: Int = Int(Date().timeIntervalSince1970)
        let next: Int = now + 86400
        Task { @MainActor in
            for folder in self.publishedFolders {
                let key = Self.pendingPrefixKey + folder.id.uuidString
                let value = UserDefaults.standard.integer(forKey: key)
                let published = Int(folder.published?.timeIntervalSince1970 ?? 0)
                if value <= published && published > 0 {
                    if now - published < Self.ttl {
                        continue
                    } else {
                        debugPrint("folder IPNS ttl expired, schedule a publishing...")
                    }
                }
                if self.publishingFolders.contains(folder.id) {
                    UserDefaults.standard.set(next, forKey: key)
                    continue
                }
                debugPrint("folder (\(folder.url)) is the first time to publish or has changes to publish...")
                do {
                    try await publishFolder(folder)
                } catch PlanetError.PublishedServiceFolderUnchangedError {
                    UserDefaults.standard.removeObject(forKey: key)
                    debugPrint("folder \(folder.url) unchanged, abort auto publishing.")
                } catch {
                    debugPrint("failed to auto publish folder \(folder.url), error: \(error)")
                }
            }
        }
    }

    @MainActor
    func publishFolder(_ folder: PlanetPublishedFolder, skipCIDCheck: Bool = false) async throws {
        addPublishingFolder(folder)
        defer {
            removePublishingFolder(folder)
        }
        let keyName = folder.id.uuidString
        if try await !IPFSDaemon.shared.checkKeyExists(name: keyName) {
            let _ = try await IPFSDaemon.shared.generateKey(name: keyName)
        }
        let url = try restoreFolderAccess(forFolder: folder)
        guard url.startAccessingSecurityScopedResource() else {
            throw PlanetError.PublishedServiceFolderPermissionError
        }
        let cid = try await IPFSDaemon.shared.addDirectory(url: url)
        url.stopAccessingSecurityScopedResource()
        var versions = try loadPublishedVersions(byFolderKeyName: keyName)
        if skipCIDCheck == false, let lastVersion = versions.last, lastVersion.cid == cid {
            throw PlanetError.PublishedServiceFolderUnchangedError
        }
        versions.append(PlanetPublishedFolderVersion(id: folder.id, cid: cid, created: Date()))
        try savePublishedVersions(versions)
        let result = try await IPFSDaemon.shared.api(
            path: "name/publish",
            args: [
                "arg": cid,
                "allow-offline": "1",
                "key": keyName,
                "quieter": "1",
                "lifetime": Self.ttlString,
            ],
            timeout: 300
        )
        let decoder = JSONDecoder()
        let publishedStatus = try decoder.decode(IPFSPublished.self, from: result)
        let updatedFolder = PlanetPublishedFolder(id: folder.id, url: folder.url, created: folder.created, published: Date(), publishedLink: publishedStatus.name)
        let updatedFolders = publishedFolders.map() { f in
            if f.id == folder.id {
                return updatedFolder
            } else {
                return f
            }
        }
        updatePublishedFolders(updatedFolders)
        NotificationCenter.default.post(name: .dashboardRefreshToolbar, object: nil)
        debugPrint("Folder published -> \(folder.url)")
    }

    @MainActor
    func updatePublishedFolders(_ folders: [PlanetPublishedFolder]) {
        publishedFolders = folders.sorted(by: { a, b in
            return a.created > b.created
        })
        Task(priority: .background) {
            do {
                try savePublishedFolders()
            } catch {
                debugPrint("failed to save published folders: \(error)")
            }
        }
    }

    @MainActor
    func addPublishingFolder(_ folder: PlanetPublishedFolder) {
        guard !publishingFolders.contains(folder.id) else { return }
        publishingFolders.append(folder.id)
    }

    private func removePublishingFolder(_ folder: PlanetPublishedFolder) {
        guard publishingFolders.contains(folder.id) else { return }
        guard let _ = publishingFolders.removeFirst(item: folder.id) else { return }
    }

    private func unpublishFolder(keyName: String) async throws {
        debugPrint("Removing published folder with key id: \(keyName) ...")
        // 1. save removed id list in case unpublishing process was interupt
        var removedIDs: [String] = UserDefaults.standard.stringArray(forKey: Self.removedListKey) ?? []
        if !removedIDs.contains(keyName) {
            removedIDs.append(keyName)
            UserDefaults.standard.set(removedIDs, forKey: Self.removedListKey)
        }

        // 2. unpin available cids
        for version in try loadPublishedVersions(byFolderKeyName: keyName) {
            try? await IPFSDaemon.shared.unpin(cid: version.cid)
        }

        // 3. publish the empty folder
        let emptyFolderURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(keyName)
        if FileManager.default.fileExists(atPath: emptyFolderURL.path) {
            try? FileManager.default.removeItem(at: emptyFolderURL)
        }
        try? FileManager.default.createDirectory(at: emptyFolderURL, withIntermediateDirectories: true)
        guard FileManager.default.fileExists(atPath: emptyFolderURL.path) else { return }

        let updatedRemovedIDs = removedIDs
        let keyExists = try await IPFSDaemon.shared.checkKeyExists(name: keyName)
        guard keyExists else { throw PlanetError.InternalError }
        let cid = try await IPFSDaemon.shared.addDirectory(url: emptyFolderURL)
        let result = try await IPFSDaemon.shared.api(
            path: "name/publish",
            args: [
                "arg": cid,
                "allow-offline": "1",
                "key": keyName,
                "quieter": "1",
                "lifetime": "24h",
            ],
            timeout: 300
        )
        let decoder = JSONDecoder()
        let publishedStatus = try decoder.decode(IPFSPublished.self, from: result)

        // 4. update removal list if unpublished
        if publishedStatus.name != "" {
            try await IPFSDaemon.shared.removeKey(name: keyName)
            UserDefaults.standard.set(updatedRemovedIDs.filter({ id in
                return id != keyName
            }), forKey: Self.removedListKey)
            removePublishedVersions(byFolderKeyName: keyName)
            debugPrint("Folder with key id \(keyName) is unpublished and removed -> \(publishedStatus)")
        }
    }

    private func updateMonitoring() {
        if autoPublish {
            for folder in publishedFolders {
                if let _ = monitors.first(where: { $0.url == folder.url }) { continue }
                let monitor = PlanetPublishedServiceMonitor(url: folder.url, folderID: folder.id)
                do {
                    try monitor.startMonitoring()
                } catch {
                    debugPrint("failed to start monitoring at: \(folder.url), error: \(error)")
                    monitor.reset()
                    continue
                }
                monitors.append(monitor)
            }
        } else {
            for monitor in monitors {
                monitor.reset()
            }
        }
    }
}


extension PlanetPublishedServiceStore {
    private var folderHistoryURL: URL {
        return URLUtils.publishedFolderHistoryPath.appendingPathComponent("history.json")
    }

    private var folderVersionURL: URL {
        let url = URLUtils.publishedFolderHistoryPath.appendingPathComponent("versions", conformingTo: .directory)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    func loadPublishedFolders() throws -> [PlanetPublishedFolder] {
        let decoder = JSONDecoder()
        if !FileManager.default.fileExists(atPath: folderHistoryURL.path) {
            return []
        }
        let data = try Data(contentsOf: folderHistoryURL)
        let folders: [PlanetPublishedFolder] = try decoder.decode([PlanetPublishedFolder].self, from: data)
        return folders
    }

    func savePublishedFolders() throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(self.publishedFolders)
        try data.write(to: folderHistoryURL)
    }

    func loadPublishedVersions(byFolderKeyName name: String) throws -> [PlanetPublishedFolderVersion] {
        let decoder = JSONDecoder()
        let versionsURL = folderVersionURL.appendingPathComponent(name)
        if !FileManager.default.fileExists(atPath: versionsURL.path) {
            return []
        }
        let data = try Data(contentsOf: versionsURL)
        let versions: [PlanetPublishedFolderVersion] = try decoder.decode([PlanetPublishedFolderVersion].self, from: data)
        return versions
    }

    func savePublishedVersions(_ versions: [PlanetPublishedFolderVersion]) throws {
        let encoder = JSONEncoder()
        guard let name = versions.first?.id.uuidString else { throw PlanetError.InternalError }
        let versionsURL = folderVersionURL.appendingPathComponent(name)
        let data = try encoder.encode(versions)
        try data.write(to: versionsURL)
    }

    func removePublishedVersions(byFolderKeyName name: String) {
        let versionsURL = folderVersionURL.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: versionsURL)
    }

    // MARK: -
    // https://developer.apple.com/documentation/uikit/view_controllers/providing_access_to_directories
    // https://benscheirman.com/2019/10/troubleshooting-appkit-file-permissions/
    //
    func restoreFolderAccess(forFolder folder: PlanetPublishedFolder) throws -> URL {
        let bookmarkKey = Self.prefixKey + folder.id.uuidString
        guard let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey) else { throw PlanetError.InternalError }
        var isStale = false
        let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
        if isStale {
            try saveBookmarkData(forFolder: folder)
        }
        return url
    }

    func saveBookmarkData(forFolder folder: PlanetPublishedFolder) throws {
        let bookmarkData = try folder.url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        let bookmarkKey = Self.prefixKey + folder.id.uuidString
        UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
    }

    func removeBookmarkData(forFolder folder: PlanetPublishedFolder) {
        UserDefaults.standard.removeObject(forKey: Self.prefixKey + folder.id.uuidString)
    }
    
    func revealFolderInFinder(_ folder: PlanetPublishedFolder) {
        do {
            let url = try self.restoreFolderAccess(forFolder: folder)
            guard url.startAccessingSecurityScopedResource() else {
                throw PlanetError.PublishedServiceFolderPermissionError
            }
            NSWorkspace.shared.open(url)
            url.stopAccessingSecurityScopedResource()
        } catch {
            debugPrint("failed to request access to folder: \(folder), error: \(error)")
            let alert = NSAlert()
            alert.messageText = "Failed to Access to Folder"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    func folderDirectoryContentHasHTMLContent(_ url: URL) async -> Bool {
        if url.hasDirectoryPath {
            if let _ = url.scheme, let host = url.host, let port = url.port {
                if (host == "127.0.0.1" || host == "localhost") && UInt16(port) == IPFSDaemon.shared.gatewayPort {
                    let indexPage = url.appendingPathComponent("index.html")
                    do {
                        let request = URLRequest(url: indexPage, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 0.01)
                        let (_, response) = try await URLSession.shared.data(for: request)
                        if let httpResponse = response as? HTTPURLResponse {
                            let result = httpResponse.statusCode == 200
                            return result
                        }
                    } catch {}
                }
            }
        }
        return false
    }
    
    func addFolder() {
        let panel = NSOpenPanel()
        panel.message = "Choose Folder to Publish"
        panel.prompt = "Choose"
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.folder]
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return }
        var folders = self.publishedFolders
        var exists = false
        for f in folders {
            if f.url.absoluteString.md5() == url.absoluteString.md5() {
                exists = true
                break
            }
        }
        if exists {
            let alert = NSAlert()
            alert.messageText = "Failed to Add Folder"
            alert.informativeText = "Selected folder has already been added."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        let folder = PlanetPublishedFolder(id: UUID(), url: url, created: Date())
        do {
            try self.saveBookmarkData(forFolder: folder)
            folders.insert(folder, at: 0)
            let updatedFolders = folders
            Task { @MainActor in
                self.updatePublishedFolders(updatedFolders)
            }
        } catch {
            debugPrint("failed to add folder: \(error)")
            let alert = NSAlert()
            alert.messageText = "Failed to Add Folder"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    func exportFolderKey(_ folder: PlanetPublishedFolder) {
        guard let _ = folder.published else {
            let alert = NSAlert()
            alert.messageText = "Failed to Export Folder Key"
            alert.informativeText = "Folder key doesn't exist, please make sure this folder has been successfully published."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        let panel = NSOpenPanel()
        panel.message = "Choose Directory to Save Folder Key"
        panel.prompt = "Choose"
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.folder]
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return }
        let folderName = folder.url.lastPathComponent.sanitized()
        let keyPath = url.appendingPathComponent(folderName + ".key")
        do {
            try IPFSCommand.exportKey(name: folder.id.uuidString, target: keyPath).run()
            NSWorkspace.shared.activateFileViewerSelecting([keyPath])
        } catch {
            let alert = NSAlert()
            alert.messageText = "Failed to Export Folder Key"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    func importAndReplaceFolderKey(_ folder: PlanetPublishedFolder, keyPath: URL) {}
}


private class PlanetPublishedServiceMonitor {
    var monitorQueue: DispatchQueue
    var monitoredDirectoryFileDescriptor: CInt = -1
    var directoryMonitorSource: DispatchSource?
    var url: URL
    var folderID: UUID

    init(url: URL, folderID: UUID) {
        self.url = url
        self.folderID = folderID
        self.monitorQueue = DispatchQueue(label: "planet.monitor.\(url.absoluteString.md5())", attributes: .concurrent)
    }

    deinit {
        reset()
    }

    func reset() {
        if directoryMonitorSource != nil {
            directoryMonitorSource?.cancel()
            directoryMonitorSource = nil
        }
        if monitoredDirectoryFileDescriptor != -1 {
            monitoredDirectoryFileDescriptor = -1
        }
    }

    func startMonitoring() throws {
        reset()
        let bookmarkKey = PlanetPublishedServiceStore.prefixKey + folderID.uuidString
        guard let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey) else {
            throw PlanetError.InternalError
        }
        var isStale = false
        let targetURL = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
        url = targetURL
        guard url.startAccessingSecurityScopedResource() else {
            throw PlanetError.PublishedServiceFolderPermissionError
        }
        monitoredDirectoryFileDescriptor = open((url as NSURL).fileSystemRepresentation, O_EVTONLY)
        directoryMonitorSource = DispatchSource.makeFileSystemObjectSource(fileDescriptor: monitoredDirectoryFileDescriptor, eventMask: DispatchSource.FileSystemEvent.write, queue: self.monitorQueue) as? DispatchSource
        directoryMonitorSource?.setEventHandler{
            PlanetPublishedServiceStore.shared.requestToPublishFolder(withURL: self.url)
        }
        directoryMonitorSource?.setCancelHandler{
            close(self.monitoredDirectoryFileDescriptor)
            self.monitoredDirectoryFileDescriptor = -1
            self.directoryMonitorSource = nil
            self.url.stopAccessingSecurityScopedResource()
        }
        directoryMonitorSource?.resume()
    }
}
