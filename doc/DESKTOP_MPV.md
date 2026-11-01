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
| 纯播放 | ✅ `mpvSetPurePlayMode` | 隐藏工具栏，保留播放/暂停按钮 |
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

早期验证使用无设备 Flutter 组件测试和共享 C++ core 语法检查。2026-11-01 已通过 UU 在 Windows x64 主机实际编译、运行并完成下述基础回归；Linux GTK/Wayland 仍未在目标系统验收。

公共底栏现遵循与 Android/SGPlayer 相同的视觉顺序，窄窗口折行而非横向滚动，锁定按钮在右侧。设置、音量、倍速、清晰度弹层受当前播放器尺寸约束。7 项共用界面回归覆盖 240/280/360/720/1280 宽度、精确倍速及锁定/解锁；该结果不替代目标系统的原生运行验收。


## Windows 目标主机验证（2026-11-01）

通过 UU 向 Windows 桌面传输 Git 跟踪的源码包与脚本，未传输 Apple Framework/XCFramework、Flutter 构建目录或缓存。远端使用已有 Flutter 3.47.7、Dart 3.13.5 和 Visual Studio 工具链，成功构建 Debug 示例。

本轮修复：

- 使用 CMake 检出的 MSVC `CMAKE_AR` 生成 `mpv.lib`，避免普通终端找不到 `lib.exe` 时继续链接并报 18 个未解析 mpv 符号；导入库生成失败现在直接终止配置。
- 创建播放器时解析 Flutter 视图的顶层宿主 HWND，让窗口代理接收播放状态/进度事件，同时让全屏操作作用于应用窗口。插件注册时 Flutter 子视图可能尚未挂到宿主，不能提前固定顶层句柄。
- 集成测试补齐 `MaterialApp` 容器，为桌面工具栏的 Tooltip 提供 Overlay。

目标主机 `native_playback_suite_test.dart` 两项测试通过：本地播放推进、暂停、seek、倍速/音量/循环调用、视频尺寸、PNG 截图、销毁、播放列表手动下一项，以及重复进入/退出全屏。另人工观察到本地视频画面、完成后重播、14 秒跳转、设置/更多设置面板、窗口全屏恢复，项目原有 XGPlayer 360p 公网 MP4 成功出画面并显示 1:30 时长。

这些结果不表示所有开关、外部字幕、多音轨、所有媒体格式、驱动、音频听感或不同显示缩放均已验收，也不替代 Release 打包验证。Linux 尚未实机验证；整体发布/tag 上传仍待全部端调试完成。


### 完整验收进度（2026-11-01）

完整验收尚未通过，不能据此发布 tag。已取回 Windows full7/full8/full9 原始日志。

| 项目 | 当前结果 |
|---|---|
| Windows 基础原生播放套件 | 已通过 2/2 |
| Flutter 全部测试 | 新版设置弹窗 Windows 38/38 通过；Mac 既有版本 35/35 |
| Windows 扩展原生验收 | full7 完整通过：真实纹理与 RGBA 一致、垂直镜像恢复、VTT/SRT 显隐、实际 2x 倍速、EOF 重播、保留末帧、autoPlay:false、自动下一集、循环、纯播放按钮、水印图片、停止后恢复 |
| HTTP 配置与错误恢复 | full8 通过：请求头 / UA / Range、404 后重新加载、清除请求选项 |
| 公网源 | full7 为 9/18 通过；full8 Mux HLS 也通过，jsDelivr DNS 失败，部分 DASH 停在 buffering；后续运行被中断，不能推断其余格式无效。18 源中 17 个主 URL HTTP 可达，不能替代分片解码验收 |
| 音量 / 静音真实输出 | full9 通过：满音量峰值 0.172633、低音量 0.000172633、静音 0、恢复 0.172633；音量曲线非线性 |
| Windows Release | full8 构建成功，已检查打包 libmpv DLL 并计算 SHA256；full9 新版菜单 Release 构建也成功；人工交互验收尚未完成 |
| 设置弹窗 / 外部控制 | 新增分组、选中状态、更多设置返回/关闭、画幅及水印/封面/末帧/纯播放开关；控制器状态通知与示例外部按钮双向同步。静态检查通过，菜单回归 38/38 通过；示例外部按钮监听的最后修改仅静态检查通过 |
| 多显示器 / DPI、Linux 实机 | 尚未验收 |
| 桌面弹幕、广告 UI、系统 PiP 等功能差异 | 仍未实现，详见上方对照表，不能作为已验收功能 |

full9 完整公网源回归为 10/18 通过，8 项失败（jsDelivr MP4、BBB/Shaka DASH、TS、Ogg、MP3、MKV、FLV）。仍需隔离媒体与切源恢复问题，不能仅据连续运行结果删除全部失败源。full10 示例控制端监听源码和构建脚本已发送到 Windows，执行结果尚未取回。没有传输 iOS 或 Flutter 编译产物。公网源回归恢复自动音视频轨选择，避免前一文件的手动轨道 ID 干扰下一媒体。新结果必须以取回日志及实际显示为准；未完成项目不能标记通过，也不能发布 tag。
