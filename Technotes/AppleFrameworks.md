# Apple Native Frameworks Used in Planet

This document lists all Apple native frameworks used in the Planet project and describes how each one is used.

## SwiftUI

The primary UI framework, imported in over 140 files across all targets (Planet, PlanetLite, Croptop). Every view component — from the main sidebar and article lists to settings panels, the writer editor, and wallet views — is built with SwiftUI. The app uses `@ObservedObject`, `@EnvironmentObject`, `@State`, `NSViewRepresentable` (for wrapping AppKit/WebKit views), and other SwiftUI primitives throughout.

## Foundation

Imported in nearly every Swift file. Provides core data types (`Data`, `URL`, `UUID`, `Date`), JSON encoding/decoding (`JSONEncoder`/`JSONDecoder`), file I/O (`FileManager`), networking (`URLSession`, `URLRequest`), `UserDefaults`, `ProcessInfo`, regular expressions, and string/date formatting used across all model and utility classes.

## Cocoa

Used in about 40 files, primarily for macOS-specific window and view controller management. Key uses include `NSWindowController` subclasses for the Published Folders Dashboard, Downloads window, IPFS Status window, and Log Viewer. Also used for `NSWorkspace` (opening URLs/files), `NSImage` manipulation, pasteboard operations, and the PlanetLite `AppDelegate`.

## AppKit

Imported directly in a handful of files where fine-grained macOS UI control is needed beyond what SwiftUI provides:

- **MarkdownEditorTextView** and **MarkdownListAutocomplete** — custom `NSTextView` subclass and text editing helpers for the Markdown editor.
- **Template** — `NSImage` resizing and bitmap processing for template screenshots.
- **PlanetAPIConsoleView** and **AppLogView** — text selection and copy support in log/console views.

## WebKit

Powers all HTML rendering and the JavaScript bridge. Used in:

- **WriterWebView** — live HTML preview of draft articles inside the writer, wrapped as `NSViewRepresentable` with `WKWebView`.
- **ArticleWebView** — renders published articles with navigation policy handling (opens external links in the system browser).
- **TemplateWebView** — previews blog templates.
- **PlanetDownloadsViewModel** — monitors and manages web content downloads.

## NaturalLanguage

Central to the semantic search feature. Used in three search-related files:

- **SearchEmbedding** — loads `NLEmbedding.sentenceEmbedding(for:)` models per language, generates vector embeddings for article text, and performs cosine-similarity search. Caches models lazily and uses locking for thread safety.
- **SearchDatabase** — uses `NLLanguageRecognizer` to detect the dominant language of article content, storing the detected language alongside embeddings.
- **SearchIndex** — coordinates with the embedding system during index builds and queries.

Language normalization maps variants (e.g., `zh-Hant` → `zh-Hans`) so that Traditional and Simplified Chinese share the same embedding model.

## Accelerate

Imported in **SearchEmbedding** for high-performance vector math. Used to compute dot products and vector norms efficiently when calculating cosine similarity between embedding vectors during semantic search.

## UserNotifications

Delivers local notifications to the user in eight files:

- **PlanetAppDelegate / AppDelegate** — registers notification categories and handles notification responses.
- **MyPlanetModel** — notifies when publishing completes or fails.
- **FollowingPlanetModel** — notifies when new articles are detected from followed planets.
- **IPFSDaemon** — notifies on IPFS daemon status changes.
- **TemplateStore** — notifies when template updates are available.
- **PFDashboardWindowController / PlanetPublishedServiceStore** — notifies on Published Folder events.

## AVFoundation

Used for audio playback, video metadata extraction, and video compression:

- **VideoCompressionJob** — the video compression pipeline. Uses `AVAssetExportSession` with preset selection (H.264 via `AVAssetExportPresetHighestQuality`, HEVC via `AVAssetExportPresetHEVCHighestQuality`) and `AVMutableVideoComposition` to transcode videos to fit within target resolutions (1080p/720p/480p). Handles orientation-aware scaling via `preferredTransform`, preserves HDR color properties (`colorPrimaries`, `colorTransferFunction`, `colorYCbCrMatrix`) through `CMFormatDescription` inspection, and detects HDR content via `containsHDRVideo` media characteristics. Outputs network-optimized files in MP4/MOV/M4V formats.
- **VideoAttachmentInfo** — extracts comprehensive video metadata using `AVURLAsset` and `AVAssetTrack`: duration, resolution, codec name, color space, HDR presence, bitrate, and frame rate.
- **AudioPlayer** — a SwiftUI view wrapping `AVPlayer` that provides playback controls (play/pause, seek forward/back 10s, scrubber) for audio attachments in articles.

