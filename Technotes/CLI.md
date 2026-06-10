# Planet CLI

`pn` is Planet's command-line utility. It is built as part of the main Xcode project and bundled inside the app at `Planet.app/Contents/Helpers/pn`.

The initial scope is a Content MVP: inspect and mutate local planets and articles, use Planet's REST API when the app is running, and fall back to direct library file access when the app is not running. Publishing remains API-only because it depends on the live app publishing stack.

## Build Integration

`pn` is a macOS command-line target in `Planet.xcodeproj` with `MACOSX_DEPLOYMENT_TARGET = 12.0`.

The main `Planet` scheme builds the CLI target, the app target has an explicit dependency on `pn`, and the app copies the built executable into `Contents/Helpers` during the app build. The CLI should not be auto-installed into `/usr/local/bin` as part of every build. Users can opt in with `pn install`.

When editing the project file for this target, use the `xcodeproj` Ruby gem rather than editing `project.pbxproj` by hand.

## Source Layout

The CLI source lives in `PlanetCLI/`.

- `main.swift` is the entry point.
- `PNCommandRunner.swift` owns global option parsing, command dispatch, user-facing output, selector resolution, and confirmation prompts.
- `PNAPIClient.swift` is a small Foundation `URLSession` client for the Planet REST API.
- `PNDiskStore.swift` reads and writes the on-disk Planet library.
- `PNModels.swift` contains pure Swift `Codable` records that mirror persisted Planet JSON keys.
- `PNPreferences.swift` reads Planet's container preferences and resolves default library and API settings.
- `PNAppBridge.swift` detects the running app, opens the app URL API controls, and resolves bundled app resources for disk-mode operations.
- `PNJSON.swift` centralizes date and pretty/sorted JSON encoding.

The CLI intentionally does not depend on Swift Argument Parser, Vapor, or broad app UI model target membership. Keep it mostly Foundation plus small AppKit bridging for `NSWorkspace` and running-app detection.

## Runtime Modes

The global source option is `--source auto|api|disk`; `auto` is the default.

In `auto` mode, `pn` checks whether `xyz.planetable.Planet` is running. If the app is running, `pn` uses the REST API. If `/v0/ping` is not reachable, `pn` opens `planet://api/start?port=<port>` and polls `/v0/ping` until the configured timeout. If the app is not running, `pn` uses the disk store.

In `api` mode, `pn` requires a reachable Planet API. If the first ping fails, it asks the running app to start the API through the same URL action and waits for it.

In `disk` mode, `pn` never tries to contact the running app. It reads and writes files in the resolved Planet library.

`pn api status` is a passive ping check. `pn api start` and `pn api stop` send app URL actions. The app handles these URLs before the generic `planet://` follow/import path so API control URLs are not interpreted as content URLs.

## API Control URLs

The running app supports these control URLs:

```
planet://api/start?port=8086
planet://api/stop
```

The start URL calls `PlanetAPIController.shared.start()` inside the app after applying the requested port. The stop URL calls `PlanetAPIController.shared.stop()`.

These URLs are internal control actions for `pn` and should stay ahead of generic URL routing in `PlanetAppDelegate`.

## API Authentication

`pn` discovers authentication from the server, not from preferences. It probes `GET /v0/ping`: a 2xx response means the API is open, an HTTP 401 means the API is reachable but requires HTTP Basic Auth, and a transport error means the API is not running. A 401 never triggers the app-start URL action.

When the server requires authentication, `pn` resolves credentials in this order, validating each candidate with the read-only `GET /v0/ping` before using it:

1. `PN_API_USERNAME` and `PN_API_PASSCODE` environment variables.
2. An interactive Username/Passcode prompt on the terminal, up to three attempts. The username defaults to `PN_API_USERNAME`, falling back to `Planet`. Prompts write to stderr so `--json` output stays clean.

`pn` deliberately does not read the app's keychain item: the passcode lives in the data-protection keychain, which a separately signed CLI cannot access reliably.

If neither source produces valid credentials, or stdin is not a terminal, `pn` fails with a message pointing at the environment variables.

API control URLs are opened without activating the app, so `pn` does not steal focus from the terminal.

## Library Resolution

Disk mode resolves the Planet library in this order:

1. The global `--library <path>` option.
2. `PlanetSettingsLibraryLocationKey` from `~/Library/Containers/xyz.planetable.Planet/Data/Library/Preferences/xyz.planetable.Planet.plist`; if that path contains a `Planet` subdirectory, that subdirectory is used.
3. `~/Library/Containers/xyz.planetable.Planet/Data/Documents/Planet`.

The expected library layout is:

```
Planet/
  My/
    <planet-uuid>/
      planet.json
      Articles/
        <article-uuid>.json
      Drafts/
      ArticleDrafts/
      avatar.png
  Public/
    <planet-uuid>/
      planet.json
      avatar.png
      assets from the selected template
      <article-uuid>/
        article.json
        attachments
  Templates/
    <template-name>/
      template.json
```

## Disk Writes

Disk `planet create` creates `My/<uuid>` and `Public/<uuid>`, creates the article and draft directories, generates an IPNS key named with the planet UUID, writes `planet.json`, copies an avatar when provided, and seeds public template assets.

The IPNS key is generated with Planet's bundled Kubo binary. If the IPFS repo has not been initialized yet, `pn` initializes it before key generation. Disk `planet delete` removes the private and public planet directories and best-effort removes the IPNS key with the same UUID.

Disk `article create` writes the private article JSON, public article metadata, attachment files, and increments the planet's `nextArticleNumber`. Disk `article update` rewrites the private article JSON and public metadata, and either appends attachments or replaces them when `--replace-attachments` is passed. Disk `article delete` removes the private article JSON and public article directory.

