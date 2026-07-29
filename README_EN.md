# kinetic_player

The strongest cross-platform Flutter video player plugin for **Android / iOS / macOS / Web**.

- **Android**: [GSYVideoPlayer 13.1.0](https://github.com/CarGuo/GSYVideoPlayer)
- **iOS / macOS**: [wanwenfeng4798/SGPlayer](https://github.com/wanwenfeng4798/SGPlayer) (**master**)
- **Web**: [Artplayer.js 5.4.0](https://artplayer.org)

Repo: [github.com/wanwenfeng4798/kinetic_player](https://github.com/wanwenfeng4798/kinetic_player)

## Features

- Unified `CommonVideoController` API (play / pause / seek / scale / rate / volume / tracks / loop / screenshot / etc.)
- Platform auto-selection: Android → GSY, iOS / macOS → SGPlayer, Web → Artplayer
- Bilibili-style native control bar (vertical volume popup with percentage while dragging, settings panel for audio tracks, consistent progress bar + bottom bar icon sizing)
- iOS / macOS native gesture controls (seek / brightness / volume) with the shared `enableNativeControls` flag
- Android Picture-in-Picture (PiP) **enabled by default** (API 26+)
- Web: Video / Document PiP, HLS/DASH, official Artplayer plugins (danmaku / subtitles / Chromecast / …)
- Private platform-only APIs via explicit downcasting (does not pollute the public interface)
- iOS / macOS integrate via both **CocoaPods** and **Swift Package Manager (SPM)**, with scripts and artifacts unified under `darwin/`
- Prebuilt `SGPlayer.xcframework` download via **GitHub Release** (avoid local building)

## Docs

| Document | Description |
|---|---|
| [doc/USAGE_EN.md](doc/USAGE_EN.md) | Integration steps, public API, native UI, platform differences |
| [doc/GSY_FEATURES_EN.md](doc/GSY_FEATURES_EN.md) | Android GSY advanced capability matrix |
| [doc/DARWIN_SGPLAYER_EN.md](doc/DARWIN_SGPLAYER_EN.md) | iOS / macOS SGPlayer binaries, scripts, SPM, Release |
| [doc/WEB_ARTPLAYER_EN.md](doc/WEB_ARTPLAYER_EN.md) | Web Artplayer plugins, HLS/DASH, Web-only APIs, rebuild |
| [doc/EXAMPLE_EN.md](doc/EXAMPLE_EN.md) | Example app notes |

## Quick Start

### 1. Add dependency

```yaml
dependencies:
  kinetic_player:
    path: ../kinetic_player   # or pub.dev / git reference
```

### 2. Enable Apple SPM (recommended for iOS / macOS)

In your app and the plugin `pubspec.yaml`:

```yaml
flutter:
  config:
    enable-swift-package-manager: true
```

### 3. Prepare SGPlayer binaries (iOS / macOS)

See [doc/DARWIN_SGPLAYER_EN.md](doc/DARWIN_SGPLAYER_EN.md).

**SPM (recommended):** Xcode downloads the remote `binaryTarget` via `Package.swift`. The Example Scheme Pre-action then runs the hook to sync checksum and local artifacts.

**Manual / CI:**

```bash
bash kinetic_player/darwin/scripts/sgplayer/spm_prebuild_hook.sh ios
bash kinetic_player/darwin/scripts/sgplayer/spm_prebuild_hook.sh macos
```

**Or** CocoaPods: `pod install` triggers `prepare_command` which calls `ensure_sgplayer.sh`.

**Fallback: local build** (first time only, ~30–60 minutes)

```bash
bash kinetic_player/darwin/scripts/sgplayer/build_sgplayer.sh ios
bash kinetic_player/darwin/scripts/sgplayer/build_sgplayer.sh macos
```

### 4. Minimal example

```dart
import 'package:kinetic_player/kinetic_player.dart';

CommonVideoPlayerViewBuilder(
  url: 'https://example.com/video.mp4',
  creationParams: const GsyUiConfig(
    showVolumeToolbar: true,
    showSettingsButton: true,
    pictureInPictureEnabled: true, // Android only
  ).toCreationParams(),
  builder: (controller) {
    // controller is CommonVideoController; you can downcast per platform if needed.
  },
);
```

Complete example: [doc/EXAMPLE_EN.md](doc/EXAMPLE_EN.md) and the `example/` directory.

## HDR test links

To avoid duplicated maintenance, HDR test streams are maintained in dedicated docs:

- Chinese: [doc/HDR_TEST_LINKS.md](doc/HDR_TEST_LINKS.md)
- English: [doc/HDR_TEST_LINKS_EN.md](doc/HDR_TEST_LINKS_EN.md)

## Platform support

| Platform | Core | Device / desktop | Simulator / browser | PiP |
|---|---|---|---|---|
| Android | GSYVideoPlayer 13.1.0 | ✅ | ✅ | ✅ (enabled by default) |
| iOS | SGPlayer master | ✅ | ❌ (prebuilt FFmpeg is arm64 only) | ❌ |
| macOS | SGPlayer master | ✅ | ✅ (macosx xcframework) | ❌ |
| Web | Artplayer.js 5.4.0 | — | ✅ Chrome / Safari / mobile Web | ✅ Video PiP; Document PiP optional |

## License

This plugin code is under the [MIT License](LICENSE).

SGPlayer is a standalone third-party project; its license follows the [wanwenfeng4798/SGPlayer](https://github.com/wanwenfeng4798/SGPlayer) repository (fork from libobjc/SGPlayer).

