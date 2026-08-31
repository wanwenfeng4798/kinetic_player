# Desktop libmpv (Windows / Linux)

Chinese: [DESKTOP_MPV.md](DESKTOP_MPV.md)

On **Windows** and **Linux**, `kinetic_player` uses [libmpv](https://mpv.io) as the built-in backend. The public API matches Android / iOS / macOS / Web: `CommonVideoPlayerViewBuilder` + `CommonVideoController`. The factory auto-selects; no Dart call-site changes.

## Versions

- **Windows**: bundles the latest LGPL `libmpv-2.dll` from [zhongfly/mpv-winbuild](https://github.com/zhongfly/mpv-winbuild) (see [windows/mpv/manifest.json](../windows/mpv/manifest.json)). C API headers match official **mpv v0.41.0** (`MPV_CLIENT_API_VERSION` 2.5).
- **Linux**: system pkg-config `mpv`. Documented minimum **0.35**; 0.41+ recommended when the distro ships it.

## Differences vs other platforms

- Video: Flutter `Texture` (libmpv software render into a pixel buffer; Linux `FlPixelBufferTexture`, Windows `PixelBufferTexture`), not a `--wid` child window.
- Chrome: Dart overlay in Bilibili style, interaction aligned with **macOS** (no pan gestures; speaker / subtitles / quality / gear / seek bar / fullscreen).
- `captureFrame(includeOverlay:)` ignores overlay (same as iOS).
- Fullscreen toggles the host Flutter window (`MpvVideoControllerImpl.mpvStartFullscreen`).

Platform-only APIs via downcast:

```dart
if (controller is MpvVideoControllerImpl) {
  await controller.mpvSetHwdec('auto-safe');
  await controller.mpvSetPlaylist(urls, startIndex: 0);
  await controller.mpvSetShowType(GsyShowType.ratio16x9);
  await controller.mpvStartFullscreen();
}
```

## Feature parity vs Android (GSY)

What libmpv / the Dart overlay can match is implemented as `mpv*` APIs (not on `CommonVideoController`).

| Capability | Desktop libmpv | Notes |
|------------|----------------|-------|
| Common play / volume / rate / loop / audio tracks | ✅ | Same method names as GSY/SG |
| Cover | ✅ `mpvSetCoverUrl` | Dart overlay, live update |
| Title | ✅ `KineticUiConfig.videoTitle` / `mpvSetUiConfig` | Top of chrome |
| Rotation | ✅ `mpvSetRenderRotation` | `video-rotate` |
| Mirror | ✅ `mpvSetMirrorHorizontal` / `Vertical` | `vf` hflip/vflip |
| 16:9 / 4:3 / fill | ✅ `mpvSetShowType` | Maps `GsyShowType` |
| External subtitles | ✅ `mpvSetSubtitleUrl` / `mpvSetSubtitleEnabled` | `sub-add` / `sid` |
| Playlist + play-next | ✅ `mpvSetPlaylist` / `mpvPlayNextInPlaylist` | Also `creationParams['playlist']` |
| Video tracks / quality | ✅ `mpvListVideoTracks` / `mpvSelectVideoTrack` | Chrome quality button |
| Net speed | ✅ `mpvGetNetSpeed` | libmpv `cache-speed` |
| Pure play | ✅ `mpvSetPurePlayMode` | Hides Dart chrome |
| Watermark | ✅ `mpvSetWatermarkUrl` | Flutter overlay, not burned in |
| Screenshot | ✅ `captureFrame` | PNG bytes |
| Hardware decode | ✅ `mpvSetHwdec` | Default `auto-safe` |
| GL filters | ❌ | GSY OpenGL pipeline |
| GIF recording | ❌ | Needs a separate encoder |
| Danmaku | ❌ | No Bilibili XML engine |
| Pre/mid-roll ads | ❌ | No desktop ad UI |
| System PiP | ❌ | No Android-style system PiP |
| List auto-play | ❌ | `GsyAutoPlayVideoList` is Android-only |
| Switch IJK/Exo cores | ❌ | Desktop is libmpv only |
| Embedded subtitle text | ❌ | Exo overlay-specific |
| Gravity orientation | ❌ | Host window handles this |

## Windows

- Target: Windows 10+ **x64**. ARM64 is not promised in v1.
- CMake downloads LGPL `libmpv-2.dll` and copies it next to the app.
- Or pre-place `windows/mpv/vendor/libmpv-2.dll`, or set `KINETIC_PLAYER_LIBMPV_DLL` / `KINETIC_PLAYER_LIBMPV_URL`.
- Manual download: `bash windows/mpv/download_libmpv.sh` (needs `7z`).
- libmpv is **LGPLv2.1+** (dynamic link); this plugin remains MIT.

```bash
cd example
flutter run -d windows
```

## Linux

System libmpv via pkg-config (`mpv`):

```bash
# Debian / Ubuntu
sudo apt install libmpv-dev

# Fedora
sudo dnf install mpv-libs-devel
```

```bash
cd example
flutter run -d linux
```

Wayland and X11 both use Texture (no `--wid` embedding). Hardware decode defaults to `hwdec=auto-safe`.

## Channels

- Plugin: `com.example.player/mpv` (`create` / `destroy`)
- Instance: `com.example.player/mpv_<viewId>` (same public method names as GSY/SG)

## Alternative

If you specifically need a GStreamer pipeline, the separate [GstPlayer](https://pub.dev/packages/gstplayer) package remains available. This plugin's desktop backend is libmpv; you do not need GstPlayer for Windows/Linux.
