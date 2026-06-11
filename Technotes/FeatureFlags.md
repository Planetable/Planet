# Feature Flags

Planet uses build-time feature flags for features that should be compiled in or out of a given app build. Current flags cover Apple Intelligence support and AI chat scroll management.

## Goals

- Keep feature decisions centralized and easy to audit.
- Preserve macOS 12 compatibility while allowing newer SDK APIs behind guards.
- Avoid scattering raw build-setting checks through normal UI logic.
- Allow local builds to enable or disable experimental features through `Planet/local.xcconfig`.

## Files

| File | Role |
|------|------|
| `Planet/Planet.xcconfig` | Debug defaults and Swift compilation-condition plumbing |
| `Planet/Release.xcconfig` | Release defaults and Swift compilation-condition plumbing |
| `Planet/local.xcconfig` | Machine-local overrides; ignored by Git |
| `Planet/FeatureFlags.swift` | Typed Swift facade for build-time feature decisions |

## Current Flags

| Build setting | Swift condition | FeatureFlags property | Default |
|---------------|-----------------|-----------------------|---------|
| `PLANET_ENABLE_APPLE_INTELLIGENCE` | `PLANET_ENABLE_APPLE_INTELLIGENCE` | `FeatureFlags.appleIntelligenceSupport` | `YES` |
| `PLANET_ENABLE_AI_CHAT_SCROLL_MANAGEMENT` | `PLANET_ENABLE_AI_CHAT_SCROLL_MANAGEMENT` | `FeatureFlags.aiChatScrollManagement` | `NO` |

## Xcode Configuration

The tracked xcconfig files define the default and map `YES`/`NO` onto Swift active compilation conditions:

```xcconfig
PLANET_ENABLE_APPLE_INTELLIGENCE = YES
PLANET_APPLE_INTELLIGENCE_COMPILATION_CONDITION_YES = PLANET_ENABLE_APPLE_INTELLIGENCE
PLANET_APPLE_INTELLIGENCE_COMPILATION_CONDITION_NO =
PLANET_ENABLE_AI_CHAT_SCROLL_MANAGEMENT = NO
PLANET_AI_CHAT_SCROLL_MANAGEMENT_COMPILATION_CONDITION_YES = PLANET_ENABLE_AI_CHAT_SCROLL_MANAGEMENT
PLANET_AI_CHAT_SCROLL_MANAGEMENT_COMPILATION_CONDITION_NO =
SWIFT_ACTIVE_COMPILATION_CONDITIONS = $(inherited) $(PLANET_APPLE_INTELLIGENCE_COMPILATION_CONDITION_$(PLANET_ENABLE_APPLE_INTELLIGENCE)) $(PLANET_AI_CHAT_SCROLL_MANAGEMENT_COMPILATION_CONDITION_$(PLANET_ENABLE_AI_CHAT_SCROLL_MANAGEMENT))
```

When `PLANET_ENABLE_APPLE_INTELLIGENCE` is `YES`, Swift receives `-D PLANET_ENABLE_APPLE_INTELLIGENCE`. When it is `NO`, the mapped condition is empty and the Apple Intelligence code is compiled out.

When `PLANET_ENABLE_AI_CHAT_SCROLL_MANAGEMENT` is `YES`, Swift receives `-D PLANET_ENABLE_AI_CHAT_SCROLL_MANAGEMENT`. When it is `NO`, the AI chat window does not install the AppKit scroll observer, does not restore a saved scroll target, and does not request bottom pinning as messages stream in.

Local builds can override the setting in `Planet/local.xcconfig`:

```xcconfig
PLANET_ENABLE_APPLE_INTELLIGENCE = NO
PLANET_ENABLE_AI_CHAT_SCROLL_MANAGEMENT = YES
```

`local.xcconfig` is included by both Debug and Release xcconfigs and is ignored by Git, so it is the right place for developer-machine choices.

## Swift Facade

`FeatureFlags.swift` centralizes runtime checks:

```swift
enum FeatureFlags {
    #if PLANET_ENABLE_APPLE_INTELLIGENCE
    static let appleIntelligenceSupport = true
    #else
    static let appleIntelligenceSupport = false
    #endif
}
```

Use `FeatureFlags` in ordinary app logic:

```swift
guard FeatureFlags.appleIntelligenceSupport else {
    isOnDeviceAIAvailable = false
    return
}
```

Use raw `#if` only where code must be completely removed from compilation, especially imports, SDK symbols, macros, protocols, and framework-specific types:

```swift
#if PLANET_ENABLE_APPLE_INTELLIGENCE && canImport(FoundationModels)
import FoundationModels
#endif
```

## Apple Intelligence Gating

Apple Intelligence support currently has three layers:

1. Build-time flag: `PLANET_ENABLE_APPLE_INTELLIGENCE`.
2. SDK check: `canImport(FoundationModels)`.
3. Runtime OS/model check: `#available(macOS 26.0, *)` plus `SystemLanguageModel.default.availability`.

All three are required. This keeps Planet buildable for macOS 12 deployment, while still allowing macOS 26-only FoundationModels code when the SDK and build flag allow it.

## Adding a New Build-Time Flag

1. Add a build setting and `YES`/`NO` mapping in both `Planet.xcconfig` and `Release.xcconfig`:

   ```xcconfig
   PLANET_ENABLE_EXAMPLE_FEATURE = YES
   PLANET_EXAMPLE_FEATURE_COMPILATION_CONDITION_YES = PLANET_ENABLE_EXAMPLE_FEATURE
   PLANET_EXAMPLE_FEATURE_COMPILATION_CONDITION_NO =
   ```

2. Append the mapped condition to the existing `SWIFT_ACTIVE_COMPILATION_CONDITIONS` assignment:

   ```xcconfig
   SWIFT_ACTIVE_COMPILATION_CONDITIONS = $(inherited) $(PLANET_APPLE_INTELLIGENCE_COMPILATION_CONDITION_$(PLANET_ENABLE_APPLE_INTELLIGENCE)) $(PLANET_EXAMPLE_FEATURE_COMPILATION_CONDITION_$(PLANET_ENABLE_EXAMPLE_FEATURE))
   ```

3. Add a typed property to `FeatureFlags.swift`.

4. Use `FeatureFlags.exampleFeature` for normal runtime branching.

5. Use `#if PLANET_ENABLE_EXAMPLE_FEATURE` around imports and symbols that cannot appear in disabled builds.

6. If the feature depends on newer APIs, keep `#available` checks even when the build flag is enabled.

7. Document the new setting in `README.md` and this technote.

## Notes

- Build-time flags are fixed at compile time. Use `UserDefaults` or app settings for user-togglable behavior.
- Do not use `DEBUG` as a feature flag unless the feature truly means Debug-only.
- If disabling a feature must also remove linked frameworks, package products, entitlements, or bundle resources, a separate target/configuration may be needed. Swift `#if` only removes Swift source from compilation.
- When modifying `Planet.xcodeproj/project.pbxproj`, use the `xcodeproj` Ruby gem rather than editing the project file manually.
