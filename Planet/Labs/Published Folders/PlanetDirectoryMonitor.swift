import Foundation


class PlanetDirectoryMonitor {
    private var stream: FSEventStreamRef?
    private let callback: FSEventStreamCallback = { (stream, contextInfo, numEvents, eventPaths, eventFlags, eventIds) in
        let watcher: PlanetDirectoryMonitor = unsafeBitCast(contextInfo, to: PlanetDirectoryMonitor.self)
        for idx in 0..<Int(numEvents) {
            let path = unsafeBitCast(eventPaths, to: NSArray.self)[idx] as! String
            watcher.processEvent(path: path, eventId: eventIds[idx])
        }
    }
    
    private let directory: String
    private var directoryDidChange: (() -> Void)?
    private var lastProcessedPath: String?
    private var lastEventId: FSEventStreamEventId = FSEventStreamEventId(kFSEventStreamEventIdSinceNow)
    
    init(directory: String, changed: (() -> Void)?) {
        self.directory = directory
        self.directoryDidChange = changed
    }
    
    func start() {
        let pathsToWatch: CFArray = [directory] as CFArray
        let latency: CFTimeInterval = 1.0
        var context = FSEventStreamContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        context.info = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            pathsToWatch,
            lastEventId,
            latency,
            UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        )
        FSEventStreamScheduleWithRunLoop(stream!, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        FSEventStreamStart(stream!)
    }
    
    func stop() {
        if let stream = stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }
    }
    
    private func processEvent(path: String, eventId: FSEventStreamEventId) {
        if path == lastProcessedPath {
            return
        }
        if let directoryDidChange {
            directoryDidChange()
        }
        lastProcessedPath = path
        lastEventId = eventId
    }
}
