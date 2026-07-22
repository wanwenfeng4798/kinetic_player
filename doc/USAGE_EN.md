# Usage Guide

## Architecture Overview

```
Dart layer
  CommonVideoController          ← Public API
  CommonVideoPlayerView          ← Native platform view
  CommonVideoPlayerFactory       ← Auto selection: Android→GSY / iOS·macOS→SG
       │
       ├── GSYVideoControllerImpl   (Android-only)
       └── SGVideoControllerImpl    (iOS / macOS-only)
```

Channel names:

- Android GSY: `com.example.player/gsy_<viewId>`
- iOS / macOS SG: `com.example.player/sg_<viewId>`

PlatformView types:

- Android: `com.example.player/gsy_view_ui` (`AndroidView`)
- iOS: `com.example.player/sg_view_ui` (`UiKitView`)
- macOS: `com.example.player/sg_view_ui` (`AppKitView`)

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

- `io.github.carguo:gsyvideoplayer-java:13.1.0`
- `io.github.carguo:gsyvideoplayer-exo2:13.1.0`
- `io.github.carguo:gsyvideoplayer-arm64:13.1.0`

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

2. **Prepare binaries** (either one):

```bash
bash darwin/scripts/sgplayer/spm_prebuild_hook.sh ios
bash darwin/scripts/sgplayer/spm_prebuild_hook.sh macos
```

- SPM: `Package.swift` remote `binaryTarget(url:checksum:)` (downloaded when Xcode resolves the package)
- Example calls the hook via Scheme **Pre-action** (sync `Package.swift` + `ensure_sgplayer`)
- CocoaPods: `prepare_command` calls `ensure_sgplayer.sh` as well

3. **Run**:

```bash
flutter pub get
flutter run          # iOS device
flutter run -d macos
```

> iOS Simulator is not supported (prebuilt FFmpeg is arm64 device-only).
> Host App must add the Pre-action; see [DARWIN_SGPLAYER_EN.md](DARWIN_SGPLAYER_EN.md).
> macOS Example needs App Sandbox outbound network entitlement `com.apple.security.network.client`.
> There is no system PiP on iOS / macOS; they share the native bottom bar and SG APIs.

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
| `captureFrame({highQuality, includeOverlay})` | Screenshot (Android can include UI overlay) |
| `dispose()` | Release |
| `playerState` | `ValueNotifier<CommonPlayerState>` |
| `position` / `duration` | Progress (native side throttles push to ~250ms) |

`CommonScaleMode`: `fit` / `fill` / `stretch`

`CommonPlayerState`: `idle` / `buffering` / `ready` / `playing` / `paused` / `completed` / `error`

`CommonAudioTrack` fields: `index`、`label`、`language`、`selected`

## View components

### CommonVideoPlayerViewBuilder (recommended)

Automatically creates a PlatformView and calls back the controller when ready:

```dart
CommonVideoPlayerViewBuilder(
  url: videoUrl,
  creationParams: const GsyUiConfig(
    enableNativeControls: true,
    showFullscreenButton: true,
    showLockButton: true,
    showVolumeToolbar: true,      // Bottom speaker button (popup vertical volume bar)
    showSettingsButton: true,     // Bottom gear button (popup settings panel; includes audio tracks)
    pictureInPictureEnabled: true, // Android PiP enabled by default
    previewVttUrl: 'https://example.com/thumbs.vtt',
  ).toCreationParams(),
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

## Native control bar UI (aligned across platforms)

Android (GSY) and iOS / macOS (SGPlayer) both use a Bilibili-style native bottom control bar with consistent progress/volume track colors (`#4DE8B5` progress and semi-transparent white track).

| Capability | Android | iOS / macOS | Configuration |
|---|---|---|---|
| Center play/pause | ✅ | ✅ | `enableNativeControls` |
| Progress bar + time | ✅ | ✅ | Native default |
| Tap to show/hide controls | ✅ | ✅ | Tap blank area; auto-hide after ~2.5s while playing |
| **Volume** | ✅ | ✅ | Tap **speaker** to pop up vertical volume bar; while dragging show percentage on the **left** of the slider (e.g. `50%`); hide when release |
| **Gestures** | ✅ | ✅ | `enableNativeControls`: horizontal seek; left half brightness; right half volume |
| **Audio tracks** | ✅ | ✅ | Tap **gear (settings)** to open the panel; or use Dart `getAudioTracks` / `selectAudioTrack` |
| Fullscreen | ✅ | ✅ | Fullscreen button (same size as settings/volume icons, 28dp) / `gsyStartFullscreen()` / `sgStartFullscreen()` |
| Picture-in-Picture PiP | ✅ default | ❌ not supported | `pictureInPictureEnabled` (Android only) |

