# SGPlayer integration for kinetic_player 3.0

Pinned upstream: [SGPlayer v2.0.0](https://github.com/wanwenfeng4798/SGPlayer/releases/tag/v2.0.0). Minimum iOS 15 / macOS 12.

Before resolving SwiftPM for the first time, run from the plugin root:

```sh
bash darwin/scripts/sgplayer/spm_prebuild_hook.sh ios
```

This prepares both conditional local binary targets. Official release archives contain a local package with a nested Artifacts/SGPlayer.xcframework; they are not remote binaryTarget archives. Downloads use the published SHA-256 and a versioned cache. Run the preparation script once for CocoaPods as well: Flutter local path dependencies may skip prepare_command. Failed downloads stop with an error; source fallback requires KINETIC_PLAYER_SGPLAYER_BUILD_FROM_SOURCE=1.

SGPlaybackSession owns automatic kernel selection, compatibility fallback, playlists and looping. SGPlaybackController owns seeks, audio tracks, screenshots and PiP. SGPlaybackControls owns native UI, iOS gestures and macOS shortcuts. Flutter forwards commands/events. Host window fullscreen, transforms and segmented assets remain adapters. Custom HTTP/demuxer options, pitch and VR require FFmpeg. Segmented assets use the FFmpeg compatibility path.

SGVideoControllerImpl adds getDiagnostics, startPictureInPicture, stopPictureInPicture and isPictureInPictureActive. PiP availability depends on the system and host background audio configuration.

Android continues to use GSY native controls. Windows/Linux keep independent libmpv texture/Flutter controls. Web keeps Artplayer DOM controls. Shared playback, seek, rate, volume, audio tracks, looping and PNG capture retain CommonVideoController. Web tracks depend on streaming formats and screenshots require CORS permission.

SGPlayer 2 exposes no runtime control localization/theme/per-button visibility interface. setLocale returns UNSUPPORTED on Darwin. Native controls use SDK copy; enableNativeControls and auto-hide remain supported. Disable native controls to supply host UI. Native settings actions are SDK-owned; call captureFrame when PNG bytes are required.

Validation excludes all device, simulator and player launches. Manually verify kernel selection/fallback, authenticated headers, seek/rate/tracks/loop, playlists, settings, fullscreen restore, PiP/background return and disposal. Verify Windows/Linux on their respective hosts and Web in a browser.

## Native extension inventory

SGVideoControllerImpl.native now forwards session/rendition/kernel policies, A–B and playlist loops, stable-ID resume, diagnostics/export, exclusive coordination, native AVPlayer policy/metrics, subtitle reading/loading/dual selection/cues, ASS/bitmap fonts, danmaku, watermarks, filters/curves/3D cube/bloom, GIF stickers, independent image composition, native control lock/cover, floating/full-window presentation, independent timeline previews/WebVTT sprites, quota/SHA-256/pinned progressive cache, background HLS stores, GIF export/remux/transcode/audio-only export, and task progress/cancel/results to upstream SGPlayer APIs.

Use native.onEvent for task/HLS/PiP events and native.onRestorePictureInPicture for asynchronous host navigation before acknowledging system restoration. Background HLS identifiers are namespaced under kinetic_player.hls.; the iOS plugin handles background NSURLSession lifecycle delivery. Stores survive player disposal and may be reopened with the same identifier. Close only after downloads finish/cancel. Authorized cookies are supported; arbitrary authenticated resource loaders/DRM remain host-native responsibilities.

All Duration arguments cross the channel as milliseconds; upstream effect offsets/positions retain their SDK units. Fonts/licenses are extracted and bundled for SPM/CocoaPods. No CVPixelBuffer/Metal pointers are passed to Dart; image results use PNG. See the full method/config inventory in DARWIN_SGPLAYER.md.
