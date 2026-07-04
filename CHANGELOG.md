## 0.0.2

### Fixes & Optimizations

- **Audio Track & Gesture Fixes**: Fixed an issue where audio track settings were reset upon replay, and resolved conflicts between audio track settings and gesture operations.
- **Audio Control Fixes**: Fixed conflicts between the audio track bar and gesture-based volume adjustments.
- **Example Optimization**: Optimized the example project to prevent the application from failing to open after enabling code obfuscation (ProGuard) on Android.

---

## 0.0.1

### Public API

- Unified `CommonVideoController`: `play` / `pause` / `stop` / `seekTo` / `setScaleMode` / `setRate` / `setVolume` / `setMute` / `switchVideoSource` / `getAudioTracks` / `selectAudioTrack` / `getDuration` / `getCurrentPosition` / `getVideoSize` / `setLooping` / `captureFrame` / `dispose`
- Dual-platform MethodChannel status and progress callbacks (`onPlayerStateChanged` / `onPositionChanged`, throttled at approx. 250ms)

### Native Control Bar (Android GSY + iOS SGPlayer)

- Bilibili-style UI: Click the speaker icon to pop up a **vertical** volume bar; click the gear icon to open the **settings panel** for audio track selection.
- Unified track colors for the progress bar and volume bar (`kinetic_seek_progress` / `KineticPlayerColors`).
- Added `GsyUiConfig.showSettingsButton` (defaults to `true`).
- `showVolumeToolbar` now controls the speaker button (instead of a persistent bottom volume bar).
- The bottom area no longer intercepts clicks after the control bar is hidden, allowing the bottom-right corner to normal toggle the control bar visibility.

### Picture-in-Picture (Android)

- `GsyUiConfig.pictureInPictureEnabled` defaults to `true`.
- Automatically enters PiP when switching to the background during playback (`onUserLeaveHint`, API 26+).
- Supports `setAutoEnterEnabled` on Android 12+.
- Manual API: `gsyEnterPictureInPicture()`.
- Host app configuration required: `supportsPictureInPicture`, `resizeableActivity`, and forwarding `KineticPlayerPlugin.handleUserLeaveHint`.
- iOS: SGPlayer custom rendering, **system PiP is not supported**.

### Playback Experience

- Fixed an issue where playback could not be replayed after completion (Android completion state now executes seek(0) first; iOS uses `replayFromBeginning`).

### Android GSY Advanced Capabilities

- Filters, danmaku (bullet comments), subtitles, screenshots/GIFs, lists, Exo tracks, watermarks, etc. (see [GSY_FEATURES.md](doc/GSY_FEATURES.md)).

### iOS SGPlayer

- Native control bar, full screen, `sgSetVRMode` / `sgSetSyncGroupId`.
- Audio track APIs aligned with the Android public layer.