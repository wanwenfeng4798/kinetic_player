# Usage Guide

Chinese version: [USAGE.md](USAGE.md)

Minimum SDK: **Dart 3.13 / Flutter 3.47**. Host apps should depend on `material_ui: ^1.8.0` and `import 'package:material_ui/material_ui.dart'` (do not `import package:flutter/material.dart`).

> 3.0: Darwin uses SGPlayer 2 native controls (iOS 15 / macOS 12). Runtime localization and per-button styling are not exposed by the SDK. See [Darwin integration](DARWIN_SGPLAYER_EN.md) for setup and migration.

## Architecture Overview

```
Dart layer
  CommonVideoController          ← Public API
  CommonVideoPlayerView          ← Platform view
  CommonVideoPlayerFactory       ← Android→GSY / iOS·macOS→SG / Web→Artplayer / Windows·Linux→libmpv
       │
       ├── GSYVideoControllerImpl        (Android-only)
       ├── SGVideoControllerImpl         (iOS / macOS-only)
       ├── ArtplayerVideoControllerImpl  (Web-only)
       └── MpvVideoControllerImpl        (Windows / Linux-only)
```

## Backend selection

Keep the default auto-selection. **Windows / Linux use built-in libmpv**; see [DESKTOP_MPV_EN.md](DESKTOP_MPV_EN.md).

| Target platforms | Backend | When to choose |
|---|---|---|
| Android | GSYVideoPlayer | Default |
| iOS / macOS | SGPlayer | Default |
| Web | Artplayer.js | Default |
| **Windows / Linux** | **libmpv** | Default |

