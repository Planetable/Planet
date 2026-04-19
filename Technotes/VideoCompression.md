# Video Compression

This note documents the current Writer video compression pipeline and its active parameters.

Source of truth:

- [Planet/Writer/VideoCompressionJob.swift](/Users/livid/Developer/Planet/Planet/Writer/VideoCompressionJob.swift)
- [Planet/Writer/VideoInfoRow.swift](/Users/livid/Developer/Planet/Planet/Writer/VideoInfoRow.swift)
- [Planet/Entities/DraftModel.swift](/Users/livid/Developer/Planet/Planet/Entities/DraftModel.swift)

## Current Export Strategy

Writer compression currently uses `AVAssetExportSession`, not a custom `AVAssetReader` / `AVAssetWriter` pipeline.

- Preset:
  - H.264 options use `AVAssetExportPresetHighestQuality`
  - HEVC options use `AVAssetExportPresetHEVCHighestQuality`
- Output is resized with an `AVMutableVideoComposition`
- `shouldOptimizeForNetworkUse = true`
- `canPerformMultiplePassesOverSourceMediaData = true`
- `directoryForTemporaryFiles = FileManager.default.temporaryDirectory`
- A soft size cap is applied via `fileLengthLimit`

Important caveat:

- `fileLengthLimit` is a file-size target, not a strict encoder bitrate setting
- Actual output bitrate may still land above or below the nominal target depending on source content and how `AVAssetExportSession` honors the cap

## Presets

There are six visible presets:

| Option | Codec | Bounding Size | Target Video Bitrate |
| --- | --- | --- | --- |
| `h264FitInside1080p` | H.264 | `1920x1080` | `7 Mbps` |
| `h264FitInside720p` | H.264 | `1280x720` | `4 Mbps` |
| `h264FitInside480p` | H.264 | `640x480` | `2 Mbps` |
| `h265FitInside1080p` | HEVC | `1920x1080` | `7 Mbps` |
| `h265FitInside720p` | HEVC | `1280x720` | `4 Mbps` |
| `h265FitInside480p` | HEVC | `640x480` | `2 Mbps` |

The codec choice only changes the export preset. The current bitrate target is driven by output resolution, not by codec.

## Resize Rules

- Video is scaled to fit inside the preset bounding box
- Aspect ratio is preserved
- Scaling never enlarges beyond the source size
- Output dimensions are rounded down to even numbers, minimum `2`
- Portrait sources use the bounding box rotated to portrait

Examples:

- A `1080x1920` source with the `720p` preset becomes `720x1280`
- A source already smaller than the preset is not upscaled

## Frame Rate

- The output composition keeps the source frame rate when available
- `frameDuration = 1 / round(source nominalFrameRate)`
- If nominal frame rate is unavailable or invalid, the timescale falls back to at least `1`

## Audio Budget

The current size cap includes a small audio allowance:

- If source audio bitrate is unavailable: use `128 kbps`
- If source audio bitrate is available: clamp it to `96–192 kbps`

This is only used to estimate `fileLengthLimit`. It does not directly configure the audio encoder.

## File Length Limit Formula

`fileLengthLimit` is computed as:

```text
durationSeconds * (targetVideoBitrate + audioBitrateBudget) / 8 * 1.03
```

Where:

- `durationSeconds` is the full asset duration
- `targetVideoBitrate` is `7 / 4 / 2 Mbps` by output resolution
- `audioBitrateBudget` is the clamped budget above
- `1.03` is a container-overhead multiplier

## HDR Rule

- If the source is detected as HDR, non-HEVC presets are rejected
- In that case the job throws `hdrRequiresHEVC`

## Output File Naming

Compressed exports are first written to a temporary directory under `NSTemporaryDirectory()`.

- The temporary export directory is a UUID
- The temporary filename is also a lowercase UUID
- The extension is lowercase and follows the chosen output container:
  - `.mov`
  - `.mp4`
  - `.m4v`

This avoids collisions with original names such as `.MOV` vs `.mov` on case-insensitive filesystems.

## Attachment Replacement

After a successful export:

- The compressed file is copied into the draft attachments directory as a new attachment
- The old markdown reference is updated if the attachment name changed
- The original attachment file is deleted only if it is not the same on-disk item as the new file

This guard exists to prevent accidental deletion of the replacement on case-insensitive volumes.

## Logging

Compression debug logging currently writes to:

- `NSTemporaryDirectory()/video.log`
- For the sandboxed Planet app this resolves under `~/Library/Containers/xyz.planetable.Planet/Data/tmp/video.log`

The log includes:

- preset selection
- source track details
- output file type selection
- bitrate budget and `fileLengthLimit`
- progress milestones
- completion, cancellation, and failures
- metadata reload after replacement

## Known Limitation

The current implementation is still constrained by `AVAssetExportSession`.

If we need tighter control over actual delivered bitrate, GOP structure, profile, or audio encoding parameters, we will likely need to move to an `AVAssetReader` / `AVAssetWriter` based pipeline.
