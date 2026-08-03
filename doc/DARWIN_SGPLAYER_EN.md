# iOS / macOS SGPlayer Integration (Darwin)

`kinetic_player` uses the same SGPlayer integration on **iOS** and **macOS** (`sharedDarwinSource`):

- Source: `darwin/kinetic_player/Sources/` (`SgPlayerKit`, `SgNativePlayerBridge`, `kinetic_player`)
- Scripts: `darwin/scripts/sgplayer/` (shared entry, with parameters `ios` | `macos`)
- Artifacts: `darwin/Frameworks/{ios,macos}/SGPlayer.xcframework`
- Manifests: `darwin/sgplayer/manifest.{ios,macos}.json`
- Config: `darwin/kinetic_player/Package.swift`, `darwin/kinetic_player.podspec`

Core: [wanwenfeng4798/SGPlayer](https://github.com/wanwenfeng4798/SGPlayer) (**master**)

## Platform comparison

| Item | iOS | macOS |
|---|---|---|
| Minimum OS | iOS 13 | **macOS 11** (SF Symbols in the control bar) |
| Dart view | `UiKitView` | `AppKitView` |
| Artifact | `darwin/Frameworks/ios/SGPlayer.xcframework` | `darwin/Frameworks/macos/SGPlayer.xcframework` |
| Manifest | `darwin/sgplayer/manifest.ios.json` | `darwin/sgplayer/manifest.macos.json` |
| Release asset | `SGPlayer.xcframework.zip` | `SGPlayer-macOS.xcframework.zip` |
| Release tag | `sgplayer-v1.0.0` | `sgplayer-macos-v1.0.0` |
| Local build | `./build.sh iOS` + scheme `SGPlayer iOS` | `./build.sh macOS` + scheme `SGPlayer macOS` |
| Simulator | ❌ (FFmpeg prebuilt is arm64 device-only) | ✅ (macosx arm64 + x86_64) |
| PiP | ❌ | ❌ |
| Outbound network (Example) | ATS / system network | App Sandbox needs `com.apple.security.network.client` |

Other capabilities (bottom bar, audio tracks, cover, SG API) are shared; **pan gestures are iOS-only** (macOS uses the progress slider + speaker/gear buttons — see [USAGE_EN.md](USAGE_EN.md)). Android-only: [GSY_FEATURES_EN.md](GSY_FEATURES_EN.md). Web: [WEB_ARTPLAYER_EN.md](WEB_ARTPLAYER_EN.md).

## Directory layout

```text
darwin/
  kinetic_player.podspec     ← single CocoaPods (ios + osx)
  kinetic_player/
    Package.swift            ← single SPM (both platforms + conditional binaryTargets)
    Sources/
      kinetic_player/        ← KineticPlayerPlugin + PrivacyInfo
      SgPlayerKit/           ← Swift UI / playback
      SgNativePlayerBridge/  ← ObjC bridge
  scripts/sgplayer/          ← shared bash (build / download / ensure / generate / package / prebuild)
  sgplayer/
    manifest.ios.json
    manifest.macos.json
  Frameworks/
    ios/SGPlayer.xcframework
    macos/SGPlayer.xcframework
  third_party/SGPlayer/      ← source clone used for local build (gitignored)
```

`pubspec.yaml` sets `sharedDarwinSource: true` for both iOS and macOS; there is no separate `ios/` or `macos/` plugin tree.

## Unified invocation (maintainers)

```bash
bash darwin/scripts/sgplayer/<script>.sh ios|macos
# Package.swift is generated once by generate_package_swift.sh (reads both manifests)
```

## Can we commit `xcframework` into Git?

| Method | Recommended? | Notes |
|---|---|---|
| Commit to `main` | ❌ Not recommended | GitHub hard limit (single file) ~100 MiB; artifact is much larger |
| **GitHub Release asset** | ✅ **Recommended** | Single asset can be up to 2 GiB |
| Git LFS | ⚠️ Optional | bandwidth quota |

Conclusion: put zip into **Release**, and set `download_url` / `sha256` in the corresponding manifest.

## Users: Get prebuilt binaries

Both platforms follow the same workflow; only change the platform argument: `ios` or `macos`.

### Method A — SPM (recommended, works from pub.dev)

1. App `pubspec.yaml`:

```yaml
dependencies:
  kinetic_player: ^2.0.1   # or path / git

flutter:
  config:
    enable-swift-package-manager: true
```

2. Run `flutter pub get` then `flutter run`.
   - The package already ships `Package.swift` (remote `binaryTarget`) and SPM sources
   - Xcode downloads `SGPlayer.xcframework` when resolving the package
   - **No** host Scheme Pre-action / extra scripts
   - macOS: set `MACOSX_DEPLOYMENT_TARGET` to **11.0+** (matches plugin `Package.swift`)

### Method B — Maintainer manual / CI (update manifests / Frameworks)

After updating Release assets or manifests:

```bash
bash darwin/scripts/sgplayer/spm_prebuild_hook.sh ios
bash darwin/scripts/sgplayer/spm_prebuild_hook.sh macos
```

Only ensure (do not rewrite `Package.swift`):

```bash
bash darwin/scripts/sgplayer/ensure_sgplayer.sh ios
bash darwin/scripts/sgplayer/ensure_sgplayer.sh macos
```

`ensure` order:

1. If `darwin/Frameworks/<platform>/SGPlayer.xcframework` exists → skip build
2. Read `download_url` from the manifest → download and unzip
3. If not configured or download fails → build from source (first time: ~30–60 minutes)

Edit Swift / ObjC directly under `darwin/kinetic_player/Sources/` (single copy); no mirror sync step.

### Method C — Set URL via environment variable

```bash
export KINETIC_PLAYER_SGPLAYER_DOWNLOAD_URL="https://github.com/wanwenfeng4798/kinetic_player/releases/download/sgplayer-v1.0.0/SGPlayer.xcframework.zip"
bash darwin/scripts/sgplayer/ensure_sgplayer.sh ios
```

### Method D — CocoaPods

When SPM is disabled, `darwin/kinetic_player.podspec` `prepare_command` runs `ensure` for ios and macos; `vendored_frameworks` points to `Frameworks/{ios,macos}/...`. End users only need `pod install` (or Flutter build).

### Method E — Local build

```bash
bash darwin/scripts/sgplayer/build_sgplayer.sh ios
bash darwin/scripts/sgplayer/build_sgplayer.sh macos

# Clean (iOS clears third_party + artifacts; macOS only clears that platform Frameworks)
bash darwin/scripts/sgplayer/build_sgplayer.sh ios clean
bash darwin/scripts/sgplayer/build_sgplayer.sh macos clean
```

## Maintainers: Publish prebuilt packages

### 1. Build

```bash
bash darwin/scripts/sgplayer/build_sgplayer.sh ios    # → darwin/Frameworks/ios/
bash darwin/scripts/sgplayer/build_sgplayer.sh macos  # → darwin/Frameworks/macos/
```

### 2. Package and write back manifests + `Package.swift`

```bash
bash darwin/scripts/sgplayer/package_sgplayer_release.sh ios
bash darwin/scripts/sgplayer/package_sgplayer_release.sh macos
```

Output examples:

- iOS: `darwin/Frameworks/ios/SGPlayer.xcframework.zip` + `.sha256`, update `manifest.ios.json`, rewrite unified `darwin/kinetic_player/Package.swift`
- macOS: `darwin/Frameworks/macos/SGPlayer-macOS.xcframework.zip` + `.sha256`, update `manifest.macos.json`, rewrite unified `darwin/kinetic_player/Package.swift`

### 3. Create GitHub Release

```bash
gh release create sgplayer-v1.0.0 \
  darwin/Frameworks/ios/SGPlayer.xcframework.zip \
  --repo wanwenfeng4798/kinetic_player \
  --title "SGPlayer iOS prebuilt v1.0.0"

gh release create sgplayer-macos-v1.0.0 \
  darwin/Frameworks/macos/SGPlayer-macOS.xcframework.zip \
  --repo wanwenfeng4798/kinetic_player \
  --title "SGPlayer macOS prebuilt v1.0.0"
```

### 4. Commit (do NOT commit the zip)

- `darwin/sgplayer/manifest.ios.json` / `manifest.macos.json`
- `darwin/kinetic_player/Package.swift`

### 5. Validate download

```bash
rm -rf darwin/Frameworks/ios/SGPlayer.xcframework
bash darwin/scripts/sgplayer/download_sgplayer.sh ios
ls darwin/Frameworks/ios/SGPlayer.xcframework
```

If you manually update the manifest:

```bash
bash darwin/scripts/sgplayer/generate_package_swift.sh
```

## Manifest fields

| Field | Description |
|---|---|
| `version` | Prebuilt version, corresponds to the Release tag |
| `sgplayer_branch` | SGPlayer branch (local build) |
| `sgplayer_repository` | SGPlayer git repository URL |
| `asset_name` | Release asset file name |
| `download_url` | HTTPS download URL; empty means skip download and build locally |
| `sha256` | zip SHA256 (same as `swift package compute-checksum`) |

## SPM notes (sharedDarwinSource)

Flutter symlinks `darwin/kinetic_player` into `ephemeral/Packages`. Therefore:

- All sources and `Package.swift` live under that package root (single copy)
- `Package.swift` declares `SGPlayer_iOS` / `SGPlayer_macOS` remote `binaryTarget`s with platform conditions
- Package-local `SGPlayer.xcframework` is only for local / CocoaPods fallback and stays `.gitignore`d; SPM consumers use the remote `binaryTarget`

Swift target structure: `SgNativePlayerBridge` (ObjC) + `kinetic_player` (includes `SgPlayerKit` Swift sources, depends on `FlutterFramework`). Intermediate standalone Swift targets do not receive Flutter framework search paths.

## Platform view API (iOS vs macOS)

Both iOS and macOS support Flutter platform views, but the native API shapes are different:

| | iOS | macOS |
|---|---|---|
| Protocol | `FlutterPlatformView` | no same-named protocol |
| Factory returns | `FlutterPlatformView` | **`NSView`** |
| Create method | `create(withFrame:viewIdentifier:arguments:)` | `create(withViewIdentifier:arguments:)` |

Implementation: `darwin/.../SgVideoPlatformView.swift` (`#if os` branches).

## Example notes

- **macOS**: `DebugProfile.entitlements` / `Release.entitlements` must include `com.apple.security.network.client`, otherwise sandbox outbound network fetch fails.
- **macOS deployment**: plugin + Example are **11.0**; host apps should set `MACOSX_DEPLOYMENT_TARGET = 11.0` (if Flutter’s generated `FlutterGeneratedPluginSwiftPackage` is still 10.15, raising the host deployment target usually aligns it).
- `Failed to foreground app; open returned 1`: usually Flutter failing to bring the app to foreground; try opening via Dock. Usually unrelated to playback.

## Third-party licensing

SGPlayer follows the license of [wanwenfeng4798/SGPlayer](https://github.com/wanwenfeng4798/SGPlayer); this plugin is MIT.

