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


Full acceptance is still pending. The full7 Windows extended suite passed, including texture/RGBA pixel agreement, mirror restoration, VTT/SRT visibility, actual 2x timing, EOF replay/last-frame retention, playlist autoPlay:false/automatic next, native looping, pure-mode buttons, watermark images and stop/reload. Full8 passed HTTP headers/UA/Range, 404 recovery and clearing request options. Its Release build succeeded with the bundled libmpv DLL checked and hashed.

Network acceptance remains incomplete: full7 passed 9/18 sources; full8 also passed Mux HLS, reported a jsDelivr DNS failure and stalled on some DASH sources before interruption. HTTP probes reached 17/18 top-level URLs; this does not establish segment decoding. The audio output test measured attenuation but assumed a linear volume curve; revised assertions check attenuation, mute and restoration without imposing that assumption. These changes await complete reruns.

The refined desktop settings menu adds grouping, selected states, back/close navigation and watermark/cover/last-frame/pure-play controls. Controller notifications and external demo buttons share state. Static checks passed; full9 sources/scripts have been transferred and launched on Windows for runtime validation, without Apple or Flutter build products. Existing Flutter tests passed 35/35 before the new menu changes. Multi-monitor/DPI and Linux hardware remain unverified. Desktop danmaku, ads UI and system PiP remain unsupported. No tag/release has been published.

Full9 update: Windows Flutter regression passed 38/38, actual output attenuation/mute/restoration and HTTP tests passed 2/2, and the refined menu Release build succeeded. Network decoding passed 10/18; eight failures remain (jsDelivr MP4, BBB/Shaka DASH, TS, Ogg, MP3, MKV and FLV). Do not treat every failure as a dead URL without isolating source loading/recovery. The final external-demo state-listener update passed static analysis and was transferred in full10; its runtime result has not been retrieved. UU remote input is intermittent, so manual popup acceptance is incomplete.