If you need a GStreamer pipeline, the separate [GstPlayer](https://pub.dev/packages/gstplayer) package is still available.

Channel / view names:

- Android GSY: `com.example.player/gsy_<viewId>` / `gsy_view_ui` (`AndroidView`)
- iOS / macOS SG: `com.example.player/sg_<viewId>` / `sg_view_ui` (`UiKitView` / `AppKitView`)
- Web Artplayer: in-process `ArtplayerViewRegistry` / `art_view_ui` (`HtmlElementView`)
- Windows / Linux libmpv: `com.example.player/mpv` + `mpv_<viewId>` / `mpv_view_ui` (`Texture`)

## Integration

### pubspec.yaml

```yaml
dependencies:
  kinetic_player:
    path: ../kinetic_player

flutter:
  config:
    enable-swift-package-manager: true   # Recommended for iOS
```

### Android

No extra steps are required. GSYVideoPlayer pulls dependencies automatically via Gradle Maven:

- `io.github.carguo:gsyvideoplayer-java:14.0.0`
- `io.github.carguo:gsyvideoplayer-exo2:14.0.0`
- `io.github.carguo:gsyvideoplayer-arm64:14.0.0`

**Picture-in-Picture (PiP)** requires declaring the host activity in `AndroidManifest.xml`:

```xml
<activity
    android:name=".MainActivity"
    android:resizeableActivity="true"
    android:supportsPictureInPicture="true"
    android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
    ... />
```

> Note: do not use `pictureInPictureMode` inside `configChanges`. Current AAPT does not support that flag. Existing flags like `screenSize|screenLayout` are enough for PiP.

Forward lifecycle events in your Activity (Example is already configured):

```kotlin
override fun onConfigurationChanged(newConfig: Configuration) {
  super.onConfigurationChanged(newConfig)
  KineticPlayerPlugin.handleConfigurationChanged(this, newConfig)
}

override fun onBackPressed() {
  if (KineticPlayerPlugin.handleBackPressed(this)) return
  super.onBackPressed()
}

override fun onUserLeaveHint() {
  super.onUserLeaveHint()
  KineticPlayerPlugin.handleUserLeaveHint(this)  // Enter PiP when backgrounding while playing
}
```

**PiP trigger conditions** (0.0.3+):

- Video is **actually playing** (including GSY auto-play `startAfterPrepared` and native play button; not limited to Flutter `play()`)
- `pictureInPictureEnabled: true` (default)
- Device API 26+ and PiP supported
- Android 8–11: depends on `onUserLeaveHint`
- Android 12+: also auto-enter PiP via `PictureInPictureParams.setAutoEnterEnabled` when user leaves the Activity

Verify by pressing **Home** or switching to another app. Paused state will not enter PiP.

### iOS / macOS (SGPlayer, shared Darwin)

Both platforms follow the same process. See [DARWIN_SGPLAYER_EN.md](DARWIN_SGPLAYER_EN.md).

1. **Enable SPM** (recommended):

```yaml
flutter:
  config:
    enable-swift-package-manager: true
```

2. **Binaries:** Run `bash darwin/scripts/sgplayer/spm_prebuild_hook.sh ios` before first SPM resolution. CocoaPods prepares official release downloads automatically.

3. **Run**:

```bash
flutter pub get
flutter run          # iOS device
flutter run -d macos
```

> iOS Simulator is not supported (prebuilt FFmpeg is arm64 device-only).
> macOS deployment target must be **12.0+** (matches plugin `Package.swift`).
> macOS Example needs App Sandbox outbound network entitlement `com.apple.security.network.client`.
> There is no system PiP on iOS / macOS; they share the native bottom bar and SG APIs.

### Web (Artplayer.js)

No native project steps:

```bash
flutter pub get
flutter run -d chrome
```

Web-only features (plugins, HLS/DASH, Document PiP, rebuild) are in a dedicated doc — same role as GSY / Darwin docs:

- English: [WEB_ARTPLAYER_EN.md](WEB_ARTPLAYER_EN.md)
- Chinese: [WEB_ARTPLAYER.md](WEB_ARTPLAYER.md)

```dart
CommonVideoPlayerViewBuilder(
  url: videoUrl,
  creationParams: ArtplayerUiConfig(
    ui: const KineticUiConfig(
      enableNativeControls: true,
      pictureInPictureEnabled: true,
      locale: 'zh',
    ),
    artPlugins: {
      ArtplayerPluginKeys.hlsControl: true,
    },
  ).toCreationParams(),
  builder: (controller) { /* … */ },
);
```

### Windows / Linux (libmpv)

Public API is unchanged. Windows downloads the latest LGPL `libmpv-2.dll` at configure time (mpv 0.41 API); Linux needs system `libmpv-dev` / `mpv-libs-devel`. See [DESKTOP_MPV_EN.md](DESKTOP_MPV_EN.md).

```bash
flutter pub get
flutter run -d windows
flutter run -d linux
```

Hosts keep using `CommonVideoPlayerViewBuilder` + `KineticUiConfig`, same as other platforms.

## Public API

`CommonVideoController` provides:

| Method / Property | Description |
|---|---|
| `play()` | Start playback (when called again after completion, it seeks to the beginning first, then plays) |
| `pause()` | Pause |
| `stop()` | Stop and reset |
| `seekTo(Duration)` | Seek |
| `setScaleMode(CommonScaleMode)` | Scale mode |
| `setRate(double)` | Playback rate |
| `setVolume(double)` / `setMute(bool)` | Volume / mute |
| `switchVideoSource(url, {autoPlay})` | Switch source |
| `getAudioTracks()` / `selectAudioTrack(index)` | Audio track list / switch |
| `getDuration()` / `getCurrentPosition()` | Read current progress (matches `duration`/`position`) |
| `getVideoSize()` | Video size (width/height) |
| `setLooping(bool)` | Looping (Android GSY native; iOS seeks(0)+play after completion) |
| `setLocale(String)` | Chrome language (`zh` / `en` / `vi` / `ms` / `id` / `fil`; set `KineticUiConfig.locale` at create) |
| `setHttpRequestOptions(KineticHttpRequestOptions?)` | Custom User-Agent / HTTP headers (applied on next source load; also `creationParams['userAgent']` / `headers`) |
| `captureFrame({highQuality, includeOverlay})` | Screenshot PNG bytes (`Uint8List?`; Android can include UI overlay) |
| `onScreenshotCaptured` | Settings screenshot finished (PNG bytes; host saves them — plugin does not write files or Photos) |
| `dispose()` | Release |
| `playerState` | `ValueNotifier<CommonPlayerState>` |
| `position` / `duration` | Progress (native side throttles push to ~250ms) |

`CommonScaleMode`: `fit` / `fill` / `stretch`

`CommonPlayerState`: `idle` / `buffering` / `ready` / `playing` / `paused` / `completed` / `error`

`CommonAudioTrack` fields: `index`、`label`、`language`、`selected`

### HTTP headers / User-Agent (all platforms)

```dart
await controller.setHttpRequestOptions(
  const KineticHttpRequestOptions(
    userAgent: 'MyApp/1.0',
    headers: {'Authorization': 'Bearer …', 'Referer': 'https://example.com/'},
  ),
);
await controller.switchVideoSource(url);

// Or at create:
creationParams: {
  'userAgent': 'MyApp/1.0',
  'headers': {'Referer': 'https://example.com/'},
  ...ui.toCreationParams(),
}
```

- Android / iOS / macOS / Windows / Linux: applied to media requests.
- Web: progressive MP4 cannot carry custom headers; HLS/DASH inject via xhr. Browsers typically forbid overriding `User-Agent`.
- Darwin can still use `sgSetDemuxerOptions` for timeout / reconnect; UA/headers share the same pending bag as the common API.

## View components

### CommonVideoPlayerViewBuilder (recommended)

Automatically creates a PlatformView and calls back the controller when ready:

```dart
CommonVideoPlayerViewBuilder(
  url: videoUrl,
  creationParams: {
    ...const KineticUiConfig(
      enableNativeControls: true,
      showFullscreenButton: true,
      showLockButton: true,
      showVolumeToolbar: true,      // Bottom speaker button (popup vertical volume bar)
      showSettingsButton: true,     // Bottom gear button (popup settings panel; includes audio tracks)
      pictureInPictureEnabled: true, // Android PiP enabled by default
      previewVttUrl: 'https://example.com/thumbs.vtt',
      locale: 'zh', // zh / en / vi / ms / id / fil
    ).toCreationParams(),
  },
  builder: (controller) {
    // Keep controller reference
  },
)
```

Android defaults to `EagerGestureRecognizer`, so native seek/volume/brightness gestures won’t be stolen by Flutter. If you need to customize gesture competition, pass `gestureRecognizers` to override the default behavior.

### CommonVideoPlayerView (low-level)

```dart
CommonVideoPlayerView(
  url: videoUrl,
  onPlatformViewCreated: (viewId) {
    final controller = CommonVideoPlayerFactory.createAuto(viewId);
  },
)
```

## Control UI and platform boundaries

3.0 uses GSY native controls on Android and SGPlaybackControls on iOS/macOS. Windows/Linux share an independent Flutter desktop overlay; Web uses Artplayer DOM controls. Shared config and operations use KineticPlayerConfig and KineticPlayerActions. UI is not pixel-identical across these SDKs.

Darwin native controls expose control visibility, auto-hide, lock, gestures/keyboard, cover and native settings. The SDK does not expose runtime localization, theme/per-button visibility or completion-cover policy; unsupported runtime calls return UNSUPPORTED. PiP depends on each platform and host. See the Chinese USAGE audit matrix and DARWIN_SGPLAYER feature inventory for exact limits.

## Platform-only APIs (downcasting)

The public interface does not include the following methods; you must explicitly downcast:

### Android — GSYVideoControllerImpl

```dart
if (controller is GSYVideoControllerImpl) {
  await controller.gsySwitchRenderCore(1); // 0=IJK, 1=Exo, 2=System
  await controller.gsyToggleDanmaku(enabled: true);
  await controller.gsyStartFullscreen();
  await controller.gsySetPreviewVttUrl('https://example.com/thumbs.vtt');
  await controller.gsySetUiConfig(const KineticUiConfig(videoTitle: 'Demo'));
  await controller.gsyEnterPictureInPicture(); // manual PiP
  await controller.gsySetRenderRotation(90);
  await controller.gsySetMirrorHorizontal(enabled: true);
  await controller.gsySetMirrorVertical(enabled: true);
  await controller.gsySetCoverUrl('https://example.com/cover.jpg');
  await controller.gsySetKeepLastFrameWhenComplete(enabled: true);
}
```

#### Shared UI configuration (`KineticUiConfig`)

Used on Android / iOS / macOS / Web. Serialized under `creationParams['ui']`. Android can update chrome at runtime with `gsySetUiConfig` (**does not** change language).

| Field | Default | Description |
|---|---|---|
| `enableNativeControls` | `true` | Android / iOS: swipe gestures (progress/volume/brightness); Apple side also controls control bar visibility. macOS: control bar visibility only — no pans (use progress slider + speaker/gear buttons) |
| `enableNativeControlsFullscreen` | `true` | Android fullscreen gesture; Apple shares with `enableNativeControls` |
| `showFullscreenButton` | `true` | Fullscreen button |
| `showLockButton` | `true` | Lock button (Android) |
| `showVolumeToolbar` | `true` | Speaker button + vertical volume popup |
| `showSettingsButton` | `true` | Gear button + two-level settings (screenshot; Android GIF) |
| `accentColor` | `#FB7299` | Seek bar / selected-state accent |
| `pictureInPictureEnabled` | `true` | Android enters PiP automatically when backgrounding (API 26+) |
| `showDragProgressTextOnSeekBar` | `false` | Show time text while dragging seek bar |
| `previewVttUrl` | — | Seek bar thumbnail WebVTT |
| `dismissControlTime` | `2500` | Auto-hide control bar while playing (ms) |
| `videoTitle` | `''` | Title text |
| `speed` / `looping` | `1` / `false` | initial playback speed / looping |
| `keepLastFrameWhenComplete` | `false` | keep last frame after finish (does not cover the frame) |
| `coverUrl` | — | cover / poster URL |
| `thumbPlay` | `true` | tap cover to start playing (Android) |
| `ijkEnableAccurateSeek` | `true` | IJK accurate seek reduces keyframe bounce when dragging seek bar (IJK-only) |
| `cacheWithPlay` | `true` | play while caching (HttpProxyCache) |
| `locale` | `'zh'` | Chrome language: `zh` / `en` / `vi` / `ms` / `id` / `fil` |

Other GSY capabilities (filters, screenshots, GIF, subtitles, playlist, etc.) see [GSY_FEATURES_EN.md](GSY_FEATURES_EN.md).

### iOS / macOS — SGVideoControllerImpl

```dart
if (controller is SGVideoControllerImpl) {
  await controller.sgStartFullscreen();
  await controller.sgSetDisplayMode(SgDisplayMode.vrBox);
  await controller.sgSetVrViewport(const SgVrViewport(degrees: 75, sensorEnable: true));
  await controller.sgSetPitch(1.2);
  await controller.sgSetDemuxerOptions(const SgDemuxerOptions(
    timeout: Duration(seconds: 20),
    reconnect: true,
    userAgent: 'MyApp',
    headers: {'Authorization': 'Bearer …'},
  ));
  await controller.sgReplaceWithSegments([
    SgMediaSegment(url: 'https://example.com/a.mp4'),
    SgMediaSegment(url: 'https://example.com/b.mp4'),
  ]);
  await controller.sgSetBackgroundPlaybackPolicy(
    const SgBackgroundPlaybackPolicy(pausesWhenEnteredBackground: false),
  );
  final tracks = await controller.sgGetVideoTracks();
  await controller.sgSelectVideoTrack(0);
  // buffering / error
  controller.buffered;      // ValueNotifier<Duration>
  controller.playerError;   // ValueNotifier<String?>
}
```

| API | Description |
|---|---|
| `buffered` / `sgGetBufferedPosition` | Buffered progress |
| `playerError` / `sgGetLastError` | Detailed error |
| `sgSetPitch` / `sgGetPitch` | Pitch (~0.5–2.0) |
| `sgSetDisplayMode` / `sgSetVrViewport` | Plane / VR / VRBox + viewport |
| `sgSetDemuxerOptions` | FFmpeg timeout / reconnect / UA / headers |
| `sgReplaceWithSegments` | Multi-segment `SGMutableAsset` |
| `sgGetVideoTracks` / `sgSelectVideoTrack` | Video track |
| `sgSetBackgroundPlaybackPolicy` | Background / interruption policy |

`creationParams` / `ui` fields: `enableNativeControls`, `showVolumeToolbar`, `showSettingsButton`, `showFullscreenButton`, `dismissControlTime`, `pictureInPictureEnabled` (read on Apple side but not effective), `coverUrl`, `keepLastFrameWhenComplete`, `locale`.

### Windows / Linux — MpvVideoControllerImpl

```dart
if (controller is MpvVideoControllerImpl) {
  await controller.mpvStartFullscreen();
  await controller.mpvSetHwdec('auto-safe');
  await controller.mpvSetPlaylist(urls, startIndex: 0);
  await controller.mpvSetShowType(GsyShowType.ratio16x9);
  await controller.mpvCommand(['show-text', 'hello']);
}
```

| API | Description |
|-----|-------------|
| `mpvStartFullscreen` / `mpvExitFullscreen` | Host-window fullscreen |
| `mpvSetHwdec` / `mpvCommand` | hwdec / raw mpv command |
| `mpvSetRenderRotation` / `mpvSetMirrorHorizontal` | Rotate / horizontal mirror |
| `mpvSetShowType` | Matches Android `GsyShowType` |
| `mpvSetPlaylist` / `mpvPlayNextInPlaylist` | Playlist / next item |
| `mpvSetSubtitleUrl` / `mpvSetSubtitleEnabled` | External subtitles |
| `mpvListVideoTracks` / `mpvGetNetSpeed` | Video tracks / net speed |
| `mpvSetCoverUrl` / `mpvSetWatermarkUrl` / `mpvSetPurePlayMode` | Cover / watermark / chrome-off |

See [DESKTOP_MPV_EN.md](DESKTOP_MPV_EN.md).

### Web — ArtplayerVideoControllerImpl

Full plugin matrix, HLS/DASH, Document PiP, and rebuild steps: [WEB_ARTPLAYER_EN.md](WEB_ARTPLAYER_EN.md).

```dart
if (controller is ArtplayerVideoControllerImpl) {
  await controller.togglePip();
  await controller.artEmitDanmuku({'text': 'hi', 'time': 1});
  controller.pipActive;
}
```

| API | Description |
|-----|-------------|
| `togglePip()` / `artToggleDocumentPip()` | Video / Document PiP |
| `artEmitDanmuku` / `artCallPlugin` | Danmaku / plugin methods |
| `artAvailablePlugins()` / `artSetUiConfig` | Plugin keys / UI update |

## Platform differences quick check

| Capability | Android (GSY) | iOS / macOS (SGPlayer) | Web (Artplayer) |
|---|---|---|---|
| Loop | native `isLooping`; `KineticUiConfig.looping` at create | seek(0)+play; `speed`/`looping` at create | Artplayer `loop` / replay on ended |
| Screenshot overlay | `captureFrame(includeOverlay: true)` includes UI | `includeOverlay` ineffective | canvas frame (CORS may fail) |
| Settings screenshot / GIF | Screenshot (`onScreenshotCaptured`) + GIF | Screenshot (`onScreenshotCaptured`) | — |
| Switch source | rebuild player | `replaceWithURL` / `sgReplaceWithSegments` | `art.switchUrl` |
| Fullscreen | `gsyStartFullscreen()` | `sgStartFullscreen()` (in-app overlay) | Artplayer fullscreen control |
| PiP | enabled by default (manifest + `onUserLeaveHint`) | not supported | `togglePip()` / Document PiP |
| Danmaku | `gsySetDanmakuUrl` / `gsyToggleDanmaku` (incl. fullscreen) | ❌ | `artPlugins.danmuku` |
| Subtitles | `gsySetSubtitleUrl` etc. | ❌ | subtitle plugins |
| Watermark / filters / GIF / ads | see [GSY_FEATURES_EN.md](GSY_FEATURES_EN.md) | ❌ | Web plugins where applicable |
| List scroll auto-play | `GsyAutoPlayVideoList` | ❌ | app-owned |
| Audio tracks UI | gear settings panel | gear settings panel | browser `AudioTrack` when available |
| Volume UI | vertical volume popup | vertical volume popup | Artplayer volume control |
| Gesture controls | `enableNativeControls` | iOS same; macOS uses progress slider + speaker/gear buttons | Artplayer gesture (optional) |
| Render rotation / mirror | `gsySetRenderRotation` / MirrorH/V (incl. fullscreen) | `sgSetRenderRotation` / MirrorH/V | via `artplayerOptions` |
| Cover | `gsySetCoverUrl` | `sgSetCoverUrl` | `poster` / `coverUrl` |
| Keep last frame | `gsySetKeepLastFrameWhenComplete` | `sgSetKeepLastFrameWhenComplete` | browser default |
| Buffered / error details | — | `buffered` / `playerError` | `error` state |
| Deployment notes | Default IJK is arm64; host ProGuard / `handleBackPressed` | iOS device; macOS 12+; sandbox `network.client` | Chrome / Safari / mobile Web; autoplay policy |

`KineticUiConfig` fields actually applied on Darwin (SG): `enableNativeControls`, `showVolumeToolbar`, `showSettingsButton`, `showFullscreenButton`, `showLockButton`, `dismissControlTime`, `coverUrl`, `keepLastFrameWhenComplete`, `speed`, `looping`, `accentColor`, `locale`. Create-time language uses `ui.locale` / `ui.strings`; hot-swap with `setLocale`, not `gsySetUiConfig`. `pictureInPictureEnabled` is **ignored** on Apple. `previewVttUrl` / `cacheWithPlay` / rotate / `thumbPlay` are **Android-only**.

## Listeners

```dart
controller.playerState.addListener(() {
  final state = controller.playerState.value;
});

controller.position.addListener(() {
  final pos = controller.position.value;
});
```

## Notes

1. Each `CommonVideoPlayerViewBuilder` automatically releases the controller on dispose. If you manually hold a controller, dispose it when your page is disposed.
2. Android Activity should forward `onConfigurationChanged`, `onBackPressed`, `onUserLeaveHint` (see the Android integration section).
3. iOS needs device testing for SGPlayer features; macOS requires 12.0+ and outbound network entitlement.
4. Disable PiP: `KineticUiConfig(pictureInPictureEnabled: false)`.
5. Web uses Artplayer.js; platform-only details live in [WEB_ARTPLAYER_EN.md](WEB_ARTPLAYER_EN.md). Rebuild with `npm run build` after editing `web/src`.

