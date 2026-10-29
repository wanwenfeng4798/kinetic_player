# Desktop libmpv (Windows / Linux)

English: [DESKTOP_MPV_EN.md](DESKTOP_MPV_EN.md)

`kinetic_player` 在 **Windows** 与 **Linux** 使用 [libmpv](https://mpv.io) 作为内建内核。公共 API 与 Android / iOS / macOS / Web 相同：`CommonVideoPlayerViewBuilder` + `CommonVideoController`。工厂自动选型，无需改 Dart 调用。

## 版本

- **Windows**：打包 [zhongfly/mpv-winbuild](https://github.com/zhongfly/mpv-winbuild) 最新 LGPL `libmpv-2.dll`（见 [windows/mpv/manifest.json](../windows/mpv/manifest.json)）。C API 头文件对齐官方 **mpv v0.41.0**（`MPV_CLIENT_API_VERSION` 2.5）。
- **Linux**：系统 pkg-config `mpv`。文档最低 **0.35**；推荐发行版提供 0.41+。

## 与其它平台的差异

- 画面：Flutter `Texture`（libmpv 软件渲染到像素缓冲；Linux 经 `FlPixelBufferTexture` 上传，Windows 为 `PixelBufferTexture`），不是 `--wid` 子窗口。
- 控制栏：Dart 层复刻 B 站风格底栏，交互对齐 **macOS**（无滑动手势；喇叭 / 字幕 / 清晰度 / 齿轮 / 进度条 / 全屏）。
- HTTP：`setHttpRequestOptions` / `creationParams` 的 `userAgent`、`headers` → libmpv `user-agent`、`http-header-fields`。
- `captureFrame(includeOverlay:)` 忽略 overlay（与 iOS 一致）。
- 全屏：切换宿主 Flutter 窗口（`MpvVideoControllerImpl.mpvStartFullscreen`）。

独有能力请向下转型：

```dart
if (controller is MpvVideoControllerImpl) {
  await controller.mpvSetHwdec('auto-safe');
  await controller.mpvSetPlaylist(urls, startIndex: 0);
  await controller.mpvSetShowType(GsyShowType.ratio16x9);
  await controller.mpvStartFullscreen();
}
```

## 相对 Android（GSY）的功能对照

能用 libmpv / Dart overlay 对齐的已实现，方法名用 `mpv*`（不下放到 `CommonVideoController`）。

| 能力 | 桌面 libmpv | 说明 |
|------|-------------|------|
| 公共播放 / 音量 / 倍速 / 循环 / 音轨 | ✅ | 与 GSY/SG 相同 method 名 |
| 封面 | ✅ `mpvSetCoverUrl` | Dart overlay，运行时可改 |
| 标题 | ✅ `KineticUiConfig.videoTitle` / `mpvSetUiConfig` | 控制栏顶部 |
| 旋转 | ✅ `mpvSetRenderRotation` | `video-rotate` |
| 镜像 | ✅ `mpvSetMirrorHorizontal` / `Vertical` | `vf` hflip/vflip；设置面板可开关水平镜像 |
| 画幅 16:9 / 4:3 / 铺满 | ✅ `mpvSetShowType` | 对齐 `GsyShowType` |
| 外挂字幕 | ✅ `mpvSetSubtitleUrl` / `mpvSetSubtitleEnabled` | `sub-add` / `sid` / `sub-visibility` |
| Playlist + 播完下一集 | ✅ `mpvSetPlaylist` / `mpvPlayNextInPlaylist` / `mpvSetAutoPlayNext` | 也读 `creationParams['playlist']` |
| 视频轨 / 清晰度 | ✅ `mpvListVideoTracks` / `mpvSelectVideoTrack` | 底栏清晰度按钮 |
| 网速 | ✅ `mpvGetNetSpeed` | libmpv `cache-speed` |
| 纯播放 | ✅ `mpvSetPurePlayMode` | 隐藏 Dart 控制栏 |
| 水印 | ✅ `mpvSetWatermarkUrl` | Flutter 叠图，不烧进画面 |
| 截图 | ✅ `captureFrame` | PNG 字节；宿主自行存盘 |
| 硬件解码 | ✅ `mpvSetHwdec` | 默认 `auto-safe` |
| GL 滤镜 | ❌ | GSY OpenGL 滤镜，桌面无对应管线 |
| GIF 录制 | ❌ | 需要独立编码器 |
| 弹幕 | ❌ | 无 B 站 XML 引擎 |
| 片头/中插广告 | ❌ | 无对等桌面广告 UI |
| 系统 PiP | ❌ | 无 Android 式系统画中画 |
| 列表滑动自动播 | ❌ | `GsyAutoPlayVideoList` 仅 Android |
| 切换 IJK/Exo 内核 | ❌ | 桌面只有 libmpv |
| 内嵌字幕文本推送 | ❌ | Exo overlay 专用 |
| 重力感应横竖屏 | ❌ | 桌面窗口自行旋转 |

## Windows

- 目标：Windows 10+ **x64**。首版不承诺 ARM64。
- CMake 配置时下载 LGPL `libmpv-2.dll`，并拷到应用目录。
- 也可预先放置：`windows/mpv/vendor/libmpv-2.dll`，或设置 `KINETIC_PLAYER_LIBMPV_DLL` / `KINETIC_PLAYER_LIBMPV_URL`。
- 手动下载：`bash windows/mpv/download_libmpv.sh`（需 `7z`）。
- libmpv 为 **LGPLv2.1+** 动态链接；插件本身仍为 MIT。

```bash
cd example
flutter run -d windows
```

## Linux

依赖系统 libmpv（pkg-config `mpv`）：

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

Wayland 与 X11 均走 Texture，不使用 `--wid` 嵌入。硬件解码默认 `hwdec=auto-safe`（vaapi / nvdec 等由 mpv 探测）。

## Channel

- 插件级：`com.example.player/mpv`（`create` / `destroy`）
- 实例：`com.example.player/mpv_<viewId>`（与 GSY/SG 相同的公共 method 名）

## 可选替代

若你更需要 GStreamer 管线而不是 libmpv，仍可使用独立包 [GstPlayer](https://pub.dev/packages/gstplayer)。本插件桌面内核是 libmpv，不必再引入 GstPlayer。

## 3.0 UI/功能核查与修复

Windows/Linux 共用同一 Dart 桌面控制栏和同一 C++ mpv core。已修复：运行时 UI 配置与倍速/音量/静音/循环/镜像/连播状态不同步；拖动滑块连续发送 seek；顶层双击手势影响按钮点击；窄窗口工具栏溢出；播放器创建后立即销毁时的资源泄漏；清空封面仍显示旧封面；手动下一集被自动连播开关阻止；mpv redirect 被错误显示为播放失败。音量调为正值会解除静音。

新增空格播放/暂停、左右方向键 5 秒（Shift 为 30 秒）、M 静音、F 全屏、L 锁定、Escape 退出全屏；快捷键只作用于获得焦点的播放器，不占用带 command/control/alt 的快捷键。关闭控制栏或纯播放模式时不接管键盘。

原 mpvStartFullscreen 仍兼容 toggle；公共 enterFullscreen 使用新的幂等命令。全屏按钮查询真实窗口状态后进入或退出。字幕/视频轨、网络速度、截图和公共配置继续保留。系统 PiP、SG 高级合成/导出/缓存并未变成 mpv 功能；Web 的浏览器插件也不适用于桌面。

验证使用无设备 Flutter 组件测试和共享 C++ core 语法检查，未验证 Windows D3D、Linux GTK/Wayland 的实际渲染、窗口回调或驱动行为，需在目标系统手动验收。
