---
name: apple-localization
description: Add and review macOS app localizations in Planet or another Apple-platform project. Use when Codex needs to add a new .lproj localization, register it in an Xcode project, translate Localizable.strings or InfoPlist.strings, review newly added translations for awkward wording, or align UI text with Apple's shipped macOS terminology by inspecting local Apple .lproj resources on the same machine.
---

# Apple Localization

Use this workflow for two common requests:

1. Add a new localization.
2. Review new translations, fix awkward strings, and align terms with Apple's shipped macOS UI language for that locale.

Prefer local Apple resources on the machine over web search. For Planet, keep macOS 12 compatibility and use `/Applications/Xcode.app/` if present, otherwise `/Applications/Xcode-16.4.0.app/`.

## Add A Localization

1. Identify the target locale code, such as `hi`, `ja`, or `zh-Hant`.
2. Inspect existing localizations:

```bash
find Planet -maxdepth 2 -path '*/Localizable.strings' -o -path '*/InfoPlist.strings'
```

3. Create `Planet/<locale>.lproj/InfoPlist.strings` and `Planet/<locale>.lproj/Localizable.strings` from the English key set. Preserve key order and comments.
4. Translate values only. Do not translate keys. Preserve placeholders, escaped newlines, Markdown syntax, product names, file extensions, commands, and code literals unless the existing app style clearly localizes them.
5. Register the locale in `Planet.xcodeproj/project.pbxproj` using the `xcodeproj` Ruby gem, not direct pbxproj editing. Add the locale to `knownRegions` and to both `Localizable.strings` and `InfoPlist.strings` variant groups.

## Mine Apple Terminology

Search installed Apple apps and system resources for the target locale:

```bash
rg --files /Applications /System/Applications /System/Library 2>/dev/null \
  | rg '/<locale>\.lproj/.*\.strings$'
```

Read candidate files with `plutil -p`, which handles binary and UTF-16 strings:

```bash
plutil -p '/Applications/SF Symbols.app/Contents/Resources/<locale>.lproj/Localizable.strings' | rg 'Cancel|Delete|Settings|Export|Finder'
plutil -p '/Applications/Numbers.app/Contents/Resources/<locale>.lproj/MainMenu.strings' | rg 'Show|Hide|Quit|Save|Open'
```

Useful Apple sources include SF Symbols for compact command labels, Numbers/Pages/Keynote for document UI, Finder/System apps for macOS menu language, and Music/TV for media-specific terms such as explicit content.

When several Apple strings disagree, prefer:

1. Recent Apple apps on the same OS.
2. The app with the closest UI context.
3. Menu/button wording over prose wording for menu/button labels.

## Review A New Translation

Do a values-only scan so source keys do not create false positives:

```ruby
path = 'Planet/<locale>.lproj/Localizable.strings'
terms = %w[<old-or-suspicious-terms>]
File.readlines(path, chomp: true).each_with_index do |line, idx|
  next unless line =~ /^"((?:\\.|[^"])*)"\s*=\s*"((?:\\.|[^"])*)";/
  key = $1
  val = $2
  hits = terms.select { |term| val.include?(term) }
  puts "#{idx + 1}: #{hits.join(', ')} | #{key} => #{val}" unless hits.empty?
end
```

Also sample the whole file in chunks with line numbers. Term scans catch consistency; chunk reading catches awkward sentence flow.

For Hindi, Apple-style terms observed on this machine include:

- `Cancel` -> `रद्द करें`
- `Delete` -> `डिलीट करें`
- `Done` -> `पूर्ण`
- `Export` -> `एक्सपोर्ट करें`
- `Import` -> `इंपोर्ट करें`
- `Open in Finder` / `Show in Finder` -> `Finder में दिखाएँ`
- `Settings` -> `सेटिंग्ज़`
- `Show` / `Hide` -> `दिखाएँ` / `छिपाएँ`
- `Save` -> `सहेजें`
- `OK` -> `ठीक`

Use the same technique to build a locale-specific term list for other languages.

## Preserve Runtime Safety

After edits, run all of these checks:

```bash
plutil -lint Planet/*.lproj/*.strings
```

```ruby
files = ['Planet/en.lproj/Localizable.strings', 'Planet/<locale>.lproj/Localizable.strings']
parsed = files.map do |path|
  File.readlines(path, chomp: true).filter_map do |line|
    next unless line =~ /^"((?:\\.|[^"])*)"\s*=\s*"((?:\\.|[^"])*)";/
    [$1, $2]
  end
end
source_keys = parsed[0].map(&:first)
target_keys = parsed[1].map(&:first)
missing = source_keys - target_keys
extra = target_keys - source_keys
order_mismatch = source_keys.zip(target_keys).each_with_index.find { |(a, b), _| a != b }
placeholder = /%(?:(\d+)\$)?[@dDsSfFiIuUxXoOcC]/
placeholder_mismatches = []
parsed[0].zip(parsed[1]).each do |(source_key, _), (_target_key, target_value)|
  source_count = source_key.scan(placeholder).count
  target_positions = target_value.scan(placeholder).each_with_index.map { |(pos), idx| pos ? pos.to_i : idx + 1 }
  expected_positions = (1..source_count).to_a
  placeholder_mismatches << [source_key, expected_positions, target_positions] unless target_positions.sort == expected_positions
end
puts "missing=#{missing.count} extra=#{extra.count} order_mismatch=#{order_mismatch ? order_mismatch.inspect : 'none'} placeholder_mismatches=#{placeholder_mismatches.count}"
placeholder_mismatches.first(20).each { |row| p row }
```

Build the app and confirm the bundle contains the new locale:

```bash
set -o pipefail
if [ -d /Applications/Xcode.app ]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
else
  export DEVELOPER_DIR=/Applications/Xcode-16.4.0.app/Contents/Developer
fi
xcodebuild -project Planet.xcodeproj -scheme "Planet" -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/planet-derived \
  CODE_SIGNING_ALLOWED=NO MACOSX_DEPLOYMENT_TARGET=12.0 build
find /tmp/planet-derived/Build/Products/Debug/Planet.app/Contents/Resources \
  -maxdepth 1 -type d -name '<locale>.lproj' -print
```

If a build fails because package derived data is stale, remove `/tmp/planet-derived`, resolve packages with `-onlyUsePackageVersionsFromResolvedFile`, then rebuild.

## Finish

Summarize the locale added or reviewed, notable terminology decisions, validation results, and whether the build succeeded. If committing, include only the localization files and the Xcode project registration unless the repo's hooks intentionally update versioning files.
