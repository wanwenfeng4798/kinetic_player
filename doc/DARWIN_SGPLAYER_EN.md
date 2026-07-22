# iOS / macOS SGPlayer Integration (Darwin)

`kinetic_player` uses the same SGPlayer integration approach on **iOS** and **macOS**:

- Source code: `darwin/SgNativePlayerBridge`, `darwin/kinetic_player/Sources/SgPlayerKit`
- Scripts: `darwin/scripts/sgplayer/` (shared entry, with parameters `ios` | `macos`)
- Artifacts: `darwin/Frameworks/{ios,macos}/SGPlayer.xcframework`
- Manifests: `darwin/sgplayer/manifest.{ios,macos}.json`

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

Other capabilities (bottom bar, gestures, audio tracks, cover, SG API) are shared; see [USAGE_EN.md](USAGE_EN.md).

## Directory layout

```text
darwin/
  scripts/sgplayer/          ← shared bash (build / download / ensure / generate / package / prebuild)
  sgplayer/
    manifest.ios.json
    manifest.macos.json
  Frameworks/
    ios/SGPlayer.xcframework
    macos/SGPlayer.xcframework
  third_party/SGPlayer/      ← source clone used for local build (gitignored)
  SgNativePlayerBridge/      ← ObjC bridge (UIKit / AppKit)
  kinetic_player/Sources/SgPlayerKit/   ← shared Swift UI / playback logic

ios/kinetic_player/          ← Package.swift + KineticPlayerPlugin (+ PrivacyInfo)
macos/kinetic_player/        ← Package.swift + KineticPlayerPlugin
ios/kinetic_player.podspec   ← CocoaPods (prepare → ensure ios)
macos/kinetic_player.podspec ← CocoaPods (prepare → ensure macos)
```

## Unified invocation

```bash
bash darwin/scripts/sgplayer/<script>.sh ios|macos
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

### Method A — SPM + Pre-build hook (recommended)

1. In your app and plugin `pubspec.yaml`:

```yaml
flutter:
  config:
    enable-swift-package-manager: true
```

2. In the host app's Xcode Scheme → **Build → Pre-actions** (place it **before** Flutter `prepare`):

```bash
/bin/bash "${SRCROOT}/scripts/run_kinetic_sgplayer_prebuild.sh"
```

- Example is already configured: `example/ios/scripts/`, `example/macos/scripts/`
- Host app can copy the script; Pre-action requires you to enable **Provide build settings from** → Runner (otherwise `${SRCROOT}` is empty)

3. The hook will:

1. Generate `{ios|macos}/kinetic_player/Package.swift` based on `darwin/sgplayer/manifest.<platform>.json`
2. `ensure_sgplayer`: if artifacts exist → skip; otherwise download; if it fails → build locally
3. Sync shared Swift/ObjC sources + local xcframework into the SPM package directory
   (Flutter will symlink packages into `ephemeral/Packages`; relative paths outside the package root won’t work)

### Method B — Manual / CI

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

1. If `darwin/Frameworks/<platform>/SGPlayer.xcframework` exists → skip build, but still sync local SPM copies
2. Read `download_url` from the manifest → download and unzip
3. If not configured or download fails → build from source (first time: ~30–60 minutes)

### Method C — Set URL via environment variable

```bash
export KINETIC_PLAYER_SGPLAYER_DOWNLOAD_URL="https://github.com/wanwenfeng4798/kinetic_player/releases/download/sgplayer-v1.0.0/SGPlayer.xcframework.zip"
bash darwin/scripts/sgplayer/ensure_sgplayer.sh ios
```

### Method D — CocoaPods

When SPM is disabled, `ios/kinetic_player.podspec` / `macos/kinetic_player.podspec` `prepare_command` will call `ensure_sgplayer.sh`; `vendored_frameworks` points to `../darwin/Frameworks/{ios,macos}/...`.

### Method E — Local build

```bash
bash darwin/scripts/sgplayer/build_sgplayer.sh ios
bash darwin/scripts/sgplayer/build_sgplayer.sh macos

