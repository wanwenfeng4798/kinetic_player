# Android GSY Advanced Capability Matrix

Android side is based on **GSYVideoPlayer 13.1.0** (`io.github.carguo:gsyvideoplayer-*`). For iOS / macOS see [DARWIN_SGPLAYER_EN.md](DARWIN_SGPLAYER_EN.md); for Web see [WEB_ARTPLAYER_EN.md](WEB_ARTPLAYER_EN.md). This document covers Android GSY-only capabilities.

## Legend

| Status | Meaning |
|---|---|
| ✅ | Exposed via the plugin MethodChannel |
| ⚠️ | Partially implemented / needs host app cooperation |
| ❌ | Not available in the GSY 13 Maven modules, or needs demo-level integration |

---

## 1. Filters / Animations / Watermark / Multi-play

| Capability | Status | API |
|---|---|---|
| 26 GL filters (mosaic, black & white, gaussian blur, etc.) | ✅ | `gsySetRenderType(GsyRenderType.glSurface)` + `gsySetEffectFilter(name)` + `gsyListEffectFilters()` |
| Watermark / Multi-play in one scene | ⚠️ | `gsySetWatermarkUrl(url)` top-right image overlay; multi-play simultaneously needs a custom layout |

---

## 2. Screenshot / GIF

| Capability | Status | API |
|---|---|---|
| Video frame screenshot | ✅ | `captureFrame()` (public API) |
| Screenshot with player UI composition | ✅ | `captureFrame(includeOverlay: true)` |
| Save screenshot to file | ✅ | `gsySaveScreenshot()` (Android GSY-only) |
| Generate GIF | ✅ | `gsyStartGifRecording()` → `gsyStopGifRecording()` |

---

## 3. Playlist / Rotation / Playback speed / Network speed

| Capability | Status | API |
|---|---|---|
| Playlist play / Continuous play | ✅ | `creationParams['playlist']` / `gsySetPlaylist()` / `gsyPlayNextInPlaylist()` |
| Gravity / manual rotation | ✅ | `GsyUiConfig.rotateViewAuto` + forward Activity `configChanges` |
| Video rotation metadata | ✅ | Applied automatically by the GSY core |
| Manual rotation 0/90/180/270 | ✅ | `gsySetRenderRotation(degrees)`; iOS: `sgSetRenderRotation(degrees)` |
| Fast-forward / slow playback | ✅ | `setRate()` or `GsyUiConfig.speed` |
| Network load speed | ✅ | `gsyGetNetSpeed()` |
| Keep last frame when finished | ✅ | `GsyUiConfig.keepLastFrameWhenComplete` / `gsySetKeepLastFrameWhenComplete`; iOS: `sgSetKeepLastFrameWhenComplete` |
| Video cover | ✅ | `GsyUiConfig.coverUrl` / `gsySetCoverUrl` (GSY `setThumbImageView`); iOS: `sgSetCoverUrl` |

> Align “keep last frame” with the GSY Demo `KeepLastFrameVideo`: the render view is not removed after natural completion, and cover is not shown. On iOS / macOS the last frame is revealed by hiding the cover layer.

---

## 4. Aspect ratio / Mirror

| Capability | Status | API |
|---|---|---|
| Default / 16:9 / 4:3 / fill / stretch | ✅ | `setScaleMode()` or `gsySetGsyShowType(GsyShowType.*)` |
| Horizontal mirror | ✅ | `gsySetMirrorHorizontal(enabled: true)`; iOS: `sgSetMirrorHorizontal(enabled: true)` |
| Vertical mirror | ✅ | `gsySetMirrorVertical(enabled: true)`; iOS: `sgSetMirrorVertical(enabled: true)` |

> iOS: apply transforms to the inner `content` of `SgTransformHostView` (outer clipping + Auto Layout won’t be disturbed by the transform). Metal render view keeps identity. Control bar is not affected.
>
> Android: use GSY `View.setRotation` (MeasureHelper remeasures by angle) + `scaleX` / `scaleY` mirroring to avoid misalignment / black screens caused by an incorrect TextureView matrix pivot.
>
> 90° / 270° will scale by `max(w/h, h/w)` to center-fill.

---

## 5. Playback core

| Core | Status | API |
|---|---|---|
| IJKPlayer | ✅ | `gsySwitchRenderCore(GsyRenderCore.ijk)` (**plugin default core**) |
| Media3 (Exo2) | ✅ | `gsySwitchRenderCore(GsyRenderCore.exo)` |
| MediaPlayer | ✅ | `gsySwitchRenderCore(GsyRenderCore.system)` |
| AliPlayer | ❌ | Maven 13.1.0 has no `gsyvideoplayer-ali` module |
| Custom core | ⚠️ | Need to fork the plugin and register `PlayerFactory.setPlayManager` |

**Default core**: the plugin sets core to **IJKPlayer** when loaded (`GsyPlayerDefaults`).

**IJK accurate seek**: `GsyUiConfig.ijkEnableAccurateSeek` (default `true`) sets `enable-accurate-seek=1` via `GSYVideoManager.setOptionModelList` to reduce keyframe bounce when dragging the progress bar; only effective for IJK.