All JSON writes go through `PNJSON` using pretty-printed, sorted keys and Planet-compatible date encoding.

## Data Models

`PNPlanetRecord`, `PNArticleRecord`, and `PNPublicArticleRecord` are intentionally small `Codable` mirrors of the persisted JSON used by `MyPlanetModel` and `MyArticleModel`. They should remain storage records, not UI models.

When adding a field, prefer matching the existing JSON key and optionality. Avoid pulling app model types into the CLI target unless a future use case clearly requires shared non-UI logic.

`PNSearchResponse` mirrors the API shape enough for command output and disk-mode search. Disk search is simple case-insensitive matching across planet names/about text and article title/content. API search delegates to `/v0/search`.

## Selectors

Planet selectors accept UUID, slug, exact case-insensitive planet name, or a UUID prefix in the Docker CLI style, such as the first eight characters of the UUID.

Article selectors accept UUID, article reference such as `<PREFIX>-<number>`, exact case-insensitive article title, or a UUID prefix.

Matching precedence is full UUID, then exact slug/name or reference/title, then UUID prefix. Exact matches win so a planet named like a hex prefix never becomes ambiguous with another planet's UUID. The shared matching logic lives in `PNSelector` in `PNModels.swift`.

Ambiguous selectors fail and print candidate IDs. This is deliberate; CLI mutations should not guess between similarly named planets or articles, and a UUID prefix shared by several records is rejected the same way.

## Command Surface

Global options:

```
--json
--pretty
--library <path>
--api-url <url>
--source auto|api|disk
--timeout <seconds>
```

Commands:

```
pn help [command]
pn version
pn install [--to /usr/local/bin] [--force]
pn status
pn api status
pn api start [--port 8086] [--wait 10]
pn api stop
pn library path
pn library doctor
pn template list
pn planet list [--all] [--archived]
pn planet show <planet>
pn planet path <planet> [--public]
pn planet create --name <name> [--about <text>] [--template <name>] [--avatar <path>]
pn planet update <planet> [--name <name>] [--about <text>] [--template <name>] [--avatar <path>]
pn planet delete <planet> [--yes]
pn planet publish <planet> [--wait]
pn article list <planet> [--all] [--limit <n>]
pn article show <planet> <article> [--content]
pn article path <planet> <article> [--public]
pn article create <planet> [--title <title>] [--content <text> | --content-file <path>] [--date <iso8601>] [--attachment <path>]...
pn article update <planet> <article> [--title <title>] [--content <text> | --content-file <path>] [--date <iso8601>] [--replace-attachments --attachment <path>]...
pn article delete <planet> <article> [--yes]
pn search <query> [--limit <n>] [--planet <planet>]
```

Human-readable tables are the default. `--json` is the machine-readable mode.

`planet list --archived` and `planet list --all` map to `/v0/planets/my?archived=true` and `?all=true` in API mode. Planet selectors resolve against all planets, including archived ones, in both modes.

In API mode the app serves reads and planet deletion for archived planets, but rejects content mutations and publish with HTTP 400 because archived planets are excluded from publishing. Disk mode does not enforce this and will mutate archived planet files when asked.

## Installation

The bundled helper can install itself by creating a symlink:

```
Planet.app/Contents/Helpers/pn install --to /usr/local/bin
```

Use `--force` to replace an existing target symlink or file. The install command points the destination to the currently running `pn` executable, so it works from the app bundle and from a development build.

## Verification

Build:

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Planet.xcodeproj -scheme "Planet" -derivedDataPath /tmp/planet-derived build
```

Check the bundled helper:

```
/tmp/planet-derived/Build/Products/Debug/Planet.app/Contents/Helpers/pn --version
/tmp/planet-derived/Build/Products/Debug/Planet.app/Contents/Helpers/pn help
```

Check disk mode against a temporary library:

```
tmp=$(mktemp -d /tmp/pn-smoke.XXXXXX)
bin=/tmp/planet-derived/Build/Products/Debug/Planet.app/Contents/Helpers/pn
planet_id=$($bin --source disk --library "$tmp" --json planet create --name "CLI Smoke" | ruby -rjson -e 'print JSON.parse(STDIN.read)["id"]')
article_id=$($bin --source disk --library "$tmp" --json article create "$planet_id" --title "Hello" --content "World" | ruby -rjson -e 'print JSON.parse(STDIN.read)["id"]')
$bin --source disk --library "$tmp" article update "$planet_id" "$article_id" --title "Updated" --content "Two"
$bin --source disk --library "$tmp" --json search Updated
$bin --source disk --library "$tmp" article delete "$planet_id" "$article_id" --yes
$bin --source disk --library "$tmp" planet delete "$planet_id" --yes
```

Check install with a temporary destination:

```
tmp=$(mktemp -d /tmp/pn-install.XXXXXX)
/tmp/planet-derived/Build/Products/Debug/Planet.app/Contents/Helpers/pn install --to "$tmp" --force
"$tmp/pn" --version
```

For app/API smoke testing, start Planet with API disabled and run `pn status`. It should detect the running app, send `planet://api/start`, wait for `/v0/ping`, and report `source: api`. Repeat with passcode authentication enabled to verify the interactive Username/Passcode prompt, the `PN_API_USERNAME`/`PN_API_PASSCODE` environment variables, and Basic Auth.

## Limitations

`planet publish` is API-only. Disk mode intentionally does not duplicate the app's live IPFS publishing orchestration.

Disk mode keeps content JSON and file layout coherent enough for local content work, but it is not a complete replacement for all app-side rebuild and publishing behavior.

The CLI should stay small. If future features need app services, prefer API endpoints or narrowly shared pure Swift helpers over adding app UI model membership to the CLI target.
