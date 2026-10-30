# 使用指南

English version: [USAGE_EN.md](USAGE_EN.md)

最低 SDK：**Dart 3.13 / Flutter 3.47**。宿主应用请依赖 `material_ui: ^1.8.0`，并 `import 'package:material_ui/material_ui.dart'`（不要再 `import package:flutter/material.dart`）。

> 3.0: Darwin uses SGPlayer 2 native controls (iOS 15 / macOS 12). Runtime localization and per-button styling are not exposed by the SDK. See [Darwin integration](DARWIN_SGPLAYER_EN.md) for setup and migration.

## 3.0 统一 Flutter 入口

```dart
CommonVideoPlayerViewBuilder(
  config: KineticPlayerConfig(
    url: mediaUrl,
    playlist: mediaUrls,
    startIndex: 0,
    autoPlay: false,
    autoPlayNext: true,
    http: const KineticHttpRequestOptions(headers: {'Referer': 'https://example.com'}),
    ui: const KineticUiConfig(speed: 1.25, looping: false),
  ),
  builder: (controller) async {
    await controller.setPlaylist(mediaUrls, startIndex: 0, autoPlay: true);
    await controller.setAutoPlayNext(false);
    await controller.playNext(); // 手动下一集不受自动连播关闭影响
    await controller.enterFullscreen(); // 幂等；重复调用不会反向退出
    await controller.exitFullscreen();
  },
);
```

Android/iOS/macOS/Windows/Linux/Web 使用同一配置和操作参数；平台专有配置放在 platformOptions。旧 creationParams 保留兼容，合并优先级为 legacy < typed config < 显式 widget.url。config 是创建参数，运行时更新使用 setUiConfig / load / setPlaylist 等控制器方法。`load(url, http: ...)` 先更新请求选项再加载；原 switchVideoSource 保留已设置的请求选项。

公共扩展还统一了 setCoverUrl、setRenderRotation、setMirrorHorizontal/Vertical、setSubtitleSource 和 setSubtitlesEnabled；调用变换前可查询 supportsRenderTransform，Web 不伪造原生复合变换支持。

公共参数统一校验：倍速必须为正有限数，音量须为有限数并截断到 0–1，播放列表不能为空且起始索引必须有效。Web 自动播放仍受浏览器手势策略约束，无法通过 Flutter 参数绕过。

### 跨端核查结果

| 能力/UI | Android | iOS/macOS | Windows/Linux | Web |
| --- | --- | --- | --- | --- |
| 播放、暂停、跳转、倍速、音量、音轨、循环、PNG | GSY 原生 | SGPlayer 原生 | libmpv | Artplayer；音轨/截图受流格式/CORS 限制 |
| playlist/startIndex/autoPlay/autoPlayNext | 统一入口，GSY 原生列表 | 统一入口，SG 原生 session | 统一入口，mpv 适配 | 统一入口，新增列表适配 |
| 全屏进入/退出/状态 | 原生 | 原生宿主窗口适配 | 原生宿主窗口适配 | 浏览器全屏；需用户手势 |
| 快捷键与锁定 | 触控为主 | iOS 手势/macOS 原生键盘 | 新增键盘、锁定、窄窗口折行工具栏 | Artplayer 自带交互 |
| 运行时公共 UI 配置 | GSY 可更新，无换源重置 | SDK 暴露的配置可更新 | 已修复动态 UI/控制器状态同步 | SDK 暴露的配置可更新 |
| 本地化、颜色、逐按钮配置 | 支持公共配置 | SDK 未暴露部分字段，不能完全对齐 | 公共本地化/颜色/按钮；桌面专用布局 | Artplayer 自身支持范围 |
| 系统 PiP | Android 系统 | SG 原生；受宿主/系统限制 | 无系统 PiP 适配，不能声明一致 | 浏览器 Video/Document PiP |
| SG 高级字幕/滤镜/离线缓存/媒体导出 | 使用 GSY 自己的专有能力 | 通过 native 扩展完整接入高层 API | 无 SG 等价入口，保持独立能力 | 使用 Artplayer 插件 |

因此共同播放逻辑与参数已经统一，但全端的原生功能和 UI **并非完全一致**。桌面保留平台实现，但公共工具栏遵循统一视觉规范；平台不支持的能力不会用空实现伪装成功。Darwin 运行时 setLocale 仍会明确返回 UNSUPPORTED；完成封面和最后一帧策略由 SGPlayer 原生实现。

