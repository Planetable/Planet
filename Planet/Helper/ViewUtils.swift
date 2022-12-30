import SwiftUI

extension NSTextField {
    // remove focus glow (blue ring) from text field
    // Reference: https://developer.apple.com/forums/thread/124617
    open override var focusRingType: NSFocusRingType {
        get { .none }
        set { }
    }
}

extension NSImage {
    func getLargestCenterSquare() -> NSRect {
        let width = size.width
        let height = size.height
        let min = min(width, height)
        let x = (width - min) / 2
        let y = (height - min) / 2
        return NSRect(x: x, y: y, width: min, height: min)
    }

    // Resize image reference: https://stackoverflow.com/a/42915296/12861158
    // Crop the largest center square of the image, and shrink if it is bigger than the given size
    // Example when resize with max length of 160:
    // 300x200 -> center square: (50, 0) to (250, 200) -> resize to 160x160
    // 100x120 -> center square: (0, 10) to (100, 110) -> no resize, 100x100
    // TODO: SwiftUI Image has `resizable` and `aspectRatio` modifier, check if these options can resize image for us
    func resizeSquare(maxLength: Int) -> NSImage? {
        let sourceRect = getLargestCenterSquare()
        let resizeLength = min(maxLength, Int(sourceRect.width))
        let resizeSize = NSSize(width: resizeLength, height: resizeLength)
        let targetRect = NSRect(x: 0, y: 0, width: resizeLength, height: resizeLength)

        if let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: resizeLength,
            pixelsHigh: resizeLength,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) {
            bitmapRep.size = resizeSize
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
            draw(in: targetRect, from: sourceRect, operation: .copy, fraction: 1.0)
            NSGraphicsContext.restoreGraphicsState()
            let resizedImage = NSImage(size: resizeSize)
            resizedImage.addRepresentation(bitmapRep)
            return resizedImage
        }
        return nil
    }

    var PNGData: Data? {
        if let tiff = tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff),
           let png = bitmap.representation(using: .png, properties: [:]) {
            return png
        }
        return nil
    }

    var JPEGData: Data? {
        if let tiff = tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff),
           let jpeg = bitmap.representation(using: .jpeg, properties: [:]) {
            return jpeg
        }
        return nil
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 08) & 0xFF) / 255,
            blue: Double((hex >> 00) & 0xFF) / 255,
            opacity: alpha
        )
    }
}

enum ViewVisibility: CaseIterable {
    case visible    // view is fully visible
    case invisible  // view is hidden but takes up space
    case gone       // view is fully removed from the view hierarchy
}

extension View {
    @ViewBuilder func visibility(_ visibility: ViewVisibility) -> some View {
        if visibility != .gone {
            if visibility == .visible {
                self
            } else {
                hidden()
            }
        }
    }
}

struct ViewUtils {
    static let presetGradients = [
        Gradient(colors: [Color(hex: 0x88D3FA), Color(hex: 0x4C9FED)]), // Sky Blue
        Gradient(colors: [Color(hex: 0xFACE76), Color(hex: 0xF5AD67)]), // Orange
        Gradient(colors: [Color(hex: 0xD8A9F0), Color(hex: 0xCA77E9)]), // Pink
        Gradient(colors: [Color(hex: 0xF39066), Color(hex: 0xF0636E)]), // Red
        Gradient(colors: [Color(hex: 0xACDB86), Color(hex: 0x74C771)]), // Green
        Gradient(colors: [Color(hex: 0x8AB2FB), Color(hex: 0x6469FA)]), // Violet
        Gradient(colors: [Color(hex: 0x7FE9D7), Color(hex: 0x5DC6B8)]), // Cyan
    ]

    static let emojiList: [String] = [
        "🐶",
        "🐱",
        "🐭",
        "🐹",
        "🐰",
        "🦊",
        "🐻",
        "🐼",
        "🐨",
        "🐯",
        "🦁",
        "🐮",
        "🐷",
        "🐸",
        "🐵",
        "🙈",
        "🙉",
        "🙊",
        "🐒",
        "🐔",
        "🐧",
        "🐦",
        "🐤",
        "🐣",
        "🐥",
        "🦆",
        "🦅",
        "🦉",
        "🦇",
        "🐺",
        "🐗",
        "🐴",
        "🦄",
        "🐝",
        "🐛",
        "🦋",
        "🐌",
        "🐞",
        "🐜",
        "🕷",
        "🕸",
        "🦂",
        "🐢",
        "🐍",
        "🦎",
        "🦖",
        "🦕",
        "🐙",
        "🦑",
        "🦐",
        "🦞",
        "🦀",
        "🐡",
        "🐠",
        "🐟",
        "🐬",
        "🐳",
        "🐋",
        "🦈",
        "🦭",
        "🐊",
        "🐅",
        "🐆",
        "🦓",
        "🦍",
        "🦧",
        "🦣",
        "🐘",
        "🦛",
        "🦏",
        "🐪",
        "🐫",
        "🦒",
        "🦘"
    ]

    static func getPresetGradient(from uuid: UUID) -> Gradient {
        let leastSignificantUInt8 = uuid.uuid.15
        let index = Int(leastSignificantUInt8) % presetGradients.count
        return presetGradients[index]
    }

    static func getPresetGradient(from walletAddress: String) -> Gradient {
        let characters: [UInt8] = Array(walletAddress.utf8)
        let lastCharUInt8 = characters.last!
        let index = Int(lastCharUInt8) % presetGradients.count
        return presetGradients[index]
    }

    static func getEmoji(from walletAddress: String) -> String {
        let characters: [UInt8] = Array(walletAddress.utf8)
        let lastCharUInt8 = characters.last!
        let index = Int(lastCharUInt8) % emojiList.count
        return emojiList[index]
    }
}