> **Volume (Android)**: when `showVolumeToolbar` is enabled, the right-side slider adjusts **player volume** (same source as the speaker popup), instead of the system volume slider. While the volume popup is open or dragging the slider, the right-side volume slider is temporarily disabled to avoid conflicts.

> **Volume (iOS / macOS)**: the right-side slider also adjusts player volume (similar sensitivity to Android GSY, about 3×). While the volume popup is open or dragging, the right-side volume slider is disabled as well.

> **Volume persistence**: volume set via slider or `setVolume()` is restored on pause/resume, replay after completion, and switching sources.

> **Audio tracks**: select tracks in the settings panel (gear) or via Flutter `selectAudioTrack` (not in the volume popup).

> **PiP**: SGPlayer uses custom rendering, so it cannot integrate with system `AVPictureInPictureController`. iOS / macOS PiP is currently not supported.

### Touch area notes

After the control bar is hidden, the bottom transparent area will not intercept taps, so you can tap the bottom-right corner and other areas to show/hide the controls and center play button.

## Platform-only APIs (downcasting)

The public interface does not include the following methods; you must explicitly downcast:

### Android — GSYVideoControllerImpl

```dart
if (controller is GSYVideoControllerImpl) {
  await controller.gsySwitchRenderCore(1); // 0=IJK, 1=Exo, 2=System
  await controller.gsyToggleDanmaku(enabled: true);
  await controller.gsyStartFullscreen();
  await controller.gsySetPreviewVttUrl('https://example.com/thumbs.vtt');
  await controller.gsySetUiConfig(const GsyUiConfig(videoTitle: 'Demo'));
  await controller.gsyEnterPictureInPicture(); // manual PiP
  await controller.gsySetRenderRotation(90);
  await controller.gsySetMirrorHorizontal(enabled: true);
  await controller.gsySetMirrorVertical(enabled: true);
  await controller.gsySetCoverUrl('https://example.com/cover.jpg');
  await controller.gsySetKeepLastFrameWhenComplete(enabled: true);
}
```

#### GSY native UI configuration items (`GsyUiConfig`)

| Field | Default | Description |
|---|---|---|
| `enableNativeControls` | `true` | Both: swipe gestures (progress/volume/brightness); Apple side also controls control bar visibility |
| `enableNativeControlsFullscreen` | `true` | Android fullscreen gesture; Apple shares with `enableNativeControls` |
| `showFullscreenButton` | `true` | Fullscreen button |
| `showLockButton` | `true` | Lock button (Android) |
| `showVolumeToolbar` | `true` | Speaker button + vertical volume popup |
| `showSettingsButton` | `true` | Gear button + settings panel (audio tracks) |
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

`creationParams` / `gsyUi` fields: `enableNativeControls`, `showVolumeToolbar`, `showSettingsButton`, `showFullscreenButton`, `dismissControlTime`, `pictureInPictureEnabled` (read on Apple side but not effective), `coverUrl`, `keepLastFrameWhenComplete`.

## Platform differences quick check

| Capability | Android (GSY) | iOS / macOS (SGPlayer) |
|---|---|---|
| Loop | native `isLooping` | seek(0)+play after completion |
| Screenshot overlay | `captureFrame(includeOverlay: true)` includes UI | `includeOverlay` is ineffective |
| Switch source | rebuild player | `replaceWithURL` / `sgReplaceWithSegments` |
| Fullscreen | `gsyStartFullscreen()` | `sgStartFullscreen()` |
| PiP | enabled by default (manifest + `onUserLeaveHint`; backgrounding enters PiP) | not supported |
| Audio tracks UI | gear settings panel | gear settings panel |
| Volume UI | vertical volume popup; show percent; disable GSY left-edge volume gesture when popup is enabled | vertical volume popup |
| Gesture controls | `enableNativeControls`: horizontal seek, left brightness, right volume | same |
| Render rotation / mirror | `gsySetRenderRotation` / MirrorH/V | `sgSetRenderRotation` / MirrorH/V |
| Cover | `gsySetCoverUrl` | `sgSetCoverUrl` |
| Keep last frame | `gsySetKeepLastFrameWhenComplete` | `sgSetKeepLastFrameWhenComplete` |
| Buffered / error details | — | `buffered` / `playerError` |
| Pitch / VRBox / multi-segment / demuxer | — | see above |
| Deployment notes | — | iOS: device testing; macOS 11+; sandbox needs `network.client` |

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
3. iOS needs device testing for SGPlayer features; macOS requires 11.0+ and outbound network entitlement.
4. Disable PiP: `GsyUiConfig(pictureInPictureEnabled: false)`.

