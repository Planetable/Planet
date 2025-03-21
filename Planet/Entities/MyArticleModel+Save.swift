//
//  MyArticleModel+Save.swift
//  Planet
//
//  Created by Xin Liu on 7/2/23.
//

import AVKit
import Foundation
import SwiftUI
import OrderedCollections

extension MyArticleModel {
    // MARK: -  Save to My/:planet_id/Articles/:article_id.json

    /// Persist any changes to the model.
    func save() throws {
        try JSONEncoder.shared.encode(self).write(to: path)
    }

    /// Delete the metadata and any in the public folder
    func delete() {
        if let slug = self.slug, slug.count > 0 {
            self.removeSlug(slug)
        }
        Task { @MainActor in
            self.planet.articles.removeAll { $0.id == self.id }
        }
        try? FileManager.default.removeItem(at: path)
        try? FileManager.default.removeItem(at: publicBasePath)
    }

    /// Remove the slug copy
    func removeSlug(_ slugToRemove: String) {
        let slug = slugToRemove.trim()
        if slugToRemove.count == 0 || slug.count == 0 {
            return
        }
        let slugPath = planet.publicBasePath.appendingPathComponent(
            slugToRemove,
            isDirectory: true
        )
        if FileManager.default.fileExists(atPath: slugPath.path) {
            try? FileManager.default.removeItem(at: slugPath)
        }
    }

    // MARK: - Save to Public/:planet_id/:article_id/index.html

    /// Save the article into UUID/index.html along with its attachments.
    func savePublic(usingTasks: Bool = false) throws {
        let started: Date = Date()
        var marks: OrderedDictionary<String, Date> = ["Started": started]

        removeDSStore()

        if !FileManager.default.fileExists(atPath: publicBasePath.path) {
            try FileManager.default.createDirectory(at: publicBasePath, withIntermediateDirectories: true)
        }

        saveMarkdownInBackground()

        try processContent()
        marks.recordEvent("ContentRendered", for: self.title)

        // MARK: - Cover Image `_cover.png`

        try saveCoverImage()
        savePreviewImageFromPDF()
        marks.recordEvent("SaveCoverImage", for: self.title)

        let coverImageCID: String? = getCoverImageCIDIfNeeded()
        marks.recordEvent("CoverImageCID", for: self.title)

        processAttachmentCIDIfNeeded()
        marks.recordEvent("AttachmentCID", for: self.title)

        // MARK: - Video

        processVideoThumbnail()
        marks.recordEvent("VideoThumbnail", for: self.title)

        // MARK: - NFT

        try processNFTMetadata(with: coverImageCID)
        marks.recordEvent("NFTMetadata", for: self.title)

        // MARK: - Render Markdown

        try processArticleHTML(usingTasks: usingTasks)
        marks.recordEvent("ArticleHTML", for: self.title)

        // MARK: - Hero Grid
        processHeroGrid()
        marks.recordEvent("HeroGrid", for: self.title)

        // MARK: - Hero Image Size
        processHeroImageSize()
        marks.recordEvent("HeroImageSize", for: self.title)

        try JSONEncoder.shared.encode(publicArticle).write(to: publicInfoPath)

        // MARK: - Slug copy
        processSlug()
        marks.recordEvent("ArticleSlug", for: self.title)

        // MARK: - Send notification when done
        Task { @MainActor in
            debugPrint("Sending notification: myArticleBuilt \(self.id) \(self.title)")
            NotificationCenter.default.post(name: .myArticleBuilt, object: self)
        }
    }

    // MARK: - Attachment Functions

