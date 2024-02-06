//
//  TemplateMonitor.swift
//  Planet
//

import Foundation


class TemplateMonitor {
    var monitorQueue: DispatchQueue
    var monitoredDirectoryFileDescriptor: CInt = -1
    var directoryMonitorSource: DispatchSource?
    var id: Template.ID
    var templateDidChange: (() -> Void)?

    init(byID id: Template.ID, templateDidChange: (() -> Void)?) {
        self.id = id
        self.monitorQueue = DispatchQueue(label: "planet.template.monitor.\(id.md5())", attributes: .concurrent)
        self.templateDidChange = templateDidChange
    }

    deinit {
        reset()
    }

    func startMonitoring() throws {
        reset()
        let templatesPath = URLUtils.repoPath().appendingPathComponent(
            "Templates",
            isDirectory: true
        )
        let templateInfoPath = templatesPath.appendingPathComponent(id).appendingPathComponent("template.json")
        guard FileManager.default.fileExists(atPath: templateInfoPath.path) else {
            debugPrint("template.json not found: \(templateInfoPath), abort monitoring")
            return
        }
        monitoredDirectoryFileDescriptor = open((templateInfoPath as NSURL).fileSystemRepresentation, O_EVTONLY)
        directoryMonitorSource = DispatchSource.makeFileSystemObjectSource(fileDescriptor: monitoredDirectoryFileDescriptor, eventMask: DispatchSource.FileSystemEvent.write, queue: self.monitorQueue) as? DispatchSource
        directoryMonitorSource?.setEventHandler(handler: eventChangesHandler)
        directoryMonitorSource?.setCancelHandler(handler: eventCancelHandler)
        directoryMonitorSource?.resume()
        debugPrint("start template monitoring for \(id) at url: \(templateInfoPath)")
    }

    private func eventChangesHandler() {
        guard let templateDidChange = templateDidChange else { return }
        templateDidChange()
    }

    private func eventCancelHandler() {
        close(self.monitoredDirectoryFileDescriptor)
        self.monitoredDirectoryFileDescriptor = -1
        self.directoryMonitorSource = nil
    }

    private func reset() {
        if directoryMonitorSource != nil {
            directoryMonitorSource?.cancel()
            directoryMonitorSource = nil
        }
        if monitoredDirectoryFileDescriptor != -1 {
            monitoredDirectoryFileDescriptor = -1
        }
    }
}