# Clean (iOS clears third_party + artifacts; macOS only clears that platform Frameworks)
bash darwin/scripts/sgplayer/build_sgplayer.sh ios clean
bash darwin/scripts/sgplayer/build_sgplayer.sh macos clean
```

## Host app: Pre-action hook

| Platform | Copy script | Optional env var |
|---|---|---|
| iOS | `example/ios/scripts/run_kinetic_sgplayer_prebuild.sh` → `your_app/ios/scripts/` | `KINETIC_PLAYER_IOS_DIR` |
| macOS | `example/macos/scripts/run_kinetic_sgplayer_prebuild.sh` → `your_app/macos/scripts/` | `KINETIC_PLAYER_MACOS_DIR` |

Resolution order: env var → path dependency next to `../../{ios|macos}` → `.flutter-plugins-dependencies`.

The macOS Example Pre-action also bumps the minimum version of `FlutterGeneratedPluginSwiftPackage` to **11.0** to match this plugin’s `Package.swift`.

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

- iOS: `darwin/Frameworks/ios/SGPlayer.xcframework.zip` + `.sha256`, update `manifest.ios.json`, and `ios/kinetic_player/Package.swift`
- macOS: `darwin/Frameworks/macos/SGPlayer-macOS.xcframework.zip` + `.sha256`, update `manifest.macos.json`, and `macos/kinetic_player/Package.swift`

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
- `ios/kinetic_player/Package.swift` / `macos/kinetic_player/Package.swift`

### 5. Validate download

```bash
rm -rf darwin/Frameworks/ios/SGPlayer.xcframework
bash darwin/scripts/sgplayer/download_sgplayer.sh ios
ls darwin/Frameworks/ios/SGPlayer.xcframework
```

If you manually update the manifest:

```bash
bash darwin/scripts/sgplayer/generate_package_swift.sh ios
bash darwin/scripts/sgplayer/generate_package_swift.sh macos
```

## Manifest fields

| Field | Description |
|---|---|
| `version` | Prebuilt version, corresponds to the Release tag |
| `sgplayer_branch` | SGPlayer branch (local build) |
| `sgplayer_repository` | SGPlayer git repository URL |
| `asset_name` | Release asset file name |
| `download_url` | HTTPS download URL; empty means skip download and build locally (macOS local fallback: SPM uses package-local `SGPlayer.xcframework` path) |
| `sha256` | zip SHA256 (same as `swift package compute-checksum`) |

## SPM package sync notes

Flutter will symlink `{ios|macos}/kinetic_player` into `ephemeral/Packages`. Therefore:

- `Package.swift` `binaryTarget` / `target.path` **must not** use paths outside the package root (e.g. `../../darwin/...`)
- `ensure_sgplayer` syncs `SgPlayerKit`, `SgNativePlayerBridge`, and (local path mode) the xcframework **into** the package’s `Sources/` / `SGPlayer.xcframework`
- These synced copies are `.gitignore`d; please only modify authoritative sources under `darwin/`, then run ensure / prebuild again

Swift target structure: `SgNativePlayerBridge` (ObjC) + `kinetic_player` (includes synced `SgPlayerKit` Swift sources, depends on `FlutterFramework`). Intermediate standalone Swift targets do not receive Flutter framework search paths.

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
- **macOS deployment**: plugin + Example are **11.0**; if Flutter generated packages are still 10.15, the Example Pre-action will bump to 11.0.
- `Failed to foreground app; open returned 1`: usually Flutter failing to bring the app to foreground; try opening via Dock. Usually unrelated to playback.

## Third-party licensing

SGPlayer follows the license of [wanwenfeng4798/SGPlayer](https://github.com/wanwenfeng4798/SGPlayer); this plugin is MIT.

