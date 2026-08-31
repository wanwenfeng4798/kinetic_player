# Example app

Chinese: [EXAMPLE.md](EXAMPLE.md)

The sample under `kinetic_player/example/` demos **fully delivered** features by platform.

## Run

Darwin (iOS / macOS) uses **Swift Package Manager** by default (same as the plugin). No Podfile or extra scripts:

```bash
cd kinetic_player/example
flutter pub get
flutter run
flutter run -d macos
flutter run -d chrome
flutter run -d windows
flutter run -d linux
```

macOS requires `MACOSX_DEPLOYMENT_TARGET = 11.0` (already set in the Example). For Xcode-only build errors about SPM platform versions, see [DARWIN_SGPLAYER_EN.md — SPM wrapper minimum OS](DARWIN_SGPLAYER_EN.md#spm-wrapper-minimum-os) (edit `FlutterGeneratedPluginSwiftPackage/Package.swift` manually, or run `flutter run -d macos` first).

## Structure

1. **Player surface** — `CommonVideoPlayerViewBuilder` with platform `KineticUiConfig` / `ArtplayerUiConfig`
2. **Common** — source, **chrome language**, audio tracks, rate, volume/mute, loop, screenshot, Play/Pause/Seek
3. **Android GSY** — render core, GL filters, subtitles, danmaku, watermark, pre/mid-roll ads, GIF, save frame, manual PiP, playlist, net speed, Exo video tracks, show type, pure play, fullscreen; AppBar opens **scroll auto-play list**
4. **iOS / macOS SG** — rotation/mirror, cover/last frame, pitch, VR modes/viewport, background policy (iOS), demuxer, video tracks, segments, seekable, fullscreen
5. **Web Artplayer** — plugins enabled at create (danmuku, Document PiP, HLS/DASH, …); panel: Video PiP, Document PiP, emit danmaku, list plugins
6. **Windows / Linux libmpv** — button chrome (volume / subtitles / quality / settings / rate / fullscreen); rotation, mirror, cover, subtitles, playlist, watermark, pure play; no pan gestures, no PiP / danmaku / ads / GIF

See feature docs for the full matrix, plus [DESKTOP_MPV_EN.md](DESKTOP_MPV_EN.md).
