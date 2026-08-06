# Example app

Chinese: [EXAMPLE.md](EXAMPLE.md)

The sample under `kinetic_player/example/` demos **fully delivered** features by platform.

## Run

```bash
cd kinetic_player/example
flutter pub get
flutter run
flutter run -d macos
flutter run -d chrome
```

## Structure

1. **Player surface** — `CommonVideoPlayerViewBuilder` with platform `GsyUiConfig` / `ArtplayerUiConfig`
2. **Common** — source, audio tracks, rate, volume/mute, loop, screenshot, Play/Pause/Seek
3. **Android GSY** — render core, GL filters, subtitles, danmaku, watermark, pre/mid-roll ads, GIF, save frame, manual PiP, playlist, net speed, Exo video tracks, show type, pure play, fullscreen; AppBar opens **scroll auto-play list**
4. **iOS / macOS SG** — rotation/mirror, cover/last frame, pitch, VR modes/viewport, background policy (iOS), demuxer, video tracks, segments, seekable, fullscreen
5. **Web Artplayer** — plugins enabled at create (danmuku, Document PiP, HLS/DASH, …); panel: Video PiP, Document PiP, emit danmaku, list plugins

See feature docs for the full matrix.
