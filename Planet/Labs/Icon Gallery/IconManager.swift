import Foundation
import SwiftUI
import Zip


private struct DockAnimationObject: Decodable {
    let name: String
    let frames: [DockAnimationFrame]
}

// MARK: -

private struct DockAnimationFrame: Decodable, Equatable {
    let name: String
    let duration: Double
    let index: Int
}

// MARK: -

private struct DockIconPreviewView: View {
    let icon: DockIcon
    let size: NSSize
    let previewable: Bool
    
    @State private var animating: Bool = false
    @State private var hovering: Bool = false
    @State private var imageSet: [NSImage] = []
    @State private var imageFrames: [DockAnimationFrame] = []
    @State private var currentImage: Image?

    var body: some View {
        ZStack {
            if imageSet.count > 0 {
                if animating {
                    if let currentImage {
                        currentImage
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: size.width, height: size.height)
                    } else {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .controlSize(.small)
                    }
                } else {
                    Image(nsImage: imageSet.first!)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: size.width, height: size.height)
                    Image(systemName: "play.circle")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(.white)
                        .frame(width: size.width * 0.25)
                        .opacity(hovering ? 0.95 : 0.0)
                }
            } else {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.small)
            }
            if previewable {
                Color(.clear)
                    .contentShape(Rectangle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onTapGesture {
                        playAnimation()
                    }
            }
        }
        .frame(width: size.width, height: size.height)
        .onHover { isHover in
            guard previewable else { return }
            guard imageSet.count > 1 && imageFrames.count > 1 else { return }
            hovering = isHover
        }
        .task(id: icon.hashValue) {
            do {
                let theImageSet = try await IconManager.shared.preparePreviewAnimationImages(withPackageName: icon.packageName, size: size)
                let theImageFrames: [DockAnimationFrame]
                let location = try IconManager.shared.animationLocation(withPackageName: icon.packageName)
                let json = location.appendingPathComponent("animation.json")
                if FileManager.default.fileExists(atPath: json.path) {
                    let decoder = JSONDecoder()
                    let data = try Data(contentsOf: json)
                    let animation = try decoder.decode(DockAnimationObject.self, from: data)
                    theImageFrames = animation.frames
                } else {
                    theImageFrames = []
                }
                await MainActor.run {
                    self.imageSet = theImageSet
                    guard self.previewable else { return }
                    self.imageFrames = theImageFrames
                    self.playAnimation()
                }
            } catch {
                debugPrint("failed to prepare preview animation: \(error)")
            }
        }
    }

    private func playAnimation() {
        guard imageSet.count > 1 && imageFrames.count > 1 && !animating else { return }
        animating = true
        let currentImageSet = imageSet
        let currentImageFrames = imageFrames
        let _ = AsyncStream { (continuation: AsyncStream<DockAnimationFrame>.Continuation) in
            Task(priority: .userInitiated) {
                var index: Int = 0
                for f in currentImageFrames {
                    continuation.yield(f)
                    let image = currentImageSet[index]
                    DispatchQueue.main.async {
                        self.currentImage = Image(nsImage: image)
                    }
                    let duration: Double = f.duration >= 0.3 ? f.duration - 0.1 : f.duration
                    let sleepNanoseconds: UInt64 = UInt64(duration * 1000000000)
                    try? await Task.sleep(nanoseconds: sleepNanoseconds)
                    index += 1
                }
                continuation.finish()
                await MainActor.run {
                    self.animating = false
                }
            }
        }
    }
}

// MARK: -

class IconManager: ObservableObject {
    static let shared = IconManager()

    @Published private(set) var isPlayingAnimation: Bool = false
    @Published private(set) var dockIcons: [DockIcon] = []
    @Published private(set) var activeDockIcon: DockIcon?

    private var cachedPreviewIconImageSet: [String: [NSImage]] = [:]
    private var cachedIconImageSet: [String: [NSImage]] = [:]
    
