# 使用指南

## 架构概览

```
Dart 层
  CommonVideoController          ← 纯公共 API
  CommonVideoPlayerView          ← 平台原生视图
  CommonVideoPlayerFactory       ← Android→GSY / iOS→SG 自动选型
       │
       ├── GSYVideoControllerImpl   (Android 独有 API)
       └── SGVideoControllerImpl    (iOS 独有 API)
```

Channel 命名：

- Android GSY：`com.example.player/gsy_<viewId>`
- iOS SG：`com.example.player/sg_<viewId>`

PlatformView 类型：

- Android：`com.example.player/gsy_view_ui`
- iOS：`com.example.player/sg_view_ui`

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

- `io.github.carguo:gsyvideoplayer-java:13.0.0`
- `io.github.carguo:gsyvideoplayer-exo2:13.0.0`
- `io.github.carguo:gsyvideoplayer-arm64:13.0.0`

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

### iOS

1. **准备 SGPlayer 二进制**（三选一，见 [IOS_SGPLAYER.md](IOS_SGPLAYER.md)）：
   - 下载 GitHub Release 预编译包（推荐）
   - `bash ios/scripts/ensure_sgplayer.sh`（自动：下载 → 本地编译）
   - CocoaPods 模式下 `pod install` 会调用 `ensure_sgplayer.sh`

2. **运行应用**（在 `example/ios` 或你的 App 的 `ios` 目录）：

```bash
flutter pub get
flutter run   # 真机
```

> iOS 模拟器暂不支持 SGPlayer（预编译 FFmpeg 仅真机 arm64）。

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

Android（GSY）与 iOS（SGPlayer）均采用 B 站风格底部控制栏，进度条与音量条轨道色统一（`#4DE8B5` 进度 / 半透明白色轨道）。

| 能力 | Android | iOS | 配置 |
|------|---------|-----|------|
| 中央播放/暂停 | ✅ | ✅ | `enableNativeControls` |
| 进度条 + 时间 | ✅ | ✅ | 原生默认 |
| 单击显隐控制栏 | ✅ | ✅ | 点击画面空白；播放中约 2.5s 自动隐藏 |
| **音量** | ✅ | ✅ | 点击**喇叭**弹出**竖向**音量条（非底部常驻条） |
| **音轨** | ✅ | ✅ | 点击**齿轮（设置）**弹出面板选择；亦可用 Dart `getAudioTracks` / `selectAudioTrack` |
| 全屏 | ✅ | ✅ | 全屏按钮 / `gsyStartFullscreen()` / `sgStartFullscreen()` |
| 画中画 PiP | ✅ 默认开启 | ❌ 不支持 | `pictureInPictureEnabled`（仅 Android） |

> **音轨**：不在音量弹窗内选择，请在设置面板（齿轮）或 Flutter 层调用 `selectAudioTrack`。

> **iOS 画中画**：SGPlayer 使用自定义 `videoRenderer`，无法接入系统 `AVPictureInPictureController`，当前不支持 PiP。

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
}
```

#### GSY 原生 UI 配置项（`GsyUiConfig`）

| 字段 | 默认 | 说明 |
|------|------|------|
| `enableNativeControls` | `true` | 非全屏手势与控制栏 |
| `enableNativeControlsFullscreen` | `true` | 全屏手势 |
| `showFullscreenButton` | `true` | 全屏按钮 |
| `showLockButton` | `true` | 全屏锁屏按钮 |
| `showVolumeToolbar` | `true` | 喇叭按钮 + 竖向音量弹窗 |
| `showSettingsButton` | `true` | 齿轮按钮 + 设置面板（音轨） |
| `pictureInPictureEnabled` | `true` | Android 播放中切后台自动 PiP（API 26+） |
| `showDragProgressTextOnSeekBar` | `false` | 拖动进度时间文字 |
| `previewVttUrl` | — | 进度条缩略图 WebVTT |
| `dismissControlTime` | `2500` | 播放中控制栏自动隐藏（ms） |
| `videoTitle` | `''` | 标题栏文字 |
| `speed` / `looping` | `1` / `false` | 初始倍速 / 循环 |

其他 GSY 能力（滤镜、截图、GIF、字幕、列表等）见 [GSY_FEATURES.md](GSY_FEATURES.md)。

### iOS — SGVideoControllerImpl

```dart
if (controller is SGVideoControllerImpl) {
  await controller.sgStartFullscreen();
  await controller.sgExitFullscreen();
  final inFullscreen = await controller.sgIsFullscreen();
  await controller.sgSetVRMode(enabled: true);
  await controller.sgSetSyncGroupId('group-1');
}
```

`creationParams` / `gsyUi` 兼容字段：`showNativeControls`、`showVolumeToolbar`、`showSettingsButton`、`showFullscreenButton`、`dismissControlTime`、`pictureInPictureEnabled`（iOS 读取但不生效）。

## 平台差异速查

| 能力 | Android (GSY) | iOS (SGPlayer) |
|------|---------------|----------------|
| 循环 | 原生 `isLooping` | 结束时 `seek(0)+play` |
| 截图 overlay | `captureFrame(includeOverlay: true)` 含 UI | `includeOverlay` 无效 |
| 换源 | 重建播放器 | `replaceWithURL` |
| 全屏 | `gsyStartFullscreen()` | `sgStartFullscreen()` |
| 画中画 | 默认开启，需 Manifest + `onUserLeaveHint` | 不支持 |
| 音轨 UI | 齿轮设置面板 | 齿轮设置面板 |
| 音量 UI | 喇叭竖向弹窗 | 喇叭竖向弹窗 |

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
3. iOS 需在真机测试 SGPlayer 相关功能。
4. 关闭画中画：`GsyUiConfig(pictureInPictureEnabled: false)`。
