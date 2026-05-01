# Crash Hardening Review

Follow-up findings from the crash-hardening pass.

## Findings

1. `PlanetDirectoryMonitor.start()` should fail explicitly.

   `PlanetDirectoryMonitor.start()` currently returns silently if the FSEvents stream cannot be created, and it ignores the return value from `FSEventStreamStart`. `PlanetPublishedServiceMonitor.startMonitoring()` then treats monitoring as active. Make `start()` throw when stream creation or startup fails so the existing caller can reset state and surface the existing error path.

2. Directory creation failures should not be swallowed for persistent paths.

   Some directory creation paths now use `try?`, especially in `URLUtils`, which avoids crashes but can hide failures for application support, library, or other persistent storage locations. Keep silent fallback behavior only for true temporary/cache locations. Persistent app data paths should throw or surface a blocking alert so the app does not continue in a partially initialized state.

3. WebView context-menu URLs need a scheme allowlist.

   The WebView context-menu actions now avoid force-unwrapping DOM-provided `href` and `src` strings, but they can still pass arbitrary URL schemes through menu actions. Restrict these actions to expected schemes such as `http`, `https`, and the specific `file` or internal schemes the app intentionally supports.

4. Wallet session/account failures need clearer user messaging.

   Missing WalletConnect sessions or accounts currently reuse the generic connection failure path, which shows imprecise text such as "Failed to Connect Wallet" even during transaction flows. Use a clearer reconnect/session-expired alert, and avoid building transactions with empty fallback account strings.

5. Plausible custom server parsing needs to preserve supported input formats.

   The Plausible dashboard URL builder now uses `URLComponents.host` directly from the saved server string. This rejects or misbuilds values that include a scheme, port, or path. Normalize the configured server first, preserving supported inputs such as bare hosts, `host:port`, and full `https://...` URLs before appending the dashboard domain path.

## Verification To Repeat After Fixes

- Run `git diff --check`.
- Build with Xcode for macOS 12:

  ```sh
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Planet.xcodeproj -scheme "Planet (Planet project)" -configuration Debug -destination "platform=macOS" -derivedDataPath /tmp/planet-derived CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO MACOSX_DEPLOYMENT_TARGET=12.0 build
  ```