    /// Get MIME type of an attachment from its file name
    func getAttachmentMimeType(name: String) -> String {
        let path = publicBasePath.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: path.path) {
            let mimeType: String? = {
                let uti = UTTypeCreatePreferredIdentifierForTag(
                    kUTTagClassFilenameExtension,
                    path.pathExtension as CFString,
                    nil
                )

                let mimetype = UTTypeCopyPreferredTagWithClass(
                    uti!.takeRetainedValue(),
                    kUTTagClassMIMEType
                )
                return mimetype?.takeRetainedValue() as String?
            }()
            if let mimeType = mimeType {
                return mimeType
            }
        }
        return "application/octet-stream"
    }

    /// Get attachment size
    func getAttachmentByteLength(name: String?) -> Int? {
        guard let name = name, let url = getAttachmentURL(name: name) else {
            return nil
        }
        do {
            let attr = try FileManager.default.attributesOfItem(atPath: url.path)
            return attr[.size] as? Int
        }
        catch {
            return nil
        }
    }

    /// Get CIDs of all attachments
    func getCIDs(for attachmentsToProcess: [String]) -> [String: String] {
        if attachmentsToProcess.count > 0 {
            var cids: [String: String] = [:]
            for attachment in attachmentsToProcess {
                if let attachmentURL = getAttachmentURL(name: attachment) {
                    if let attachmentCID = try? IPFSDaemon.shared.getFileCIDv0(url: attachmentURL) {
                        debugPrint("CID for \(attachment): \(attachmentCID)")
                        cids[attachment] = attachmentCID
                    }
                    else {
                        debugPrint("Unable to determine CID for \(attachment)")
                    }
                }
            }
            return cids
        }
        return [:]
    }

    // MARK: - NFT Related Functions

    /// Get the CID of nft.json if present
    func getNFTJSONCID() -> String? {
        if let nftJSONURL = getAttachmentURL(name: "nft.json") {
            if let nftJSONCID = try? IPFSDaemon.shared.getFileCIDv0(url: nftJSONURL) {
                debugPrint("CIDv0 for NFT metadata nft.json: \(nftJSONCID)")
                return nftJSONCID
            }
            else {
                debugPrint("Unable to determine CIDv0 for NFT metadata nft.json")
            }
        }
        return nil
    }

    // MARK: - Audio Related Functions

    func hasAudioContent() -> Bool {
        return audioFilename != nil
    }

    func getAudioDuration(name: String?) -> Int? {
        guard let name = name, let url = getAttachmentURL(name: name) else {
            return nil
        }
        let asset = AVURLAsset(url: url)
        let duration = asset.duration
        return Int(CMTimeGetSeconds(duration))
    }

    /// Format seconds as hh:mm:ss
    func formatDuration(duration: Int) -> String {
        if duration > 3600 {
            let hours = duration / 3600
            let minutes = (duration % 3600) / 60
            let seconds = duration % 60
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        else {
            let minutes = (duration % 3600) / 60
            let seconds = duration % 60
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    // MARK: - Video Related Functions

    func hasVideoContent() -> Bool {
        let result: Bool = videoFilename != nil
        debugPrint("Checking video content for \(self.title): \(result)")
        return result
    }

    func saveVideoThumbnail() {
        guard let videoFilename = self.videoFilename else { return }
        let videoThumbnailFilename = "_videoThumbnail.png"
        let videoThumbnailPath = publicBasePath.appendingPathComponent(videoThumbnailFilename)
        let opKey = "\(self.id)-video-thumbnail-\(videoFilename)"
        if let op = self.planet.ops[opKey],
            FileManager.default.fileExists(atPath: videoThumbnailPath.path)
        {
            debugPrint("Video thumbnail operation for \(opKey) is already done at \(op)")
            return
        }
        if let thumbnail = self.getVideoThumbnail(),
            let data = thumbnail.PNGData
        {
            try? data.write(to: videoThumbnailPath)
        }
        Task { @MainActor in
            self.planet.ops[opKey] = Date()
        }
    }

    func getVideoThumbnail() -> NSImage? {
        if self.hasVideoContent() {
            guard let videoFilename = self.videoFilename else {
                return nil
            }
            do {
                let url = self.publicBasePath.appendingPathComponent(videoFilename)
                let asset = AVURLAsset(url: url)
                let imageGenerator = AVAssetImageGenerator(asset: asset)
                imageGenerator.appliesPreferredTrackTransform = true
                let cgImage = try imageGenerator.copyCGImage(
                    at: .zero,
                    actualTime: nil
                )
                return NSImage(cgImage: cgImage, size: .zero)
            }
            catch {
                print(error.localizedDescription)

                return nil
            }
        }
        return nil
    }

    // MARK: - Various Generated Images

    func hasPDFContent() -> Bool {
        return self.attachments?.contains { $0.hasSuffix(".pdf") } ?? false
    }

    func hasHeroImage() -> Bool {
        return self.getHeroImage() != nil
    }

    func getHeroImage() -> String? {
        if let heroImage = self.heroImage {
            return heroImage
        }
        if self.hasVideoContent() {
            debugPrint("HeroImage: video content found")
            return "_videoThumbnail.png"
        }
        if self.hasPDFContent() {
            debugPrint("HeroImage: PDF content found")
            return "_preview.png"
        }
        debugPrint("HeroImage: finding from \(attachments ?? [])")
        let images: [String]? = attachments?.compactMap {
            let imageNameLowercased = $0.lowercased()
            if imageNameLowercased.hasSuffix(".avif") || imageNameLowercased.hasSuffix(".jpeg")
                || imageNameLowercased.hasSuffix(".jpg") || imageNameLowercased.hasSuffix(".png")
                || imageNameLowercased.hasSuffix(".webp") || imageNameLowercased.hasSuffix(".gif")
                || imageNameLowercased.hasSuffix(".tiff") || imageNameLowercased.hasSuffix(".heic")
            {
                return $0
            }
            else {
                return nil
            }
        }
        debugPrint("HeroImage candidates: \(images?.count ?? 0) \(images ?? [])")
        var firstImage: String? = nil
        if let items = images {
            for item in items {
                let imagePath = publicBasePath.appendingPathComponent(item, isDirectory: false)
                if let url = URL(string: imagePath.absoluteString) {
                    debugPrint("HeroImage: checking size of \(url.absoluteString)")
                    if let image = NSImage(contentsOf: url) {
                        if firstImage == nil {
                            firstImage = item
                        }
                        debugPrint("HeroImage: created NSImage from \(url.absoluteString)")
                        debugPrint("HeroImage: candidate size: \(image.size)")
                        if image.size.width >= 600 && image.size.height >= 400 {
                            debugPrint("HeroImage: \(item)")
                            DispatchQueue.main.async {
                                self.heroImage = firstImage
                                if let firstImage = firstImage, let size = self.getImageSize(name: firstImage) {
                                    self.heroImageWidth = Int(size.width)
                                    self.heroImageHeight = Int(size.height)
                                }
                                try? self.save()
                            }
                            return item
                        }
                    }
                }
                else {
                    debugPrint("HeroImage: invalid URL for item: \(item) \(imagePath)")
                }
            }
        }
        if firstImage != nil {
            debugPrint("HeroImage: return the first image anyway for \(self.title): \(firstImage!)")
            DispatchQueue.main.async {
                self.heroImage = firstImage
                if let firstImage = firstImage, let size = self.getImageSize(name: firstImage) {
                    self.heroImageWidth = Int(size.width)
                    self.heroImageHeight = Int(size.height)
                }
                try? self.save()
            }
            return firstImage
        }
        debugPrint("HeroImage: NOT FOUND")
        return nil
    }

    func getImageSize(name: String) -> NSSize? {
        let imagePath = publicBasePath.appendingPathComponent(name, isDirectory: false)
        if let url = URL(string: imagePath.absoluteString) {
            if let image = NSImage(contentsOf: url) {
                let imageRep = image.representations.first as? NSBitmapImageRep
                return NSSize(width: imageRep?.pixelsWide ?? 0, height: imageRep?.pixelsHigh ?? 0)
            }
        }
        return nil
    }

    func getHeroGridLocalURL() -> URL? {
        let heroGridPath = publicBasePath.appendingPathComponent(
                "_grid.png",
                isDirectory: false
            )
        if FileManager.default.fileExists(atPath: heroGridPath.path) {
            return heroGridPath
        }
        return nil
    }

    /**
     If the article has a hero image, generate a grid version of it.
     */
    func saveHeroGrid() {
        guard let heroImageFilename = self.getHeroImage() else { return }
        let heroImagePath = publicBasePath.appendingPathComponent(
            heroImageFilename,
            isDirectory: false
        )
        let heroGridPNGFilename = "_grid.png"
        let heroGridPNGPath = publicBasePath.appendingPathComponent(heroGridPNGFilename)
        let heroGridJPEGFilename = "_grid.jpg"
        let heroGridJPEGPath = publicBasePath.appendingPathComponent(heroGridJPEGFilename)
        let opKey = "\(self.id)-hero-grid-\(heroImageFilename)"
        if let op = self.planet.ops[opKey],
            FileManager.default.fileExists(atPath: heroImagePath.path),
            FileManager.default.fileExists(atPath: heroGridPNGPath.path)
        {
            debugPrint("Hero grid operation for \(opKey) is already done at \(op)")
            return
        }
        guard let heroImage = NSImage(contentsOf: heroImagePath) else { return }
        if let grid = heroImage.resizeSquare(maxLength: 512) {
            if let gridPNGData = grid.PNGData {
                try? gridPNGData.write(to: heroGridPNGPath)
            }
            if let gridJPEGData = grid.JPEGData {
                try? gridJPEGData.write(to: heroGridJPEGPath)
            }
        }
        DispatchQueue.main.async {
            self.hasHeroGrid = true
        }
        Task { @MainActor in
            debugPrint("Hero grid is saved for \(self.title)")
            self.planet.ops[opKey] = Date()
        }
    }

    var heroGridImage: NSImage? {
        if let heroGridLocalURL = getHeroGridLocalURL() {
            return NSImage(contentsOf: heroGridLocalURL)
        }
        return nil
    }

    var heroImageObject: NSImage? {
        if let heroImageFilename = self.getHeroImage() {
            let heroImagePath = publicBasePath.appendingPathComponent(
                heroImageFilename,
                isDirectory: false
            )
            return NSImage(contentsOf: heroImagePath)
        }
        return nil
    }

    // MARK: - Cover Image

    /// Prepare the text string to be used in _cover.png
    func getCoverImageText() -> String {
        debugPrint("Current attachments in \(self.title): \(self.attachments ?? [])")
        // For audio, add an icon and duration
        if let _ = audioFilename {
            return getCoverImageTextForAudioPost()
        }
        if let _ = videoFilename {
            return getCoverImageTextForVideoPost()
        }
        return getCoverImageTextForTextOnlyPost()
    }

    func getCoverImageTextForTextOnlyPost() -> String {
        var text: String = self.title
        if self.content.count > 0 {
            text = content
        }
        return text
    }

    func getCoverImageTextForAudioPost() -> String {
        var text: String = ""
        if let audioFilename = audioFilename {
            text = self.title
            if let audioDuration = getAudioDuration(name: audioFilename) {
                text += "\n\n█▄▅ " + formatDuration(duration: audioDuration)
            }
            if content.count > 0 {
                text += "\n\n" + content
            }
            return text
        }
        return getCoverImageTextForTextOnlyPost()
    }

    func getCoverImageTextForVideoPost() -> String {
        var text: String = ""
        if let videoFilename = videoFilename {
            text = self.title
            if let videoDuration = getAudioDuration(name: videoFilename) {
                text += "\n\n▶ " + formatDuration(duration: videoDuration)
            }
            if content.count > 0 {
                text += "\n\n" + content
            }
            return text
        }
        return getCoverImageTextForTextOnlyPost()
    }

    /// Save preview image from PDF
    func savePreviewImageFromPDF() {
        // If PDF is the only attachment, generate a preview image
        if let attachments = self.attachments, attachments.count == 1, attachments[0].lowercased().hasSuffix(".pdf"), let url = getAttachmentURL(name: attachments[0]) {
            let image = NSImage(contentsOf: url)
            // Write image to `_preview.png`
            if let image = image {
                let imageFilename = "_preview.png"
                let imagePath = publicBasePath.appendingPathComponent(imageFilename)
                if let imagePNGData = image.PNGData {
                    try? imagePNGData.write(to: imagePath)
                }
                DispatchQueue.main.async {
                    self.heroImage = imageFilename
                    if let size = self.getImageSize(name: imageFilename) {
                        self.heroImageWidth = Int(size.width)
                        self.heroImageHeight = Int(size.height)
                    }
                }
            }
        }
    }

    /// Save cover image to `_cover.png`
    func saveCoverImage(with string: String, filename: String, imageSize: NSSize) {
        let image = NSImage(size: imageSize)

        image.lockFocus()

        // Fill with black
        NSColor.black.set()
        NSBezierPath(rect: NSRect(origin: .zero, size: imageSize)).fill()

        let textView = NSTextView(frame: NSRect(x: 32, y: 32, width: 448, height: 448))
        textView.isEditable = false
        textView.isSelectable = false
        // Use white on black for the textView
        textView.backgroundColor = NSColor.black
        textView.drawsBackground = true

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left

        let font: NSFont
        if planet.templateName == "Croptop" {
            // Use the pixelated Capsule font for the Croptop template
            font = NSFont(name: "Capsules-500", size: 32) ?? NSFont.systemFont(ofSize: 32)
            debugPrint("Using Capsules-500 font for Croptop: \(font)")
        }
        else {
            font = NSFont.systemFont(ofSize: 32)
        }

        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white,
            .font: font,
            .paragraphStyle: paragraphStyle,
        ]

        let attributedString = NSAttributedString(string: string, attributes: attrs)

        textView.textStorage?.setAttributedString(attributedString)

        let textViewImage = textView.bitmapImageRepForCachingDisplay(in: textView.bounds)
        textView.cacheDisplay(in: textView.bounds, to: textViewImage!)
        textViewImage?.draw(in: NSRect(x: 32, y: 32, width: 448, height: 448))

        image.unlockFocus()

        // Save the image
        if let tiffData = image.tiffRepresentation,
            let bitmapImage = NSBitmapImageRep(data: tiffData)
        {
            let pngData = bitmapImage.representation(using: .png, properties: [:])
            do {
                let url = URL(fileURLWithPath: filename)
                try pngData?.write(to: url)
                print("Image saved successfully at \(url.path)")
            }
            catch {
                print("Failed to save image: \(error)")
            }
        }
    }

    // MARK: - Save Markdown content to article.md
    func saveMarkdown() async {
        let markdownPath = publicBasePath.appendingPathComponent("article.md")
        if FileManager.default.fileExists(atPath: markdownPath.path) {
            do {
                try FileManager.default.removeItem(at: markdownPath)
            }
            catch {
                debugPrint("Failed to remove article.md for \(self.title): \(error)")
            }
        }
        do {
            let markdown = "\(self.title)\n\n\(self.content)"
            try markdown.write(to: markdownPath, atomically: true, encoding: .utf8)
        }
        catch {
            debugPrint("Failed to write article.md for \(self.title): \(error)")
        }
    }

    // MARK: - Clean Up
    /// Remove `.DS_Store` file from public article folder
    func removeDSStore() {
        let dsStorePath = publicBasePath.appendingPathComponent(".DS_Store")
        if FileManager.default.fileExists(atPath: dsStorePath.path) {
            do {
                try FileManager.default.removeItem(at: dsStorePath)
                debugPrint("Removed .DS_Store for \(self.title)")
            }
            catch {
                debugPrint("Failed to remove .DS_Store for \(self.title): \(error)")
            }
        }
        if let attachments = self.attachments {
            var newAttachments: [String] = []
            for attachment in attachments {
                if attachment == ".DS_Store" {
                    let attachmentPath = publicBasePath.appendingPathComponent(attachment)
                    if FileManager.default.fileExists(atPath: attachmentPath.path) {
                        do {
                            try FileManager.default.removeItem(at: attachmentPath)
                            debugPrint("Removed .DS_Store for \(self.title)")
                        }
                        catch {
                            debugPrint("Failed to remove .DS_Store for \(self.title): \(error)")
                        }
                    }
                }
                else {
                    newAttachments.append(attachment)
                }
            }
            if newAttachments.count != attachments.count {
                self.attachments = newAttachments.sorted()
                do {
                    try self.save()
                    debugPrint("Removed .DS_Store from attachments for \(self.title)")
                }
                catch {
                    debugPrint(
                        "Failed to remove .DS_Store from attachments for \(self.title): \(error)"
                    )
                }
            }
        }
    }
}

extension OrderedDictionary where Key == String, Value == Date {
    fileprivate mutating func recordEvent(_ event: String, for title: String) {
        let previousEventTime = self.values.last ?? Date()
        let currentTime = Date()
        self[event] = currentTime
        debugPrint(
            "\(event) for \(title) took: \(String(format: "%.3f", currentTime.timeIntervalSince(previousEventTime))) seconds"
        )
    }
}