## AVKit

Provides the video player UI. Used in:

- **MyArticleModel / MyArticleModel+Save** — video thumbnail generation via `AVAssetImageGenerator`.
- **WriterVideoView** — embeds `AVPlayerView` for video preview in the article writer.
- **PlanetQuickShareView** — video playback in the Quick Share panel.

## CoreImage

Used for image filtering and QR code generation:

- **WalletConnectV1QRCodeView / WalletConnectV2QRCodeView** — generates QR codes for WalletConnect pairing using `CIFilter.qrCodeGenerator()` and renders them via `CIContext`.
- **WalletManager** — imports `CoreImage.CIFilterBuiltins` for QR code generation.
- **Template** — applies `CIColorControls` (darken) and `CIGaussianBlur` filters to template preview images, composites them over a black background using `CISourceOverCompositing`.

## ImageIO

Handles low-level image metadata and pixel-level operations:

- **AttachmentModel** — reads EXIF data from image attachments using `CGImageSourceCreateWithURL` and `CGImageSourceCopyPropertiesAtIndex` to extract the original capture date (`kCGImagePropertyExifDateTimeOriginal`).
- **URLUtils** — strips GPS metadata from images for privacy (using `CGImageDestination` to re-encode without `kCGImagePropertyGPSDictionary`), and reads pixel dimensions/DPI to determine display size (handling @2x/@3x Retina assets).

## UniformTypeIdentifiers

Used in about 16 files for file type identification:

- **WriterDragAndDrop** — identifies dragged file types during drag-and-drop into the editor.
- **PlanetQuickShareView** — validates file types for quick sharing.
- **AttachmentModel** — determines MIME types for article attachments.
- **ArtworkView** — filters allowed image types for planet artwork.
- **CloudflarePages** — maps file extensions to MIME types for upload.

## CoreData

Legacy data persistence, used in two files under `LegacyCoreData/`:

- **CoreDataPersistence** — sets up an `NSPersistentContainer` named "Planet" and manages the `NSManagedObjectContext` for reading/writing.
- **PlanetArticle** — the Core Data entity for articles.

This is maintained for migrating data from earlier versions of Planet. The current persistence layer uses JSON files and GRDB/SQLite.

## CryptoKit

Used in **CloudflarePages** for file integrity verification during Cloudflare Pages deployments. Computes `SHA256.hash(data:)` digests of file contents to determine which files have changed and need uploading.

## CommonCrypto

Imported in **Extensions.swift**. The legacy C-based cryptography framework, kept available for any hashing or cryptographic utility needs in extension methods on Foundation types.

## Combine

Reactive event handling, used in three files:

- **WalletManager** — manages asynchronous WalletConnect session events and state changes.
- **TipSelectView** — reacts to wallet state updates for the Ethereum tipping UI.
- **ScheduledTasksManager** — a global `ObservableObject` that manages system-wide scheduled tasks (content update checks, background sync) independently of any SwiftUI view lifecycle.

## Dispatch

Imported in **MyPlanetModel** for Grand Central Dispatch primitives. Used for thread-safe concurrent operations in the planet publishing pipeline.

## Darwin

Imported in **ArticleAIChatView** for low-level POSIX process control. The AI chat feature includes a shell tool that runs commands via `Process`; `Darwin.kill(_:_:)` with `SIGKILL` is used as a last resort to force-terminate a timed-out child process when `Process.terminate()` (SIGTERM) is insufficient.

## os

The structured logging framework, imported in 15 files. Creates `Logger` instances with subsystem/category pairs for fine-grained, filterable logging:

- Search subsystem (`SearchDatabase`, `SearchIndex`, `SearchEmbedding`)
- IPFS subsystem (`IPFSDaemon`)
- Publishing (`MyPlanetModel`, `FollowingPlanetModel`, `CloudflarePages`)
- Templates (`Template`, `TemplateStore`)
- Utilities (`ENSUtils`, `KeychainHelper`, `Saver`)
- UI (`ArticleWebView`)
