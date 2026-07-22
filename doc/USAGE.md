# 使用指南

English version: [USAGE_EN.md](USAGE_EN.md)

## 架构概览

```
Dart 层
  CommonVideoController          ← 纯公共 API
  CommonVideoPlayerView          ← 平台原生视图
  CommonVideoPlayerFactory       ← Android→GSY / iOS·macOS→SG 自动选型
       │
       ├── GSYVideoControllerImpl   (Android 独有 API)
       └── SGVideoControllerImpl    (iOS / macOS 独有 API)
```

Channel 命名：

- Android GSY：`com.example.player/gsy_<viewId>`
- iOS / macOS SG：`com.example.player/sg_<viewId>`

PlatformView 类型：

- Android：`com.example.player/gsy_view_ui`（`AndroidView`）
- iOS：`com.example.player/sg_view_ui`（`UiKitView`）
- macOS：`com.example.player/sg_view_ui`（`AppKitView`）

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

- `io.github.carguo:gsyvideoplayer-java:13.1.0`
- `io.github.carguo:gsyvideoplayer-exo2:13.1.0`
- `io.github.carguo:gsyvideoplayer-arm64:13.1.0`

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

2. **准备二进制**（任选其一）：

```bash
bash darwin/scripts/sgplayer/spm_prebuild_hook.sh ios
bash darwin/scripts/sgplayer/spm_prebuild_hook.sh macos
```

- SPM：`Package.swift` 远程 `binaryTarget(url:checksum:)`，Xcode 解析时下载  
- Example 已在 Scheme **Pre-action** 中调用钩子（同步 Package.swift + `ensure_sgplayer`）  
- CocoaPods：`prepare_command` 同样调用 `ensure_sgplayer.sh`  

3. **运行**：

```bash
flutter pub get
flutter run          # iOS 真机
flutter run -d macos
```

> iOS 模拟器暂不支持（FFmpeg 预编译仅真机 arm64）。  
> 宿主 App 请添加 Pre-action，见 [DARWIN_SGPLAYER.md](DARWIN_SGPLAYER.md)。  
> macOS Example 需 `com.apple.security.network.client` 出站网络权限。  
> iOS / macOS 均无系统 PiP；原生底栏与 SG API 共用。

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
| `captureFrame({highQuality, includeOverlay})` | 截图（Android 可含 UI overlay） |
| `dispose()` | 释放 |
| `playerState` | `ValueNotifier<CommonPlayerState>` |
| `position` / `duration` | 进度（原生侧约 250ms 节流推送） |

`CommonScaleMode`：`fit` / `fill` / `stretch`

`CommonPlayerState`：`idle` / `buffering` / `ready` / `playing` / `paused` / `completed` / `error`

`CommonAudioTrack` 字段：`index`、`label`、`language`、`selected`

## 视图组件

### CommonVideoPlayerViewBuilder（推荐）

自动创建 PlatformView 并在就绪后回调 controller：

```dart
CommonVideoPlayerViewBuilder(
  url: videoUrl,
  creationParams: const GsyUiConfig(
    enableNativeControls: true,
    showFullscreenButton: true,
    showLockButton: true,
    showVolumeToolbar: true,      // 底部喇叭按钮（弹出竖向音量条）
    showSettingsButton: true,     // 底部齿轮按钮（弹出设置面板，含音轨）
    pictureInPictureEnabled: true, // Android 默认开启 PiP
    previewVttUrl: 'https://example.com/thumbs.vtt',
  ).toCreationParams(),
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

## 原生控制栏 UI（双端对齐）

Android（GSY）与 iOS / macOS（SGPlayer）均采用 B 站风格底部控制栏，进度条与音量条轨道色统一（`#4DE8B5` 进度 / 半透明白色轨道）。

| 能力 | Android | iOS / macOS | 配置 |
|------|---------|-------------|------|
| 中央播放/暂停 | ✅ | ✅ | `enableNativeControls` |
| 进度条 + 时间 | ✅ | ✅ | 原生默认 |
| 单击显隐控制栏 | ✅ | ✅ | 点击画面空白；播放中约 2.5s 自动隐藏 |
| **音量** | ✅ | ✅ | 点击**喇叭**弹出**竖向**音量条；拖动时在滑轨**左侧**显示百分比（如 `50%`），松手后隐藏 |
| **手势** | ✅ | ✅ | `enableNativeControls`：横向调进度；左半屏纵向调亮度；右半屏纵向调音量 |
| **音轨** | ✅ | ✅ | 点击**齿轮（设置）**弹出面板选择；亦可用 Dart `getAudioTracks` / `selectAudioTrack` |
| 全屏 | ✅ | ✅ | 全屏按钮（与设置/音量图标同尺寸 28dp）/ `gsyStartFullscreen()` / `sgStartFullscreen()` |
| 画中画 PiP | ✅ 默认开启 | ❌ 不支持 | `pictureInPictureEnabled`（仅 Android） |