2026-10-29：Android 真机已通过 SGPlayer 公网视频和本地视频的播放/暂停/跳转/倍速/音量/循环/视频尺寸/PNG 截图测试，本地播放列表切换及重复进入/退出全屏也通过。iOS 本地视频及原项目 W3Schools 公网视频均已通过同组基本播放测试；公网媒体确认输出视频帧。此前的 DNS 失败发生于 App 无线数据权限未开启的阶段。Android 另外通过不同本地视频互相切换，以及暂停画面添加本地水印后的截图差异检查。Windows/Linux 仍未在目标系统编译原生插件。

示例同时保留四个 SGPlayer 本地视频与经可访问性核查的 18 个网络源。启动默认使用本地视频和本地封面；仅在用户选择网络媒体后加载对应远程内容。本地素材随 App 打包并写入临时目录，以文件 URL 交给原生播放器。播放公网视频不需要 iOS“本地网络”权限，访问局域网媒体时才需要；App 自身的无线数据访问权限需允许联网。

## 架构概览

```
Dart 层
  CommonVideoController          ← 纯公共 API
  CommonVideoPlayerView          ← 平台原生视图
  CommonVideoPlayerFactory       ← Android→GSY / iOS·macOS→SG / Web→Artplayer / Windows·Linux→libmpv
       │
       ├── GSYVideoControllerImpl        (Android 独有 API)
       ├── SGVideoControllerImpl         (iOS / macOS 独有 API)
       ├── ArtplayerVideoControllerImpl  (Web 独有 API)
       └── MpvVideoControllerImpl        (Windows / Linux 独有 API)
```

## 内核选型

默认按平台自动选型即可。**Windows / Linux 走内建 libmpv**，详见 [DESKTOP_MPV.md](DESKTOP_MPV.md)。

| 目标平台 | 选用内核 | 何时选用 |
|----------|----------|----------|
| Android | GSYVideoPlayer | 默认 |
| iOS / macOS | SGPlayer | 默认 |
| Web | Artplayer.js | 默认 |
| **Windows / Linux** | **libmpv** | 默认 |

