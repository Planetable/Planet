//
//  MyArticleModel+SavePublic.swift
//  Planet
//
//  Created by Xin Liu on 11/5/23.
//

import Dispatch
import Foundation

/// Sub processes to be executed from MyArticleModel.savePublic()
extension MyArticleModel {
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
            try nftData.write(to: publicNFTMetadataPath, options: .atomic)
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
    func processArticleHTML() throws -> ArticleHTMLPerfBreakdown {
        guard let template = planet.template else {
            throw PlanetError.MissingTemplateError
        }

        let totalStartedAt = DispatchTime.now().uptimeNanoseconds

        var mainRenderPerf = ArticleTemplateRenderPerfBreakdown()
        let articleHTML = try template.render(article: self, perf: &mainRenderPerf)
        let mainWriteStartedAt = DispatchTime.now().uptimeNanoseconds
        try articleHTML.data(using: .utf8)?.write(to: publicIndexPath, options: .atomic)
        let mainWriteDuration = DispatchTime.now().uptimeNanoseconds - mainWriteStartedAt
        debugPrint("HTML for \(self.title) saved to \(publicIndexPath.path)")

        var simpleRenderPerf: ArticleTemplateRenderPerfBreakdown? = nil
        var simpleWriteDuration: UInt64? = nil
        if template.hasSimpleHTML {
            var perf = ArticleTemplateRenderPerfBreakdown()
            let simpleHTML = try template.render(article: self, forSimpleHTML: true, perf: &perf)
            let simpleWriteStartedAt = DispatchTime.now().uptimeNanoseconds
            try simpleHTML.data(using: .utf8)?.write(to: publicSimplePath, options: .atomic)
            simpleWriteDuration = DispatchTime.now().uptimeNanoseconds - simpleWriteStartedAt
            simpleRenderPerf = perf
            debugPrint("Simple HTML for \(self.title) saved to \(publicSimplePath.path)")
        }

        return ArticleHTMLPerfBreakdown(
            mainRender: mainRenderPerf,
            mainWriteDuration: mainWriteDuration,
            simpleRender: simpleRenderPerf,
            simpleWriteDuration: simpleWriteDuration,
            totalDuration: DispatchTime.now().uptimeNanoseconds - totalStartedAt
        )
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

    // MARK: - Split Save for Quick Post

    /// Minimal save: only renders index.html so ArticleView can display the article immediately.
    /// Call `savePublicDeferred()` afterward to complete cover images, CIDs, hero grids, etc.
    func savePublicMinimal() throws {
        removeDSStore()
        if !FileManager.default.fileExists(atPath: publicBasePath.path) {
            try FileManager.default.createDirectory(
                at: publicBasePath, withIntermediateDirectories: true
            )
        }
        saveMarkdown()
        try processContent()
        _ = try processArticleHTML()
    }

    /// Complete the remaining savePublic work that was skipped by `savePublicMinimal()`:
    /// cover images, CIDs, NFT metadata, hero grid, hero image size, slug copy, article.json, and ops.
    func savePublicDeferred() throws {
        try saveCoverImage()
        savePreviewImageFromPDF()
        let coverImageCID: String? = getCoverImageCIDIfNeeded()
        processAttachmentCIDIfNeeded()
        processVideoThumbnail()
        try processNFTMetadata(with: coverImageCID)
        processHeroGrid()
        processHeroImageSize()
        try JSONEncoder.shared.encode(publicArticle).write(to: publicInfoPath, options: .atomic)
        processSlug()
        do {
            try self.planet.saveOps()
        } catch {
            debugPrint("failed to save ops to file: \(error)")
        }
        Task { @MainActor in
            debugPrint("Sending notification: myArticleBuilt \(self.id) \(self.title)")
            NotificationCenter.default.post(name: .myArticleBuilt, object: self)
        }
    }
}

struct ArticleHTMLPerfBreakdown {
    let mainRender: ArticleTemplateRenderPerfBreakdown
    let mainWriteDuration: UInt64
    let simpleRender: ArticleTemplateRenderPerfBreakdown?
    let simpleWriteDuration: UInt64?
    let totalDuration: UInt64

