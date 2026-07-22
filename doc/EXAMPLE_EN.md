# Example App

The Example project lives in `kinetic_player/example/` and demonstrates how to integrate and use the dual-core player.

## Run

```bash
cd kinetic_player/example

bash ../darwin/scripts/sgplayer/spm_prebuild_hook.sh ios
bash ../darwin/scripts/sgplayer/spm_prebuild_hook.sh macos

flutter pub get
flutter run          # iOS device / Android
flutter run -d macos
```

Android can run directly with `flutter run`. iOS / macOS details are in [DARWIN_SGPLAYER_EN.md](DARWIN_SGPLAYER_EN.md).

## UI layout

`example/lib/main.dart` includes:

1. **Video area** — `CommonVideoPlayerViewBuilder` loads remote sources; Android includes `GsyUiConfig` (native controls, preview thumbnails, etc.).
2. **Settings / Source / Audio tracks** — demo sources can be selected via dropdown (includes Big Buck Bunny and 4K HEVC test streams); audio tracks can be selected via `getAudioTracks` / `selectAudioTrack`; there is also a gear button in the native UI.
3. **Android-only** — GL filters, subtitles (WebVTT / pushed text), danmaku (Bilibili XML).
4. **Loop / Screenshot** — `setLooping`, `captureFrame`.
5. **Common controls** — Play / Pause / Seek 10s and state/progress display.
6. **Platform-only buttons** — Android: `GSY Fullscreen`; iOS: `SG Fullscreen`, `SG VR`.

## Native control bar (enabled in Example)

| Interaction | Description |
|---|---|
| Tap on video | Show/hide control bar and center play button |
| Speaker | Popup vertical volume bar (Bilibili style); **while dragging, show percentage on the left side of the slider** |
| Gear | Popup settings panel to select audio track |
| Fullscreen | Window-level fullscreen (icon size matches settings/volume icons) |
| Swipe gestures | Horizontal seek; left half brightness; right half volume (`enableNativeControls`) |
| Rotate / Mirror | Rotate left/right by 90°, reset, left/right mirror, up/down mirror (Android / iOS) |
| Cover / Keep last frame | Toggle cover and keep last frame after playing finished (Android / iOS) |
| Advanced (iOS) | Pitch, VR/VRBox, background playback, demuxer options, video track selection; buffering and error display |

**Picture-in-Picture (Android)**: while playing (including auto-play or starting from native button), pressing **Home** or switching to another app will automatically enter PiP. Example is configured in `MainActivity` and `AndroidManifest`; `GsyUiConfig(pictureInPictureEnabled: true)` is explicitly enabled.

## Core code

```dart
CommonVideoPlayerViewBuilder(
  url: _selectedSource.url,
  creationParams: isAndroid
      ? GsyUiConfig(
          enableNativeControls: true,
          showFullscreenButton: true,
          showVolumeToolbar: true,
          showSettingsButton: true,
          pictureInPictureEnabled: true,
          showDragProgressTextOnSeekBar: true,
          videoTitle: 'GSY Demo',
          previewVttUrl: _previewVttUri,
        ).toCreationParams()
      : null,
  builder: (controller) {
    setState(() => _controller = controller);
  },
)
```

## Control panel logic

```dart
// Common controls
await controller?.play();
await controller?.pause();
await controller?.seekTo(const Duration(seconds: 10));
await controller?.setLooping(true);
final path = await controller?.captureFrame(highQuality: true, includeOverlay: true);

// Audio tracks
final tracks = await controller?.getAudioTracks();
await controller?.selectAudioTrack(tracks.first.index);

// Listen state
ValueListenableBuilder<CommonPlayerState>(
  valueListenable: controller!.playerState,
  builder: (_, state, __) => Text('State: $state'),
);

// GSY-only (Android)
if (controller is GSYVideoControllerImpl) {
  await controller.gsyToggleDanmaku(enabled: true);
  await controller.gsyStartFullscreen();
}

// SG-only (iOS)
if (controller is SGVideoControllerImpl) {
  await controller.sgSetVRMode(enabled: true);
  await controller.sgStartFullscreen();
}
```

## Android host configuration (already included in Example)

`example/android/app/src/main/AndroidManifest.xml`:

- `android:supportsPictureInPicture="true"`
- `android:resizeableActivity="true"`

`MainActivity.kt`:

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
  KineticPlayerPlugin.handleUserLeaveHint(this)
}
```

## Demo URLs

Default uses W3Schools public MP4:

```text
https://www.w3schools.com/html/mov_bbb.mp4
```

You can replace it in `main.dart` inside `_DemoMedia.videoUrl`.

## Test

```bash
cd kinetic_player
flutter analyze
flutter test
```

Integration test is under `example/integration_test/`.

## pubspec configuration

Example enables SPM:

```yaml
flutter:
  config:
    enable-swift-package-manager: true
```

iOS / macOS Scheme Pre-actions are already calling `example/{ios,macos}/scripts/run_kinetic_sgplayer_prebuild.sh` (sync remote binaryTarget + ensure local xcframework). See [DARWIN_SGPLAYER_EN.md](DARWIN_SGPLAYER_EN.md).

Use a local path dependency:

```yaml
dependencies:
  kinetic_player:
    path: ../
```

