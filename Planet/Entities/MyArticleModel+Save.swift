//
//  MyArticleModel+Save.swift
//  Planet
//
//  Created by Xin Liu on 7/2/23.
//

import AVKit
import Foundation
import SwiftUI

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
        planet.articles.removeAll { $0.id == id }
        try? FileManager.default.removeItem(at: path)
        try? FileManager.default.removeItem(at: publicBasePath)
    }

    /// Remove the slug copy
    func removeSlug(_ slugToRemove: String) {
        let slugPath = planet.publicBasePath.appendingPathComponent(
            slugToRemove,
            isDirectory: true
        )
        if FileManager.default.fileExists(atPath: slugPath.path) {
            try? FileManager.default.removeItem(at: slugPath)
        }
    }

    // MARK: - Save to Public/:planet_id/:article_id/index.html

    // TODO: Fix a potential crash here
    func obtainCoverImageCID() -> String? {
        if let coverImageURL = getAttachmentURL(name: "_cover.png") {
            if FileManager.default.fileExists(atPath: coverImageURL.path) {
                do {
                    let coverImageCID = try IPFSDaemon.shared.getFileCIDv0(url: coverImageURL)
                    return coverImageCID
                } catch {
                    return nil
                }
            }
        }
        return nil
    }

    /// Save the article into UUID/index.html along with its attachments.
    func savePublic() throws {
        let started: Date = Date()
        guard let template = planet.template else {
            throw PlanetError.MissingTemplateError
        }
        defer {
            Task { @MainActor in
                debugPrint("Sending notification: myArticleBuilt \(self.id) \(self.title)")
                NotificationCenter.default.post(name: .myArticleBuilt, object: self)
            }
        }
        // Remove article-level .DS_Store if any
        self.removeDSStore()
        // Save article.md
        self.saveMarkdown()
        // Save cover image
        //TODO: Clean up the logic here
        // MARK: Cover Image

        let coverImageText = self.getCoverImageText()

        saveCoverImage(
            with: coverImageText,
            filename: publicCoverImagePath.path,
            imageSize: NSSize(width: 512, height: 512)
        )

        var needsCoverImageCID = false
        if let attachments = self.attachments, attachments.count == 0 {
            needsCoverImageCID = true
        }
        if audioFilename != nil {
            needsCoverImageCID = true
        }

        var coverImageCID: String? = nil
        if needsCoverImageCID {
            coverImageCID = obtainCoverImageCID()
        }

        if let attachments = self.attachments, attachments.count == 0 {
            if self.planet.templateName == "Croptop" {
                // _cover.png CID is only needed by Croptop now
                let newAttachments: [String] = ["_cover.png"]
                self.attachments = newAttachments
            }
        }
        var attachmentCIDs: [String: String] = self.cids ?? [:]
        let needsToUpdateCIDs = {
            if let cids = self.cids, cids.count > 0 {
                for attachment in self.attachments ?? [] {
                    if cids[attachment] == nil {
                        debugPrint("CID Update for \(self.title): NEEDED because \(attachment) is missing")
                        return true
                    }
                    if let cid = cids[attachment], cid.hasPrefix("Qm") == false {
                        debugPrint("CID Update for \(self.title): NEEDED because \(attachment) is not CIDv0")
                        return true
                    }
                }
                return false
            }
            if self.attachments?.count ?? 0 > 0 {
                debugPrint("CID Update for \(self.title): NEEDED because cids is nil")
                return true
            }
            return false
        }()
        if needsToUpdateCIDs {
            debugPrint("CID Update for \(self.title): NEEDED")
            attachmentCIDs = getCIDs()
            self.cids = attachmentCIDs
            try? self.save()
        }
        else {
            debugPrint("CID Update for \(self.title): NOT NEEDED")
        }

        let doneCIDUpdate: Date = Date()
        debugPrint("CID Update for \(self.title) took: \(doneCIDUpdate.timeIntervalSince(started))")

        // MARK: - Video
        if self.hasVideoContent() {
            self.saveVideoThumbnail()
        }

        let doneVideoThumbnail: Date = Date()
        debugPrint(
            "Video thumbnail for \(self.title) took: \(doneVideoThumbnail.timeIntervalSince(doneCIDUpdate))"
        )

        // MARK: - NFT
        // TODO: Move all NFT-related operations into an extension
        if attachmentCIDs.count > 0, let firstKeyValuePair = attachmentCIDs.first,
            let generateNFTMetadata = template.generateNFTMetadata, generateNFTMetadata
        {
            debugPrint("Writing NFT metadata for \(self.title) \(cids)")
            let (firstKey, firstValue) = firstKeyValuePair
            // For image and text-only NFTs, we use the first image as the NFT image
            var imageCID: String
            imageCID = firstValue
            // For video NFTs, we use the CID of _videoThumbnail.png for image
            if self.hasVideoContent(),
                let videoThumbnailURL = getAttachmentURL(name: "_videoThumbnail.png"),
                let videoThumbnailCID = try? IPFSDaemon.shared.getFileCIDv0(url: videoThumbnailURL)
            {
                imageCID = videoThumbnailCID
            }
            var animationCID: String? = nil
            // For audio NFTs, we use the CID of _cover.png for image
            if let audioFilename = audioFilename, let coverImageCID = coverImageCID {
                debugPrint(
                    "Audio NFT for \(self.title): \(audioFilename) coverImageCID: \(coverImageCID)"
                )
                imageCID = coverImageCID
            }
            if let audioFilename = audioFilename, let audioCID = attachmentCIDs[audioFilename] {
                debugPrint(
                    "Audio NFT for \(self.title): \(audioFilename) animationCID: \(audioCID)"
                )
                animationCID = audioCID
            }
            if let videoFilename = videoFilename, let videoCID = attachmentCIDs[videoFilename] {
                animationCID = videoCID
            }
            debugPrint("NFT image CIDv0 for \(self.title): \(imageCID)")
            var attributes: [NFTAttribute] = []
            let titleAttribute = NFTAttribute(
                trait_type: "title",
                value: self.title
            )
            attributes.append(titleAttribute)
            let titleSHA256Attribute = NFTAttribute(
                trait_type: "title_sha256",
                value: self.title.sha256()
            )
            attributes.append(titleSHA256Attribute)
            let contentSHA256Attribute = self.content.count > 0 ? NFTAttribute(
                trait_type: "content_sha256",
                value: self.content.sha256()
            )
            : nil
            if let contentSHA256Attribute = contentSHA256Attribute {
                attributes.append(contentSHA256Attribute)
            }
            let createdAtAttribute = NFTAttribute(
                trait_type: "created_at",
                value: String(Int(self.created.timeIntervalSince1970))
            )
            attributes.append(createdAtAttribute)
            let nft = NFTMetadata(
                name: self.title,
                description: self.summary ?? firstKey,
                image: "https://ipfs.io/ipfs/\(imageCID)",
                external_url: (self.externalLink ?? self.browserURL?.absoluteString) ?? "",
                mimeType: self.getAttachmentMimeType(name: firstKey),
                animation_url: animationCID != nil ? "https://ipfs.io/ipfs/\(animationCID!)" : nil,
                attributes: attributes
            )
            let nftData = try JSONEncoder.shared.encode(nft)
            try nftData.write(to: publicNFTMetadataPath)
            let nftMetadataCID = self.getNFTJSONCID()
            debugPrint("NFT metadata CID: \(nftMetadataCID ?? "nil")")
            let nftMetadataCIDPath = publicBasePath.appendingPathComponent("nft.json.cid.txt")
            try? nftMetadataCID?.write(to: nftMetadataCIDPath, atomically: true, encoding: .utf8)
        }
        else {
            debugPrint(
                "Not writing NFT metadata for \(self.title) and CIDs: \(self.cids ?? [:]) \(template.generateNFTMetadata ?? false) \(self.attachments ?? [])"
            )
        }

        let doneNFTMetadata: Date = Date()
        debugPrint(
            "NFT metadata for \(self.title) took: \(doneNFTMetadata.timeIntervalSince(doneVideoThumbnail))"
        )

        // MARK: - Render Markdown
        // TODO: This part seems very slow, it takes seconds to render the article HTML
        let articleHTML = try template.render(article: self)
        try articleHTML.data(using: .utf8)?.write(to: publicIndexPath)

        if template.hasSimpleHTML {
            let simpleHTML = try template.render(article: self, forSimpleHTML: true)
            try simpleHTML.data(using: .utf8)?.write(to: publicSimplePath)
        }

        let doneArticleHTML: Date = Date()
        debugPrint(
            "Article HTML for \(self.title) took: \(doneArticleHTML.timeIntervalSince(doneNFTMetadata))"
        )

        if self.hasHeroImage() || self.hasVideoContent() {
            self.saveHeroGrid()
        }

        let doneHeroGrid: Date = Date()
        debugPrint(
            "Hero grid for \(self.title) took: \(doneHeroGrid.timeIntervalSince(doneArticleHTML))"
        )

        try JSONEncoder.shared.encode(publicArticle).write(to: publicInfoPath)
        if let articleSlug = self.slug, articleSlug.count > 0 {
            let publicSlugBasePath = planet.publicBasePath.appendingPathComponent(
                articleSlug,
                isDirectory: true
            )
            if FileManager.default.fileExists(atPath: publicSlugBasePath.path) {
                try? FileManager.default.removeItem(at: publicSlugBasePath)
            }
            try? FileManager.default.copyItem(at: publicBasePath, to: publicSlugBasePath)
        }

        let doneSlug: Date = Date()
        debugPrint("Slug for \(self.title) took: \(doneSlug.timeIntervalSince(doneHeroGrid))")
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
    func getCIDs() -> [String: String] {
        if let attachments = self.attachments, attachments.count > 0 {
            var cids: [String: String] = [:]
            for attachment in attachments {
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
        return videoFilename != nil
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

    func hasHeroImage() -> Bool {
        return self.getHeroImage() != nil
    }

    func getHeroImage() -> String? {
        if let heroImage = self.heroImage {
            return heroImage
        }
        if self.hasVideoContent() {
            return "_videoThumbnail.png"
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
            heroImage = firstImage
            try? self.save()
            return firstImage
        }
        debugPrint("HeroImage: NOT FOUND")
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
        Task { @MainActor in
            self.planet.ops[opKey] = Date()
        }
    }

    // MARK: - Cover Image

    /// Prepare the text string to be used in _cover.png
    func getCoverImageText() -> String {
        debugPrint("Current attachments in \(self.title): \(self.attachments ?? [])")
        // For audio, add an icon and duration
        if let audioFilename = audioFilename {
            return getCoverImageTextForAudioPost()
        }
        if let videoFilename = videoFilename {
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
    func saveMarkdown() {
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