> **音量（Android）**：开启 `showVolumeToolbar` 后，画面右侧滑动调节的是**播放器音量**（与喇叭弹窗同源），不再用系统音量条。音量弹窗打开或正在拖动滑轨时，右侧滑动调音量会被暂时禁用，避免与竖向滑轨冲突。

> **音量（iOS / macOS）**：右侧滑动同样调节播放器音量（灵敏度与 Android GSY 一致，约 3×）；音量弹窗打开或拖动滑轨时，右侧滑动调音量同样被禁用。

> **音量持久化**：通过滑轨或 `setVolume()` 设置的音量在暂停/恢复、播放完成重播、换源后会自动恢复，不会回到默认值。

> **音轨**：不在音量弹窗内选择，请在设置面板（齿轮）或 Flutter 层调用 `selectAudioTrack`。

> **画中画**：SGPlayer 使用自定义渲染，无法接入系统 `AVPictureInPictureController`，iOS / macOS 当前均不支持 PiP。

### 触摸区域说明

控制栏隐藏后，底部透明区域不再拦截点击，右下角与画面其他区域均可单击唤出/隐藏控制栏与中央播放按钮。

## 平台独有 API（向下转型）

公共接口**不包含**以下方法，需显式转型：

### Android — GSYVideoControllerImpl

```dart
if (controller is GSYVideoControllerImpl) {
  await controller.gsySwitchRenderCore(1); // 0=IJK, 1=Exo, 2=System
  await controller.gsyToggleDanmaku(enabled: true);
  await controller.gsyStartFullscreen();
  await controller.gsySetPreviewVttUrl('https://example.com/thumbs.vtt');
  await controller.gsySetUiConfig(const GsyUiConfig(videoTitle: 'Demo'));
  await controller.gsyEnterPictureInPicture(); // 手动进入 PiP
  await controller.gsySetRenderRotation(90);
  await controller.gsySetMirrorHorizontal(enabled: true);
  await controller.gsySetMirrorVertical(enabled: true);
  await controller.gsySetCoverUrl('https://example.com/cover.jpg');
  await controller.gsySetKeepLastFrameWhenComplete(enabled: true);
}
```

#### GSY 原生 UI 配置项（`GsyUiConfig`）

| 字段 | 默认 | 说明 |
|------|------|------|
| `enableNativeControls` | `true` | 双端：滑动手势（进度/音量/亮度）；Apple 端同时控制底栏显隐 |
| `enableNativeControlsFullscreen` | `true` | Android 全屏手势；Apple 端与 `enableNativeControls` 共用 |
| `showFullscreenButton` | `true` | 全屏按钮 |
| `showLockButton` | `true` | 全屏锁屏按钮（Android） |
| `showVolumeToolbar` | `true` | 喇叭按钮 + 竖向音量弹窗 |
| `showSettingsButton` | `true` | 齿轮按钮 + 设置面板（音轨） |
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

`creationParams` / `gsyUi` 字段：`enableNativeControls`、`showVolumeToolbar`、`showSettingsButton`、`showFullscreenButton`、`dismissControlTime`、`pictureInPictureEnabled`（Apple 端读取但不生效）、`coverUrl`、`keepLastFrameWhenComplete`。

## 平台差异速查

| 能力 | Android (GSY) | iOS / macOS (SGPlayer) |
|------|---------------|------------------------|
| 循环 | 原生 `isLooping` | 结束时 `seek(0)+play` |
| 截图 overlay | `captureFrame(includeOverlay: true)` 含 UI | `includeOverlay` 无效 |
| 换源 | 重建播放器 | `replaceWithURL` / `sgReplaceWithSegments` |
| 全屏 | `gsyStartFullscreen()` | `sgStartFullscreen()` |
| 画中画 | 默认开启，需 Manifest + `onUserLeaveHint`；播放中（含自动播放）切后台进入 | 不支持 |
| 音轨 UI | 齿轮设置面板 | 齿轮设置面板 |
| 音量 UI | 喇叭竖向弹窗；拖动显示百分比；禁用 GSY 左侧音量手势 | 喇叭竖向弹窗 |
| 手势调节 | `enableNativeControls`：横向进度、左亮度、右音量 | 同左（底栏显隐一并受控） |
| 画面旋转 / 镜像 | `gsySetRenderRotation` / MirrorH/V | `sgSetRenderRotation` / MirrorH/V |
| 封面 | `gsySetCoverUrl` | `sgSetCoverUrl` |
| 保留最后一帧 | `gsySetKeepLastFrameWhenComplete` | `sgSetKeepLastFrameWhenComplete` |
| 缓冲 / 错误详情 | — | `buffered` / `playerError` |
| 音高 / VRBox / 多段 / demuxer | — | 见上表 |
| 部署注意 | — | iOS：真机；macOS 11+；沙盒需 `network.client` |

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
3. iOS 需在真机测试 SGPlayer；macOS 需 11.0+，并开启出站网络 entitlement。
4. 关闭画中画：`GsyUiConfig(pictureInPictureEnabled: false)`。