    func perfFields() -> [String] {
        var fields = [
            "article_html_total_breakdown_ms=\(PerfLogger.milliseconds(totalDuration))",
            "article_html_main_markdown_ms=\(PerfLogger.milliseconds(mainRender.markdownDuration))",
            "article_html_main_about_ms=\(PerfLogger.milliseconds(mainRender.aboutDuration))",
            "article_html_main_context_ms=\(PerfLogger.milliseconds(mainRender.contextDuration))",
            "article_html_main_context_has_podcast_ms=\(PerfLogger.milliseconds(mainRender.contextHasPodcastDuration))",
            "article_html_main_context_public_planet_ms=\(PerfLogger.milliseconds(mainRender.contextPublicPlanetDuration))",
            "article_html_main_context_site_navigation_ms=\(PerfLogger.milliseconds(mainRender.contextSiteNavigationDuration))",
            "article_html_main_context_has_avatar_ms=\(PerfLogger.milliseconds(mainRender.contextHasAvatarDuration))",
            "article_html_main_context_user_settings_ms=\(PerfLogger.milliseconds(mainRender.contextUserSettingsDuration))",
            "article_html_main_context_public_article_ms=\(PerfLogger.milliseconds(mainRender.contextPublicArticleDuration))",
            "article_html_main_context_style_css_hash_ms=\(PerfLogger.milliseconds(mainRender.contextStyleCSSHashDuration))",
            "article_html_main_custom_code_ms=\(PerfLogger.milliseconds(mainRender.customCodeDuration))",
            "article_html_main_stencil_ms=\(PerfLogger.milliseconds(mainRender.stencilDuration))",
            "article_html_main_write_ms=\(PerfLogger.milliseconds(mainWriteDuration))",
            "article_html_simple_enabled=\(simpleRender == nil ? 0 : 1)",
        ]

        if let simpleRender {
            fields.append(contentsOf: [
                "article_html_simple_markdown_ms=\(PerfLogger.milliseconds(simpleRender.markdownDuration))",
                "article_html_simple_about_ms=\(PerfLogger.milliseconds(simpleRender.aboutDuration))",
                "article_html_simple_context_ms=\(PerfLogger.milliseconds(simpleRender.contextDuration))",
                "article_html_simple_context_has_podcast_ms=\(PerfLogger.milliseconds(simpleRender.contextHasPodcastDuration))",
                "article_html_simple_context_public_planet_ms=\(PerfLogger.milliseconds(simpleRender.contextPublicPlanetDuration))",
                "article_html_simple_context_site_navigation_ms=\(PerfLogger.milliseconds(simpleRender.contextSiteNavigationDuration))",
                "article_html_simple_context_has_avatar_ms=\(PerfLogger.milliseconds(simpleRender.contextHasAvatarDuration))",
                "article_html_simple_context_user_settings_ms=\(PerfLogger.milliseconds(simpleRender.contextUserSettingsDuration))",
                "article_html_simple_context_public_article_ms=\(PerfLogger.milliseconds(simpleRender.contextPublicArticleDuration))",
                "article_html_simple_context_style_css_hash_ms=\(PerfLogger.milliseconds(simpleRender.contextStyleCSSHashDuration))",
                "article_html_simple_custom_code_ms=\(PerfLogger.milliseconds(simpleRender.customCodeDuration))",
                "article_html_simple_stencil_ms=\(PerfLogger.milliseconds(simpleRender.stencilDuration))",
            ])
        }
        if let simpleWriteDuration {
            fields.append("article_html_simple_write_ms=\(PerfLogger.milliseconds(simpleWriteDuration))")
        }

        return fields
    }
}