    init() {
        resetCache()
        dockIcons = [
            DockIcon(id: 0, groupID: 1, name: "NFT Tier 1", groupName: "NFT", packageName: "tier1", unlocked: false),
            DockIcon(id: 10, groupID: 1, name: "NFT Tier 2", groupName: "NFT", packageName: "tier2", unlocked: false),
            DockIcon(id: 20, groupID: 1, name: "NFT Tier 3", groupName: "NFT", packageName: "tier3", unlocked: false),
            DockIcon(id: 30, groupID: 2, name: "Icon Vol.1 1", groupName: "Icon Vol.1", packageName: "vol1-1", unlocked: true),
            DockIcon(id: 40, groupID: 2, name: "Icon Vol.1 2", groupName: "Icon Vol.1", packageName: "vol1-2", unlocked: true),
            DockIcon(id: 50, groupID: 2, name: "Icon Vol.1 3", groupName: "Icon Vol.1", packageName: "vol1-3", unlocked: true),
            DockIcon(id: 60, groupID: 2, name: "Icon Vol.1 4", groupName: "Icon Vol.1", packageName: "vol1-4", unlocked: true),
            DockIcon(id: 70, groupID: 2, name: "Icon Vol.1 5", groupName: "Icon Vol.1", packageName: "vol1-5", unlocked: true),
            DockIcon(id: 80, groupID: 2, name: "Icon Vol.1 6", groupName: "Icon Vol.1", packageName: "vol1-6", unlocked: true),
            DockIcon(id: 90, groupID: 2, name: "Icon Vol.1 7", groupName: "Icon Vol.1", packageName: "vol1-7", unlocked: true),
            DockIcon(id: 100, groupID: 2, name: "Icon Vol.1 8", groupName: "Icon Vol.1", packageName: "vol1-8", unlocked: true)
        ]
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let iconKey = UserDefaults.standard.string(forKey: "PlanetDockIconLastPackageName"), let icon = self.dockIcons.first(where: { $0.packageName == iconKey }) {
                self.setIcon(icon: icon)
            }
        }
    }

    func setIcon(icon: DockIcon) {
        activeDockIcon = icon
        if iconSupportsAnimation(icon: icon) {
            playAnimation(withPackageName: icon.packageName)
        } else {
            setFirstFrame(withPackageName: icon.packageName)
        }
        UserDefaults.standard.set(icon.packageName, forKey: "PlanetDockIconLastPackageName")
        DistributedNotificationCenter.default().post(name: Notification.Name("PlanetDockIconSyncPackageName"), object: icon.packageName)
    }
    
    func resetIcon() {
        NSApp.dockTile.contentView = nil
        NSApp.dockTile.display()
        activeDockIcon = nil
        cachedIconImageSet.removeAll()
        cachedPreviewIconImageSet.removeAll()
        UserDefaults.standard.removeObject(forKey: "PlanetDockIconLastPackageName")
        DistributedNotificationCenter.default().post(name: Notification.Name("PlanetDockIconSyncPackageName"), object: "")
    }

    func iconSupportsAnimation(icon: DockIcon) -> Bool {
        do {
            let location = try animationLocation(withPackageName: icon.packageName)
            let json = location.appendingPathComponent("animation.json")
            return FileManager.default.fileExists(atPath: json.path)
        } catch {}
        return false
    }
    
    func iconIsActive(icon: DockIcon) -> Bool {
        return activeDockIcon == icon
    }
    
    func iconGroupNames() -> [String] {
        let allGroupNames: [String] = dockIcons.map() { icon in
            return icon.groupName
        }
        let groupNames: [String] = Array(Set(allGroupNames)).sorted().reversed()
        return groupNames
    }
    
    func resetCache() {
        try? FileManager.default.removeItem(at: baseCacheURL())
        try? FileManager.default.createDirectory(at: baseCacheURL(), withIntermediateDirectories: true)
    }
    
    func animationLocation(withPackageName name: String) throws -> URL {
        let targetURL = baseCacheURL().appendingPathComponent(name.lowercased())
        if !FileManager.default.fileExists(atPath: targetURL.path) {
            if let zipfile = Bundle.main.url(forResource: name.lowercased(), withExtension: "zip") {
                try Zip.unzipFile(zipfile, destination: targetURL, overwrite: false, password: nil)
            }
        }
        return targetURL
    }
    
    func preparePreviewAnimationImages(withPackageName name: String, size: NSSize) async throws -> [NSImage] {
        let location = try animationLocation(withPackageName: name)
        let json = location.appendingPathComponent("animation.json")
        let key = String(format: "%@-%.d-%.d", name, size.width, size.height)
        let currentCachedIconImageSet = cachedIconImageSet
        let currentCachedPreviewIconImageSet = cachedPreviewIconImageSet
        if !FileManager.default.fileExists(atPath: json.path) {
            if let imageSet = currentCachedPreviewIconImageSet[key] {
                return imageSet
            } else {
                let imagePath: URL = location.appendingPathComponent("a.png")
                if FileManager.default.fileExists(atPath: imagePath.path), let image = NSImage(contentsOfFile: imagePath.path) {
                    let imageSet = [thumbnail(fromImage: image, atSize: size)]
                    Task { @MainActor in
                        self.cachedPreviewIconImageSet[key] = imageSet
                    }
                    return imageSet
                }
            }
        } else {
            let decoder = JSONDecoder()
            let data = try Data(contentsOf: json)
            let animation = try decoder.decode(DockAnimationObject.self, from: data)
            if let imageSet = currentCachedPreviewIconImageSet[key] {
                return imageSet
            } else {
                var imageSet: [NSImage] = []
                let imageSetIsCached: Bool = currentCachedIconImageSet[name] != nil
                for f in animation.frames {
                    let image: NSImage
                    if imageSetIsCached {
                        guard let i = currentCachedIconImageSet[name]?[f.index] else { continue }
                        image = i
                    } else {
                        let imageFile = location.appendingPathComponent(f.name)
                        guard let i = NSImage(contentsOfFile: imageFile.path) else { continue }
                        image = i
                    }
                    imageSet.append(thumbnail(fromImage: image, atSize: size))
                }
                let finalImageSet = imageSet
                Task { @MainActor in
                    self.cachedPreviewIconImageSet[key] = finalImageSet
                }
                return imageSet
            }
        }
        return []
    }
    
    @ViewBuilder
    func iconPreview(icon: DockIcon, size: NSSize = NSSize(width: 96, height: 96), previewable: Bool = true) -> some View {
        DockIconPreviewView(icon: icon, size: size, previewable: previewable)
    }

    // MARK: -
    
    private func baseCacheURL() -> URL {
        let tempURL: URL
        if #available(macOS 13.0, *) {
            tempURL = URL(filePath: NSTemporaryDirectory())
        } else {
            tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
        }
        return tempURL.appendingPathComponent("Icons")
    }
    
    private func thumbnail(fromImage image: NSImage, atSize size: NSSize) -> NSImage {
        let aspectRatio = image.size.width / image.size.height
        let thumbnailSize = NSSize(width: size.width, height: size.width * aspectRatio)
        let outputImage = NSImage(size: thumbnailSize)
        outputImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: thumbnailSize), from: .zero, operation: .sourceOver, fraction: 1.0)
        outputImage.unlockFocus()
        return outputImage
    }

    private func playAnimation(withPackageName name: String) {
        guard isPlayingAnimation == false else { return }
        do {
            let location = try animationLocation(withPackageName: name)
            let json = location.appendingPathComponent("animation.json")
            let decoder = JSONDecoder()
            let data = try Data(contentsOf: json)
            let animation = try decoder.decode(DockAnimationObject.self, from: data)
            isPlayingAnimation = true
            let currentCachedIconImageSet = cachedIconImageSet
            let frames: [DockAnimationFrame] = animation.frames
            let imageSetIsCached: Bool = currentCachedIconImageSet[name] != nil
            let _ = AsyncStream { (continuation: AsyncStream<DockAnimationFrame>.Continuation) in
                Task(priority: .userInitiated) {
                    var imageSet: [NSImage] = []
                    for f in frames {
                        continuation.yield(f)
                        let image: NSImage
                        if imageSetIsCached {
                            guard let i = currentCachedIconImageSet[name]?[f.index] else { continue }
                            image = i
                        } else {
                            let imageFile = location.appendingPathComponent(f.name)
                            guard let i = NSImage(contentsOfFile: imageFile.path) else { continue }
                            image = i
                            imageSet.append(image)
                        }
                        DispatchQueue.main.async {
                            NSApp.applicationIconImage = image
                        }
                        let duration: Double = f.duration >= 0.3 ? f.duration - 0.1 : f.duration
                        let sleepNanoseconds: UInt64 = UInt64(duration * 1000000000)
                        try? await Task.sleep(nanoseconds: sleepNanoseconds)
                    }
                    continuation.finish()
                    await MainActor.run {
                        self.isPlayingAnimation = false
                    }
                    if !imageSetIsCached && imageSet.count > 0 {
                        let finalImageSet = imageSet
                        Task { @MainActor in
                            self.cachedIconImageSet[name] = finalImageSet
                        }
                    }
                    imageSet.removeAll()
                }
            }
        } catch {
            isPlayingAnimation = false
        }
    }
    
    private func setFirstFrame(withPackageName name: String) {
        do {
            let location = try animationLocation(withPackageName: name)
            let imagePath = location.appendingPathComponent("a.png")
            if let image = NSImage(contentsOfFile: imagePath.path) {
                DispatchQueue.main.async {
                    NSApp.applicationIconImage = image
                }
            }
        } catch {
            debugPrint("failed to set first frame for package: \(name), error: \(error)")
        }
    }
}