**Large file / remote MKV**: when `GsyUiConfig.cacheWithPlay` is enabled it uses HttpProxyCache; for multi-GB progressive downloads it is easy to hit connection timeouts. For large remote files set `cacheWithPlay: false`. The plugin also increases default timeouts for GSY prepare / Exo HTTP / IJK format to 60s.

In Exo mode, **DASH / HLS adaptive** is handled automatically by Media3; switching tracks is available via `gsyListExoVideoTracks` / `gsySelectExoVideoTrack`.

**Audio (track) public API**: `getAudioTracks()` / `selectAudioTrack(index)` (Exo / IJK core; see `GsyAudioTrackHelper`).

---

## 6. Layout / Pure play / Danmaku / Custom layout

| Capability | Status | API |
|---|---|---|
| Fullscreen / non-fullscreen two layouts | ✅ | native `startWindowFullscreen` + `GsyUiConfig` |
| Pure play without controls | ✅ | `gsySetPurePlayMode(enabled: true)` |
| Danmaku | ✅ | `gsySetDanmakuUrl(url)` + `gsyToggleDanmaku(enabled)` (DanmakuFlameMaster + Bilibili XML) |
| Bilibili-style control bar | ✅ | vertical volume popup (shows percentage while dragging) + settings panel for audio tracks; when `showVolumeToolbar` is enabled it disables GSY left-edge volume gestures; bottom bar icons are unified to 28dp |
| Inherit custom layout | ⚠️ | fork `KineticGSYVideoPlayer` and override `getLayoutId()` |

Layout file: `kinetic_video_layout_preview.xml` (progress bar, `kinetic_seek_progress` color theme, speaker/gear/fullscreen buttons).

---

## 7. Singleton / Multi-instance / Auto-play list / Seamless switching

| Capability | Status | Note |
|---|---|---|
| Single instance playback | ✅ | `gsyReleaseAllVideos()` |
| Multi-instance simultaneous playback | ✅ | Each PlatformView uses its own `playTag` |
| Auto-play when list is scrolled | ⚠️ | `GsyAutoPlayVideoList` / `GsyAutoPlayCoordinator` (visibility detection; not GSY ListGSYVideoPlayer) |
| Seamless switching on detail page | ⚠️ | `creationParams['playTag']` + `gsySeamlessHandoffParams()` sharing the same playTag |

---

## 8. Small window / PiP

| Capability | Status | API / Note |
|---|---|---|
| Android PiP | ✅ | **`pictureInPictureEnabled: true` (default)**; while playing (including GSY auto-play / native play button), press Home or background to enter PiP |
| Manual PiP | ✅ | `gsyEnterPictureInPicture()` |
| Android 12+ system auto PiP | ✅ | while playing, auto-enter PiP via `PictureInPictureParams.setAutoEnterEnabled` |
| Host manifest | ⚠️ | `supportsPictureInPicture="true"`, `resizeableActivity="true"` |
| Host activity | ⚠️ | `KineticPlayerPlugin.handleUserLeaveHint(this)` |
| iOS / macOS PiP | ❌ | SGPlayer uses custom rendering; no system PiP |
| Desktop multi-window | ⚠️ | depends on Android system multi-window + PiP |

Disable PiP:

```dart
GsyUiConfig(pictureInPictureEnabled: false)
```

---

## 9. Ads

| Capability | Status | API |
|---|---|---|
| Pre-roll ad + skip | ⚠️ | `gsyPlayWithPreRollAd(adUrl, contentUrl)` (automatically switch to main content after ads) |
| Mid-roll ads | ⚠️ | `gsySetMidRollAds([{positionMs, adUrl, contentUrl}])`; triggered by position; full `GSYADVideoPlayer` UI is not ported |

---

## 10. Subtitles

| Capability | Status | API |
|---|---|---|
| External SRT/WebVTT | ✅ | `gsySetSubtitleUrl(url, mimeType: ...)` |
| Enable / disable | ✅ | `gsySetSubtitleEnabled()` |
| Exo embedded subtitle bridge | ✅ | `gsySetEmbeddedSubtitleText(text)` |

---

## 11. DASH / Adaptive clarity

| Capability | Status | Note |
|---|---|---|
| Exo DASH playback | ✅ | Use Exo core + DASH URL |
| HLS/DASH track switching UI | ⚠️ | `gsyListExoVideoTracks()` / `gsySelectExoVideoTrack(index)` (no demo-level UI) |

---

## Quick example

```dart
if (controller is GSYVideoControllerImpl) {
  await controller.gsySetRenderType(GsyRenderType.glSurface);
  await controller.gsySetEffectFilter('gaussianBlur');
  await controller.gsySetGsyShowType(GsyShowType.ratio16x9);
  await controller.gsySetSubtitleUrl('https://example.com/subs.vtt');
  final path = await controller.captureFrame(includeOverlay: true);
  await controller.gsySetPlaylist(['url1', 'url2']);
  await controller.gsySetDanmakuUrl('https://example.com/danmaku.xml');
  await controller.gsyToggleDanmaku(enabled: true);
  final tracks = await controller.gsyListExoVideoTracks();
  if (tracks.isNotEmpty) await controller.gsySelectExoVideoTrack(0);
  final audioTracks = await controller.getAudioTracks();
  if (audioTracks.length > 1) {
    await controller.selectAudioTrack(audioTracks[1].index);
  }
}
```

