# Desktop libmpv (Windows / Linux)

Chinese: [DESKTOP_MPV.md](DESKTOP_MPV.md)

On **Windows** and **Linux**, `kinetic_player` uses [libmpv](https://mpv.io) as the built-in backend. The public API matches Android / iOS / macOS / Web: `CommonVideoPlayerViewBuilder` + `CommonVideoController`. The factory auto-selects; no Dart call-site changes.

## Versions

- **Windows**: bundles the latest LGPL `libmpv-2.dll` from [zhongfly/mpv-winbuild](https://github.com/zhongfly/mpv-winbuild) (see [windows/mpv/manifest.json](../windows/mpv/manifest.json)). C API headers match official **mpv v0.41.0** (`MPV_CLIENT_API_VERSION` 2.5).
- **Linux**: system pkg-config `mpv`. Documented minimum **0.35**; 0.41+ recommended when the distro ships it.

## Differences vs other platforms

- Video: Flutter `Texture` (libmpv software render into a pixel buffer; Linux `FlPixelBufferTexture`, Windows `PixelBufferTexture`), not a `--wid` child window.
- Chrome: Dart overlay in Bilibili style, interaction aligned with **macOS** (no pan gestures; speaker / subtitles / quality / gear / seek bar / fullscreen).
- HTTP: `setHttpRequestOptions` / `creationParams` `userAgent` & `headers` → libmpv `user-agent` / `http-header-fields`.
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


## Windows host validation (2026-11-01)

The x64 example was built and run through UU Remote using Flutter 3.47.7 and the existing Visual Studio toolchain. Only tracked sources and scripts were transferred, without Apple frameworks, Flutter build outputs or caches. Fixed import-library generation by using CMake's MSVC librarian path and failing configuration on errors. Player creation now resolves the top-level host HWND so state/progress messages reach the window delegate and fullscreen targets the application window. Integration tests now use MaterialApp to supply the desktop tooltips with an Overlay.

Both native playback suite tests passed on Windows: playback advancement, pause, seek, rate/volume/loop calls, dimensions, PNG capture, disposal, manual playlist next and repeated fullscreen entry/exit. Manual checks also showed local video, EOF replay, a 14-second seek, settings/more-settings panels, window restoration and frames from the existing XGPlayer 360p public MP4 (1:30 duration). This is basic validation, not acceptance of every setting, subtitle format, audio output, driver, display scale or Release package. Linux hardware and overall release/tag publication remain pending.


Full acceptance is still pending. Both Mac and Windows Flutter suites pass 35/35; Windows rebuilt and passed the native 2/2 smoke suite again. Full5/full6 logs confirm real texture/native RGBA pixel agreement, mirror restoration, VTT/SRT visibility, actual 2x timing (about 1.94–1.96), EOF replay and last-frame capture. Fixed ignored progress/volume colors, missing pure-mode play/pause, Windows drive/UNC image paths and forced playlist autoplay; the autoPlay:false fix passed on Windows in full6. Full6 then exposed automatic-next failure with keep-open, because EOF property changes did not advance the playlist. Added shared guarded EOF handling; this latest change has only passed C++ syntax checks and awaits Windows regression. Subsequent loop/watermark/pure-button/reload assertions were not reached. The new network acceptance suite covers all 18 project public URLs and native track selection but has not run. Latest incremental sources/scripts are on the Windows desktop as kinetic-full7.zip / .cmd, on top of full5/full6. UU input recovered for those runs, then the tool returned noWindowsAvailable after full7 transfer; read-only screenshots remain available, but full7 has not launched. Audible volume/mute, aspect, hardware decoding, HTTP/failure recovery, Release, multi-monitor/DPI and Linux hardware also remain pending; desktop danmaku, ads UI and system PiP remain unsupported. No tag/release has been published.
