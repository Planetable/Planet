# Apple Native Framework Ideas for Planet

Ideas for additional Apple native frameworks that could make Planet more useful.

## High Impact

### CoreSpotlight

Index blog posts and followed articles so users can find them from macOS Spotlight. For a content-heavy app with potentially thousands of articles, this is a natural fit. Index title, summary, tags, and author when articles are created or fetched, and delete entries when articles are removed. Users would discover their own drafts and followed content without even opening Planet.

Available since macOS 10.11 — no compatibility concerns.

### AppIntents (macOS 13+)

Expose key actions to Shortcuts and Siri: "Publish a quick post", "Check for new articles", "Search my planets". Power users could build automations like "every morning, check for updates from my followed planets and summarize what's new." This would also enable Spotlight App Shortcuts (type a verb and Planet shows up).

### Vision

Auto-generate `alt` text for images in articles. When a user drags an image into the writer, `VNRecognizeTextRequest` could OCR any text in screenshots, and `VNClassifyImageRequest` could describe photos. This is great for accessibility and SEO — two things bloggers care about. Could also detect QR codes in images without CoreImage.

Available since macOS 10.13 — no compatibility concerns.

### Translation (macOS 14+)

Planet is an international content aggregator that already uses `NLLanguageRecognizer` to detect article languages. On-device translation for followed articles in foreign languages would be compelling — a "Translate" button on articles written in languages the user doesn't read, using Apple's offline translation models.

## Medium Impact

### Swift Charts (macOS 13+)

Replace or augment the Plausible analytics with native charts: posting frequency over time, word count trends, follower activity, IPFS gateway hit counts. Even a simple "articles published per week" sparkline in the sidebar would add polish. The framework handles dark mode, accessibility, and animations for free.

### PDFKit

Export articles or entire blogs as PDF. Bloggers often want printable or archival versions of their content. `PDFDocument` could compose articles with their images and formatting into shareable PDFs. Could also support PDF attachment previews in the article reader.

Available since macOS 10.4 — no compatibility concerns.

### QuickLook (QLPreviewPanel)

Let users press Space on any attachment, template, or article to get a Quick Look preview — the standard macOS pattern. Especially useful for the template browser (preview before applying) and article attachments (images, videos, PDFs) without opening a full viewer.

Available since macOS 10.6 — no compatibility concerns.

### CoreML

Enhance the existing NaturalLanguage search with a custom model for auto-tagging articles by topic, spam/quality detection on followed feeds, or smarter content recommendations ("articles similar to ones you've starred"). The embedding infrastructure is already in place — CoreML could slot in alongside it.

Available since macOS 10.13 — no compatibility concerns.

## Nice to Have

### ServiceManagement (SMAppService, macOS 13+)

Register a login item or launch agent to keep the IPFS daemon running in the background even when the main app isn't open. Currently the daemon lifecycle is tied to the app — `SMAppService` would let it persist across reboots, which matters for keeping content available on the IPFS network.

### NSDataDetector

Auto-detect links, dates, addresses, and phone numbers in article content and make them actionable. Already in Foundation but underused — could enhance the article reader by making detected entities tappable.

Available since macOS 10.7 — no compatibility concerns.

### Share Extension

A macOS Share Extension so users can share URLs, text, or images from Safari and other apps directly into Planet as a new quick post. This would reduce friction for the "saw something interesting, want to blog about it" workflow.

### Network Framework (NWPathMonitor)

Use `NWPathMonitor` to detect connectivity changes and pause/resume IPFS syncing intelligently. Show a clear "offline" indicator and queue publishes for when connectivity returns, rather than failing silently.

Available since macOS 10.14 — no compatibility concerns.
