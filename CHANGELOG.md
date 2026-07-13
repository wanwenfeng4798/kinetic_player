## 0.0.3

### Fixes

- **Volume persistence**: Fixed volume level and slider position resetting after pause/resume, replay after completion, or switching video source. Android re-applies saved volume on `onPrepared` / playback start; iOS uses `applySavedVolume` on play/replay and returns `_savedVolume` from `currentVolume()`.
- **Picture-in-Picture (Android)**: Fixed auto PiP not triggering when playback started via GSY auto-play or native play button (`isPlaying` was only set from Flutter `play()`). Playback state now syncs with native GSY events; PiP eligibility uses actual player state (`isPlaybackActive()`).
- **Volume gesture conflict (Android)**: When `showVolumeToolbar` is enabled, GSY’s built-in left-edge volume slider gesture is disabled so only the Bilibili-style volume popup is shown.
- **Volume drag label**: Fixed percentage label (`50%`) flickering or disappearing while dragging the volume slider.
- **Toolbar icons**: Unified fullscreen button size with settings/volume icons (28dp); replaced GSY default enlarge icon with matching vector assets.

### Enhancements

- **Volume UI**: Dragging the vertical volume slider shows a percentage label to the left of the track; the label hides on release. Panel background width reduced to 44dp (label floats outside the panel).
- **iOS gesture controls**: Added GSY-style pan gestures — horizontal seek, left-half brightness, right-half volume — with a center HUD overlay. Controlled by the shared `enableNativeControls` flag (same as Android). System brightness is restored when the player is disposed. Swipe-volume is blocked while the volume popup is open or its slider is being dragged (same as Android), and volume sensitivity matches GSY (~3×).
- **Render rotate / mirror**: Android already exposed `gsySetRenderRotation` / `gsySetMirrorHorizontal`; iOS adds matching `sgSetRenderRotation` / `sgSetMirrorHorizontal` via `CGAffineTransform` on the video view. Example app includes rotate/mirror controls for both platforms.
- **Cover / keep last frame**: Android uses GSY `setThumbImageView` + KeepLastFrameVideo-style `onAutoCompletion`; iOS uses a cover overlay and hides it when keeping the last frame. Config: `GsyUiConfig.coverUrl` / `keepLastFrameWhenComplete`; runtime: `gsySetCoverUrl` / `gsySetKeepLastFrameWhenComplete` (iOS: `sgSet*`).
- **Rotate fill + vertical mirror**: 90°/270° rotation now scales to center-fill the player; added `gsySetMirrorVertical` / `sgSetMirrorVertical`.
- **Rotate / mirror positioning fix**: Android now uses GSY `View.setRotation` + `scaleX`/`scaleY` (MeasureHelper remeasure) instead of a mis-pivoted TextureView matrix; iOS uses `SgTransformHostView` (clipping host + inner content transform) so Auto Layout stays stable and the Metal render target stays identity.
- **SGPlayer deep APIs**: buffered progress + error details, pitch, VR/VRBox + viewport, demuxer options (timeout/UA/headers), video track selection, multi-segment `SGMutableAsset`, background playback policy; `sgSetSyncGroupId` now throws (unsupported).
- **Example**: Explicitly enables `pictureInPictureEnabled: true`; added PiP usage hint in the control panel.

---

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
