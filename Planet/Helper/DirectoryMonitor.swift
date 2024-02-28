import Foundation


class DirectoryMonitor {
    private var stream: FSEventStreamRef?
    private let callback: FSEventStreamCallback = { (stream, contextInfo, numEvents, eventPaths, eventFlags, eventIds) in
        let watcher: DirectoryMonitor = unsafeBitCast(contextInfo, to: DirectoryMonitor.self)
        for idx in 0..<Int(numEvents) {
            let path = unsafeBitCast(eventPaths, to: NSArray.self)[idx] as! String
            watcher.processEvent(path: path, eventId: eventIds[idx])
        }
    }
    
    private let directory: String
    private var lastProcessedPath: String?
    private var lastEventId: FSEventStreamEventId = FSEventStreamEventId(kFSEventStreamEventIdSinceNow)
    
    init(directory: String) {
        self.directory = directory
    }
    
    func start() {
        let pathsToWatch: CFArray = [directory] as CFArray
        let latency: CFTimeInterval = 1.0 // Latency in seconds
        
        var context = FSEventStreamContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        context.info = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        // Create the stream
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
        print("Directory \(path) has changed.")
        lastProcessedPath = path
        lastEventId = eventId
    }
}