若需要 GStreamer 管线，仍可使用独立包 [GstPlayer](https://pub.dev/packages/gstplayer)。

Channel 命名：

- Android GSY：`com.example.player/gsy_<viewId>`
- iOS / macOS SG：`com.example.player/sg_<viewId>`
- Web Artplayer：进程内 Dart 注册表（`ArtplayerViewRegistry`，无跨端 MethodChannel）
- Windows / Linux libmpv：`com.example.player/mpv`（create/destroy）+ `com.example.player/mpv_<viewId>`

PlatformView / Texture 类型：

- Android：`com.example.player/gsy_view_ui`（`AndroidView`）
- iOS：`com.example.player/sg_view_ui`（`UiKitView`）
- macOS：`com.example.player/sg_view_ui`（`AppKitView`）
- Web：`com.example.player/art_view_ui`（`HtmlElementView` + Artplayer.js）
- Windows / Linux：`com.example.player/mpv_view_ui`（Flutter `Texture` + Dart 控制栏）

## 集成

### pubspec.yaml

```yaml
dependencies:
  kinetic_player:
    path: ../kinetic_player

flutter:
  config:
    enable-swift-package-manager: true   # iOS 推荐开启 SPM
```

### Android

无需额外步骤。GSYVideoPlayer 通过 Gradle Maven 依赖自动拉取：

- `io.github.carguo:gsyvideoplayer-java:14.0.0`
- `io.github.carguo:gsyvideoplayer-exo2:14.0.0`
- `io.github.carguo:gsyvideoplayer-arm64:14.0.0`

**画中画（PiP）** 需在宿主 Activity 的 `AndroidManifest.xml` 中声明：

```xml
<activity
    android:name=".MainActivity"
    android:resizeableActivity="true"
    android:supportsPictureInPicture="true"
    android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
    ... />
```

> 注意：不要在 `configChanges` 中使用 `pictureInPictureMode`，当前 AAPT 不支持该 flag；已有 `screenSize|screenLayout` 等即可满足 PiP 场景。

并在 Activity 中转发生命周期（example 已配置）：

```kotlin
override fun onConfigurationChanged(newConfig: Configuration) {
  super.onConfigurationChanged(newConfig)
  KineticPlayerPlugin.handleConfigurationChanged(this, newConfig)
}

override fun onBackPressed() {
  if (KineticPlayerPlugin.handleBackPressed(this)) return
  super.onBackPressed()
}

override fun onUserLeaveHint() {
  super.onUserLeaveHint()
  KineticPlayerPlugin.handleUserLeaveHint(this)  // 播放中切后台自动 PiP
}
```

**PiP 触发条件**（0.0.3+）：

- 视频处于**实际播放中**（含 GSY 自动播放 `startAfterPrepared`、原生播放按钮，不限于 Flutter `play()`）
- `pictureInPictureEnabled: true`（默认）
- 设备 API 26+ 且支持 PiP
- Android 8–11：依赖 `onUserLeaveHint` 主动进入 PiP
- Android 12+：额外通过 `PictureInPictureParams.setAutoEnterEnabled` 在用户离开 Activity 时系统自动进入

按 **Home** 或切换到其他 App 即可验证；暂停状态下不会进入 PiP。

### iOS / macOS（SGPlayer，共用 Darwin）

两端流程一致，详见 [DARWIN_SGPLAYER.md](DARWIN_SGPLAYER.md)。

1. **启用 SPM**（推荐）：

```yaml
flutter:
  config:
    enable-swift-package-manager: true
```

2. **二进制**：SPM 首次解析前执行 `bash darwin/scripts/sgplayer/spm_prebuild_hook.sh ios`。CocoaPods 的 prepare_command 自动下载官方发布包。

3. **运行**：

```bash
flutter pub get
flutter run          # iOS 真机
flutter run -d macos
```

> iOS 模拟器暂不支持（FFmpeg 预编译仅真机 arm64）。
> macOS 部署版本需 **12.0+**（与插件 `Package.swift` 对齐）。
> macOS Example 需 `com.apple.security.network.client` 出站网络权限。
> iOS / macOS 均无系统 PiP；原生底栏与 SG API 共用。

### Web（Artplayer.js）

无需额外原生工程。通过 `HtmlElementView` 挂载 Artplayer，公共 API 与其它平台一致。

```bash
flutter pub get
flutter run -d chrome
```

Web 独有能力（`artPlugins`、HLS/DASH、Document PiP、弹幕 API、TS 打包等）见独立文档：

- 中文：[WEB_ARTPLAYER.md](WEB_ARTPLAYER.md)
- English：[WEB_ARTPLAYER_EN.md](WEB_ARTPLAYER_EN.md)

```dart
CommonVideoPlayerViewBuilder(
  url: videoUrl,
  creationParams: ArtplayerUiConfig(
    ui: const KineticUiConfig(
      enableNativeControls: true,
      pictureInPictureEnabled: true,
      locale: 'zh',
    ),
    artPlugins: {
      ArtplayerPluginKeys.hlsControl: true,
    },
  ).toCreationParams(),
  builder: (controller) { /* … */ },
);
```

### Windows / Linux（libmpv）

公共 API 不变。Windows 构建时下载最新 LGPL `libmpv-2.dll`（mpv 0.41 API）；Linux 需系统 `libmpv-dev` / `mpv-libs-devel`。详见 [DESKTOP_MPV.md](DESKTOP_MPV.md)。

```bash
flutter pub get
flutter run -d windows
flutter run -d linux
```

宿主继续使用 `CommonVideoPlayerViewBuilder` + `KineticUiConfig`，与其它平台相同。

## 公共 API

`CommonVideoController` 提供：

| 方法 / 属性 | 说明 |
|-------------|------|
| `play()` | 开始播放（播放结束后再次调用会先 seek 到开头再播） |
| `pause()` | 暂停 |
| `stop()` | 停止并重置 |
| `seekTo(Duration)` | 跳转 |
| `setScaleMode(CommonScaleMode)` | 缩放模式 |
| `setRate(double)` | 倍速 |
| `setVolume(double)` / `setMute(bool)` | 音量 / 静音 |
| `switchVideoSource(url, {autoPlay})` | 换源 |
| `getAudioTracks()` / `selectAudioTrack(index)` | 音轨列表 / 切换 |
| `getDuration()` / `getCurrentPosition()` | 读取当前进度（与 `duration`/`position` 一致） |
| `getVideoSize()` | 视频宽高 |
| `setLooping(bool)` | 循环（Android GSY 原生；iOS 播放结束时 seek(0)+play） |
| `setLocale(String)` | 控制栏语言（`zh` / `en` / `vi` / `ms` / `id` / `fil`；创建时用 `KineticUiConfig.locale`） |
| `setHttpRequestOptions(KineticHttpRequestOptions?)` | 自定义 User-Agent / HTTP 标头（下次换源生效；也可 `creationParams['userAgent']` / `headers`） |
| `captureFrame({highQuality, includeOverlay})` | 截当前帧，返回 PNG 字节 `Uint8List?`（Android 可含 UI overlay） |
| `onScreenshotCaptured` | 设置面板截图完成回调（PNG 字节；宿主自行保存，插件不写文件/相册） |
| `dispose()` | 释放 |
| `playerState` | `ValueNotifier<CommonPlayerState>` |
| `position` / `duration` | 进度（原生侧约 250ms 节流推送） |

`CommonScaleMode`：`fit` / `fill` / `stretch`

`CommonPlayerState`：`idle` / `buffering` / `ready` / `playing` / `paused` / `completed` / `error`

`CommonAudioTrack` 字段：`index`、`label`、`language`、`selected`

### HTTP 标头 / User-Agent（全平台）

```dart
await controller.setHttpRequestOptions(
  const KineticHttpRequestOptions(
    userAgent: 'MyApp/1.0',
    headers: {'Authorization': 'Bearer …', 'Referer': 'https://example.com/'},
  ),
);
await controller.switchVideoSource(url); // 换源时带上

// 或创建时：
creationParams: {
  'userAgent': 'MyApp/1.0',
  'headers': {'Referer': 'https://example.com/'},
  ...ui.toCreationParams(),
}
```

- Android / iOS / macOS / Windows / Linux：对媒体请求生效。
- Web：渐进式 MP4 **无法**自定义请求头；HLS/DASH 经 xhr 注入。浏览器通常禁止覆盖 `User-Agent`。
- Darwin 仍可用 `sgSetDemuxerOptions` 设 timeout / reconnect；UA/headers 与公共 API 写入同一 pending 袋。

## 视图组件

### CommonVideoPlayerViewBuilder（推荐）

自动创建 PlatformView 并在就绪后回调 controller：

```dart
CommonVideoPlayerViewBuilder(
  url: videoUrl,
  creationParams: {
    ...const KineticUiConfig(
      enableNativeControls: true,
      showFullscreenButton: true,
      showLockButton: true,
      showVolumeToolbar: true,      // 底部喇叭按钮（弹出竖向音量条）
      showSettingsButton: true,     // 底部齿轮按钮（弹出设置面板，含音轨）
      pictureInPictureEnabled: true, // Android 默认开启 PiP
      previewVttUrl: 'https://example.com/thumbs.vtt',
      locale: 'zh', // zh / en / vi / ms / id / fil
    ).toCreationParams(),
  },
  builder: (controller) {
    // 保存 controller 引用
  },
)
```

Android 默认使用 `EagerGestureRecognizer`，原生进度条/音量/亮度手势不会被 Flutter 抢走。若外层需要自定义手势竞争，可传入 `gestureRecognizers` 覆盖默认行为。

### CommonVideoPlayerView（低级）

```dart
CommonVideoPlayerView(
  url: videoUrl,
  onPlatformViewCreated: (viewId) {
    final controller = CommonVideoPlayerFactory.createAuto(viewId);
  },
)
```

## 原生控制栏与平台差异

3.0 的 Android 使用 GSY 原生视图，iOS/macOS 使用 SGPlaybackControls；Windows/Linux 使用共用的独立 Flutter 桌面 UI，Web 使用 Artplayer DOM UI。共同播放行为与参数见上方核查表，UI 不承诺逐像素一致。

Darwin 支持 native controls 开关、自动隐藏、锁定、原生键盘/手势、原生封面和 SDK 自带设置。上游未暴露的运行时本地化、颜色、逐按钮显隐以及完成封面策略不再由插件重复自绘。需要本地化自定义 UI 的宿主可关闭原生控制栏，通过公共控制器操作；原生高级 API 仍可用。

Android 的原生配置、GIF 与覆盖层见 GSY_FEATURES.md；桌面键盘、布局及运行时同步见 DESKTOP_MPV.md；SG 原生扩展方法清单见 DARWIN_SGPLAYER.md。系统 PiP 有实际平台与宿主限制，不再使用“所有平台都一致”的描述。

## 平台独有 API（向下转型）

公共接口**不包含**以下方法，需显式转型：

### Android — GSYVideoControllerImpl

```dart
if (controller is GSYVideoControllerImpl) {
  await controller.gsySwitchRenderCore(1); // 0=IJK, 1=Exo, 2=System
  await controller.gsyToggleDanmaku(enabled: true);
  await controller.gsyStartFullscreen();
  await controller.gsySetPreviewVttUrl('https://example.com/thumbs.vtt');
  await controller.gsySetUiConfig(const KineticUiConfig(videoTitle: 'Demo'));
  await controller.gsyEnterPictureInPicture(); // 手动进入 PiP
  await controller.gsySetRenderRotation(90);
  await controller.gsySetMirrorHorizontal(enabled: true);
  await controller.gsySetMirrorVertical(enabled: true);
  await controller.gsySetCoverUrl('https://example.com/cover.jpg');
  await controller.gsySetKeepLastFrameWhenComplete(enabled: true);
}
```

#### 公共 UI 配置项（`KineticUiConfig`）

Android / iOS / macOS / Web 共用。创建时经 `creationParams['ui']` 下发；Android 运行时可用 `gsySetUiConfig` 更新外观（**不**改语言）。

| 字段 | 默认 | 说明 |
|------|------|------|
| `enableNativeControls` | `true` | Android / iOS：滑动手势（进度/音量/亮度）；Apple 端同时控制底栏显隐。macOS：底栏显隐，无滑动手势（用进度条 + 喇叭/齿轮按钮） |
| `enableNativeControlsFullscreen` | `true` | Android 全屏手势；Apple 端与 `enableNativeControls` 共用 |
| `showFullscreenButton` | `true` | 全屏按钮 |
| `showLockButton` | `true` | 全屏锁屏按钮（Android） |
| `showVolumeToolbar` | `true` | 喇叭按钮 + 竖向音量弹窗 |
| `showSettingsButton` | `true` | 齿轮按钮 + 两级设置面板（截图；Android 含 GIF） |
| `accentColor` | `#FB7299` | 进度条 / 选中态强调色 |
| `pictureInPictureEnabled` | `true` | Android 播放中切后台自动 PiP（API 26+） |
| `showDragProgressTextOnSeekBar` | `false` | 拖动进度时间文字 |
| `previewVttUrl` | — | 进度条缩略图 WebVTT |
| `dismissControlTime` | `2500` | 播放中控制栏自动隐藏（ms） |
| `videoTitle` | `''` | 标题栏文字 |
| `speed` / `looping` | `1` / `false` | 初始倍速 / 循环 |
| `keepLastFrameWhenComplete` | `false` | 播完保留最后一帧（不盖封面） |
| `coverUrl` | — | 封面 / 海报图 URL |
| `thumbPlay` | `true` | 点击封面开始播放（Android） |
| `ijkEnableAccurateSeek` | `true` | IJK 精确 seek，减轻拖动进度条关键帧回弹（仅 IJK 内核） |
| `cacheWithPlay` | `true` | 边播边缓（HttpProxyCache）； |
| `locale` | `'zh'` | 控制栏语言：`zh` / `en` / `vi` / `ms` / `id` / `fil` |

其他 GSY 能力（滤镜、截图、GIF、字幕、列表等）见 [GSY_FEATURES.md](GSY_FEATURES.md)。

### iOS / macOS — SGVideoControllerImpl

```dart
if (controller is SGVideoControllerImpl) {
  await controller.sgStartFullscreen();
  await controller.sgSetDisplayMode(SgDisplayMode.vrBox);
  await controller.sgSetVrViewport(const SgVrViewport(degrees: 75, sensorEnable: true));
  await controller.sgSetPitch(1.2);
  await controller.sgSetDemuxerOptions(const SgDemuxerOptions(
    timeout: Duration(seconds: 20),
    reconnect: true,
    userAgent: 'MyApp',
    headers: {'Authorization': 'Bearer …'},
  ));
  await controller.sgReplaceWithSegments([
    SgMediaSegment(url: 'https://example.com/a.mp4'),
    SgMediaSegment(url: 'https://example.com/b.mp4'),
  ]);
  await controller.sgSetBackgroundPlaybackPolicy(
    const SgBackgroundPlaybackPolicy(pausesWhenEnteredBackground: false),
  );
  final tracks = await controller.sgGetVideoTracks();
  await controller.sgSelectVideoTrack(0);
  // 缓冲 / 错误
  controller.buffered;      // ValueNotifier<Duration>
  controller.playerError;   // ValueNotifier<String?>
}
```

| API | 说明 |
|-----|------|
| `buffered` / `sgGetBufferedPosition` | 缓冲进度 |
| `playerError` / `sgGetLastError` | 详细错误 |
| `sgSetPitch` / `sgGetPitch` | 音高（约 0.5–2.0） |
| `sgSetDisplayMode` / `sgSetVrViewport` | Plane / VR / VRBox + 视角 |
| `sgSetDemuxerOptions` | FFmpeg 超时 / 重连 / UA / headers |
| `sgReplaceWithSegments` | 多段 `SGMutableAsset` |
| `sgGetVideoTracks` / `sgSelectVideoTrack` | 视频轨 |
| `sgSetBackgroundPlaybackPolicy` | 后台 / 中断策略 |

`creationParams` / `ui` 字段：`enableNativeControls`、`showVolumeToolbar`、`showSettingsButton`、`showFullscreenButton`、`dismissControlTime`、`pictureInPictureEnabled`（允许后台自动 PiP）、`coverUrl`、`keepLastFrameWhenComplete`、`locale`。

### Windows / Linux — MpvVideoControllerImpl

```dart
if (controller is MpvVideoControllerImpl) {
  await controller.mpvStartFullscreen();
  await controller.mpvSetHwdec('auto-safe');
  await controller.mpvSetPlaylist(urls, startIndex: 0);
  await controller.mpvSetShowType(GsyShowType.ratio16x9);
  await controller.mpvCommand(['show-text', 'hello']);
}
```

| API | 说明 |
|-----|------|
| `mpvStartFullscreen` / `mpvExitFullscreen` | 宿主窗口全屏 |
| `mpvSetHwdec` / `mpvCommand` | 硬解 / 原始 mpv 命令 |
| `mpvSetRenderRotation` / `mpvSetMirrorHorizontal` | 旋转 / 水平镜像 |
| `mpvSetShowType` | 对齐 Android `GsyShowType` |
| `mpvSetPlaylist` / `mpvPlayNextInPlaylist` | 播放列表 / 下一集 |
| `mpvSetSubtitleUrl` / `mpvSetSubtitleEnabled` | 外挂字幕 |
| `mpvListVideoTracks` / `mpvGetNetSpeed` | 视频轨 / 网速 |
| `mpvSetCoverUrl` / `mpvSetWatermarkUrl` / `mpvSetPurePlayMode` | 封面 / 水印 / 纯播 |

详见 [DESKTOP_MPV.md](DESKTOP_MPV.md)。

### Web — ArtplayerVideoControllerImpl

完整插件表、HLS/DASH、Document PiP 与打包说明见 [WEB_ARTPLAYER.md](WEB_ARTPLAYER.md)。

```dart
if (controller is ArtplayerVideoControllerImpl) {
  await controller.togglePip();
  await controller.artEmitDanmuku({'text': 'hi', 'time': 1});
  controller.pipActive;
}
```

| API | 说明 |
|-----|------|
| `togglePip()` / `artToggleDocumentPip()` | Video / Document PiP |
| `artEmitDanmuku` / `artCallPlugin` | 弹幕 / 插件方法 |
| `artAvailablePlugins()` / `artSetUiConfig` | 插件键列表 / UI 更新 |

## 平台差异速查

| 能力 | Android (GSY) | iOS / macOS (SGPlayer) | Web (Artplayer) |
|------|---------------|------------------------|-----------------|
| 循环 | 原生 `isLooping`；`KineticUiConfig.looping` 创建生效 | 结束时 `seek(0)+play`；`KineticUiConfig.looping` / `speed` 创建生效 | Artplayer `loop` / 结束重播 |
| 截图 overlay | `captureFrame(includeOverlay: true)` 含 UI | `includeOverlay` 无效 | 当前帧 canvas（跨域可能失败） |
| 设置内截图 / GIF | 二级截图（`onScreenshotCaptured`）+ GIF | 仅截图（`onScreenshotCaptured`） | — |
| 换源 | 重建播放器 | `replaceWithURL` / `sgReplaceWithSegments` | `art.switchUrl` |
| 全屏 | `gsyStartFullscreen()` | `sgStartFullscreen()`（应用内 overlay） | Artplayer `fullscreen` 控件 |
| 画中画 | 默认开启，需 Manifest + `onUserLeaveHint` | 原生 sample-buffer PiP；后台自动进入，macOS 支持最小化自动进入 | `togglePip()` / Document PiP（见 [WEB_ARTPLAYER.md](WEB_ARTPLAYER.md)） |
| 弹幕 | `gsySetDanmakuUrl` / `gsyToggleDanmaku`（含全屏） | `native.loadDanmakuXml` / 原生弹幕开关 | `artPlugins.danmuku` |
| 字幕 | `gsySetSubtitleUrl` 等（含全屏） | 公共 `setSubtitleSource`；原生文件选择、WebVTT/SRT/ASS/双字幕 | `multipleSubtitles` / `jassub` 等插件 |
| 水印 / 滤镜 / GIF / 广告 | 见 [GSY_FEATURES.md](GSY_FEATURES.md) | 原生水印开关、滤镜、GIF 导出、片头/中插/跳过；见 [Darwin 功能](DARWIN_SGPLAYER.md) | 广告等见 Web 插件 |
| 列表滑动自动播放 | `GsyAutoPlayVideoList` | ❌ | 自行实现 |
| 音轨 UI | 齿轮设置面板 | 齿轮设置面板 | `AudioTrack` API（浏览器支持时） |
| 音量 UI | 喇叭竖向弹窗 | 喇叭竖向弹窗 | Artplayer 音量控件 |
| 手势调节 | `enableNativeControls` | iOS 同左；macOS 用进度条 + 喇叭/齿轮按钮 | Artplayer gesture（可关） |
| 画面旋转 / 镜像 | `gsySetRenderRotation` / MirrorH/V（含全屏） | `sgSetRenderRotation` / MirrorH/V | 经 `artplayerOptions` 扩展 |
| 封面 | `gsySetCoverUrl` | `sgSetCoverUrl` | `poster` / `coverUrl` |
| 保留最后一帧 | `gsySetKeepLastFrameWhenComplete` | `sgSetKeepLastFrameWhenComplete` | 浏览器默认行为 |
| 缓冲 / 错误详情 | — | `buffered` / `playerError` | `error` 状态 |
| 部署注意 | IJK 默认 arm64；混淆需宿主 ProGuard 规则；需转发 `handleBackPressed` | iOS：真机；macOS 12+；沙盒需 `network.client` | Chrome / Safari / 移动 Web；注意自动播放策略 |

Darwin（SG）支持公共配置 `enableNativeControls`、工具栏显示开关、`dismissControlTime`、`coverUrl`、`keepLastFrameWhenComplete`、`speed`、`looping`、`pictureInPictureEnabled` 和 `previewVttUrl`。WebVTT 缩略图解析、裁切与拖动显示均在原生 SDK 内执行。默认设置菜单提供字幕/弹幕文件加载、字幕/弹幕/水印开关、比例、镜像、循环、截图、纯播放、封面、最后一帧和后台 PiP；示例外部控制面板提供相同功能入口，纯播放后可从外部按钮恢复工具栏。Darwin 当前原生菜单使用统一中文文案；运行时 `setLocale` 尚未实现。`cacheWithPlay`、`rotateViewAuto`、`thumbPlay` 等仍属于 Android 特有配置。


## 监听状态

```dart
controller.playerState.addListener(() {
  final state = controller.playerState.value;
});

controller.position.addListener(() {
  final pos = controller.position.value;
});
```

## 注意事项

1. 每个 `CommonVideoPlayerViewBuilder` 会在 dispose 时自动释放 controller；若手动持有 controller，需在页面 dispose 时调用 `controller.dispose()`。
2. Android Activity 需转发 `onConfigurationChanged`、`onBackPressed`、`onUserLeaveHint`（见上文 Android 集成节）。
3. iOS 需在真机测试 SGPlayer；macOS 需 12.0+，并开启出站网络 entitlement。
4. 关闭画中画：`KineticUiConfig(pictureInPictureEnabled: false)`。
5. Web 使用 Artplayer.js；独有能力见 [WEB_ARTPLAYER.md](WEB_ARTPLAYER.md)。修改 `web/src` 后执行 `npm run build`。自动播放受浏览器策略限制。

SGPlayer v2.0.0 没有独立的 iOS 网络权限申请 API。会话加载远程 URL 时，即使 autoPlay=false，也可能准备媒体并请求网络；缓存下载、远程封面和字幕等按调用参数发起网络请求。网络权限提示由系统触发，首次拒绝或尚未授权时请求可能失败，授权后应重新加载媒体。

2026-10-29 网络源复核：移除重复请求返回 HTTP 403 的 W3Schools，以及连续连接超时的 filesamples。保留其余 15 个原项目来源，新增已验证响应的 Ogg、MP3 与 MPEG-TS，合计 18 个网络来源、9 种格式。检查包含实际 Range 响应与媒体签名；HLS/DASH 的清单可访问不保证所有分段和所有平台均能解码。

Android 示例全屏设置 `lockLand: true, autoFullWithSize: false`，让 GSY 原生方向管理旋转整个 Activity、工具栏和锁定按钮；`autoFullWithSize` 会覆盖 `lockLand` 的方向判断，不能同时用它保证横屏。真机回归包含全屏窗口宽大于高断言。

Android 横屏补充验证：修复 Flutter 混合合成视图覆盖全屏宿主的问题，并限制 GSY 全屏宿主到导航栏/刘海安全区域，避免右侧控件裁切。SM-G981B 真机通过横屏宽高、锁定按钮完整边界、锁定隐藏工具栏、解锁后恢复工具栏、退出全屏、换源和本地水印截图回归。


### 验收范围（2026-10-29）

Android 目前通过的是 SM-G981B 上的核心播放、暂停、跳转、倍速、音量、循环、尺寸、PNG、不同文件换源、列表下一集、横屏全屏与退出、原生锁定/解锁和本地水印。尚不能据此声明全部 Android 功能或全部屏幕通过：其他机型/平板/折叠屏/分屏，以及 PiP、GIF、广告、弹幕、各类字幕、音轨和全部网络格式仍需逐项运行验收。

Web 已通过 Chrome 的动态参数 JS 转换回归，覆盖 playlist、startIndex、autoPlay、autoPlayNext，避免动态接收者调用 jsify 的 NoSuchMethodError；完整示例 Web 编译、8 项 JS 测试与 TypeScript 检查通过。该结果不等于所有浏览器和所有媒体格式通过。

本地 SGPlayer 的 iPhone 离线整套播放、列表、下一集与全屏回归通过。samplelib 网络回归出现 DNS 解析失败，不能计为通过。

本地 SGPlayer 产物回归更新：iPhone 与 macOS 均通过单次启动的离线基本播放、截图、列表、下一集与全屏用例（各 2 项）。网络用例若预检失败，不再继续创建原生媒体播放器；先显示授权/连接提示，并在有限等待期间重试预检，成功后才加载媒体。调试网络测试入口会自动尝试联网，不能把该入口当作正常示例启动行为；正常示例默认本地视频及本地封面。


### 公共工具栏视觉规范

Web 与 Windows/Linux 共用界面已对齐原生端的底栏风格：黑色半透明背景、白色图标、粉色进度与圆形滑块，播放/当前时间/进度/总时长/倍速/设置/音量/全屏按同一顺序排列，锁定按钮居右。窄窗口采用折行布局，设置与倍速弹层限制在播放器边界内。字幕和清晰度等高级功能通过设置访问。

Web 复用 Artplayer 的播放、跳转、音量、选择器和插件 API；时间标签来自 SDK 已格式化的内容，不维护第二套时钟。弹幕发送行保留独立行，HLS/DASH 音轨及清晰度默认归入设置；网页 PiP 与视频 PiP 也保留设置入口。显示开关和主题色支持运行时同步。

验证范围：Chrome 使用真实本地 MP4，在无插件和示例插件组合下分别检查 240/280/360/720/1280 五种宽度、进度条实际高度、点击跳转、锁定阻止跳转、1.25x 倍速及菜单边界。Windows/Linux 共用组件通过同组宽度及弹层、锁定测试，但未在 Windows/Linux 目标系统实测原生窗口与解码。

Web 浏览器回归入口：先在 web/ 运行 `npm run build`，再运行 `npm run test:browser`；非默认 Chrome 路径可通过 `CHROME_EXECUTABLE` 指定。测试只访问本机临时服务器和随项目提供的 MP4。
