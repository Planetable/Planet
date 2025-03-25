//
//  MyArticleModel+SavePublic.swift
//  Planet
//
//  Created by Xin Liu on 11/5/23.
//

import Foundation

/// Sub processes to be executed from MyArticleModel.savePublic()
extension MyArticleModel {
    /// Save article.md with a background thread
    func saveMarkdownInBackground() {
        Task(priority: .background) {
            await self.saveMarkdown()
        }
    }

    /// Render markdown to HTML if contentRendered is nil
    func processContent() throws {
        guard self.content.count > 0, self.contentRendered == nil else { return }

        if let contentHTML = CMarkRenderer.renderMarkdownHTML(markdown: self.content) {
            self.contentRendered = contentHTML
            try self.save()
        }
    }

    func hasTextOnlyContent() -> Bool {
        let mediaExtensions = [".png", ".apng", ".jpeg", ".jpg", ".tiff", ".webp", ".gif", ".mp4", ".mov", ".pdf"]
        return !(self.attachments ?? []).contains { attachment in
            mediaExtensions.contains(where: attachment.lowercased().hasSuffix)
        }
    }

    /// Save `_cover.png` for Croptop for text-only posts
    func saveCoverImage() throws {
        if hasTextOnlyContent() {
            let coverImageText = self.getCoverImageText()

            if self.planet.templateName == "Croptop" {
                saveCoverImage(
                    with: coverImageText,
                    filename: publicCoverImagePath.path,
                    imageSize: NSSize(width: 512, height: 512)
                )
            }
        }
    }

    // TODO: Fix a potential crash here
    func obtainCoverImageCID() -> String? {
        if let coverImageURL = getAttachmentURL(name: "_cover.png") {
            if FileManager.default.fileExists(atPath: coverImageURL.path) {
                do {
                    let coverImageCID = try IPFSDaemon.shared.getFileCIDv0(url: coverImageURL)
                    return coverImageCID
                }
                catch {
                    return nil
                }
            }
        }
        return nil
    }

    func getCoverImageCIDIfNeeded() -> String? {
        var needsCoverImageCID = false
        if let attachments = self.attachments, attachments.count == 0,
            self.planet.templateName == "Croptop"
        {
            needsCoverImageCID = true
        }
        if audioFilename != nil, self.planet.templateName == "Croptop" {
            needsCoverImageCID = true
        }

        var coverImageCID: String? = nil
        if needsCoverImageCID {
            coverImageCID = obtainCoverImageCID()
        }

        return coverImageCID
    }

    func processAttachmentCIDIfNeeded() {
        // This logic is needed because the Croptop grid view needs at least one picture
        if let attachments = self.attachments, attachments.count == 0 {
            if self.planet.templateName == "Croptop" {
                // _cover.png CID is only needed by Croptop now
                let newAttachments: [String] = ["_cover.png"]
                DispatchQueue.main.async {
                    self.attachments = newAttachments
                }
            }
        }
        var attachmentsToProcess: [String] = []
        if let attachments = self.attachments {
            attachmentsToProcess = attachments
        }
        if attachmentsToProcess.count == 0, self.planet.templateName == "Croptop" {
            attachmentsToProcess = ["_cover.png"]
        }
        var attachmentCIDs: [String: String] = self.cids ?? [:]
        let needsToUpdateCIDs = {
            if let cids = self.cids, cids.count > 0 {
                for attachment in attachmentsToProcess {
                    if cids[attachment] == nil {
                        debugPrint(
                            "CID Update for \(self.title): NEEDED because \(attachment) is missing"
                        )
                        return true
                    }
                    if let cid = cids[attachment], cid.hasPrefix("Qm") == false {
                        debugPrint(
                            "CID Update for \(self.title): NEEDED because \(attachment) is not CIDv0"
                        )
                        return true
                    }
                }
                return false
            }
            if attachmentsToProcess.count > 0 {
                debugPrint("CID Update for \(self.title): NEEDED because cids is nil")
                return true
            }
            return false
        }()
        if needsToUpdateCIDs {
            debugPrint("CID Update for \(self.title): NEEDED")
            attachmentCIDs = getCIDs(for: attachmentsToProcess)
            self.cids = attachmentCIDs
            try? self.save()
        }
        else {
            debugPrint("CID Update for \(self.title): NOT NEEDED")
        }
    }

    /// Process video thumbnail
    func processVideoThumbnail() {
        if self.hasVideoContent() {
            self.saveVideoThumbnail()
        }
    }

    /// Process NFT metadata
    func processNFTMetadata(with coverImageCID: String?) throws {
        guard let template = planet.template else {
            throw PlanetError.MissingTemplateError
        }
        if let cids = self.cids, cids.count > 0, let firstKeyValuePair = cids.first,
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
            if let audioFilename = audioFilename, let audioCID = cids[audioFilename] {
                debugPrint(
                    "Audio NFT for \(self.title): \(audioFilename) animationCID: \(audioCID)"
                )
                animationCID = audioCID
            }
            if let videoFilename = videoFilename, let videoCID = cids[videoFilename] {
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
            let contentSHA256Attribute =
                self.content.count > 0
                ? NFTAttribute(
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
                animation_url: (animationCID != nil ? "https://ipfs.io/ipfs/\(animationCID!)" : nil),
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
    }

    /// Render article HTML
    func processArticleHTML(usingTasks: Bool = false) throws {
        guard let template = planet.template else {
            throw PlanetError.MissingTemplateError
        }

        if (usingTasks) {
            Task(priority: .userInitiated) {
                let articleHTML = try template.render(article: self)
                try articleHTML.data(using: .utf8)?.write(to: publicIndexPath)
                debugPrint("HTML for \(self.title) saved to \(publicIndexPath.path)")
            }

            Task(priority: .userInitiated) {
                if template.hasSimpleHTML {
                    let simpleHTML = try template.render(article: self, forSimpleHTML: true)
                    try simpleHTML.data(using: .utf8)?.write(to: publicSimplePath)
                    debugPrint("Simple HTML for \(self.title) saved to \(publicSimplePath.path)")
                }
            }
        } else {
            let articleHTML = try template.render(article: self)
            try articleHTML.data(using: .utf8)?.write(to: publicIndexPath)
            debugPrint("HTML for \(self.title) saved to \(publicIndexPath.path)")

            if template.hasSimpleHTML {
                let simpleHTML = try template.render(article: self, forSimpleHTML: true)
                try simpleHTML.data(using: .utf8)?.write(to: publicSimplePath)
                debugPrint("Simple HTML for \(self.title) saved to \(publicSimplePath.path)")
            }
        }
    }

    /// Process hero grid
    func processHeroGrid() {
        if self.hasHeroImage() || self.hasVideoContent() {
            self.saveHeroGrid()
        }
    }

    /// Process hero image size
    func processHeroImageSize() {
        if let heroImage = self.getHeroImage() {
            if let size = self.getImageSize(name: heroImage){
                if (self.heroImageWidth != Int(size.width) || self.heroImageHeight != Int(size.height)) {
                    self.heroImageWidth = Int(size.width)
                    self.heroImageHeight = Int(size.height)
                    debugPrint("Hero image size saved for \(self.title): \(size.width) x \(size.height)")
                    try? self.save()
                }
            }
        }
    }

    /// Process slug
    func processSlug() {
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
    }
}
