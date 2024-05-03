Useful FFmpeg commands to enhance videos for Planet.

## Convert to Progressive HEVC

```
ffmpeg -i input.mp4 -c:v libx265 -crf 28 -c:a copy -tag:v hvc1 -movflags faststart output-x265-fast.mp4
```

## 4x Upscale with Nearest Neighbor

```
ffmpeg -i input.mp4 -crf 18 -vf "scale=iw*4:ih*4:flags=neighbor" output-4x.mp4
```

## Move Metadata to Beginning

```
ffmpeg -i input.mp4 -codec copy -movflags faststart output-fast.mp4
```