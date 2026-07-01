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
| `play()` | 开始播放 |
| `pause()` | 暂停 |
| `seekTo(Duration)` | 跳转 |
| `setScaleMode(CommonScaleMode)` | 缩放模式 |
| `dispose()` | 释放 |
| `playerState` | `ValueNotifier<CommonPlayerState>` |
| `position` / `duration` | 进度（原生侧 250ms 节流） |

`CommonScaleMode`：`fit` / `fill` / `stretch`

`CommonPlayerState`：`idle` / `buffering` / `ready` / `playing` / `paused` / `completed` / `error`

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

## 平台独有 API（向下转型）

公共接口**不包含**以下方法，需显式转型：

### Android — GSYVideoControllerImpl

```dart
if (controller is GSYVideoControllerImpl) {
  await controller.gsySwitchRenderCore(1); // 0=IJK, 1=Exo, 2=System
  await controller.gsyToggleDanmaku(enabled: true);
  await controller.gsyStartFullscreen(); // 原生窗口全屏（也可点播放器全屏按钮）
  await controller.gsySetPreviewVttUrl('https://example.com/thumbs.vtt');
  await controller.gsySetUiConfig(const GsyUiConfig(videoTitle: 'Demo'));
}
```

#### GSY 原生 UI（AndroidView 内嵌，与 StandardGSYVideoPlayer 默认一致）

| 能力 | 配置 / API |
|------|------------|
| 播放/暂停（中心按钮、双击） | 原生默认 |
| 单击显隐控制栏 | 原生默认 |
| 进度条拖动 / 缓冲条 | 原生默认 |
| 横向滑动快进、竖向音量/亮度 | `enableNativeControls` / `enableNativeControlsFullscreen` |
| 滑动快进/音量/亮度弹窗 | 原生默认 |
| 全屏窗口 / 退出全屏 | 全屏按钮、`gsyStartFullscreen()`、系统返回键 |
| 全屏锁屏 | `showLockButton` |
| 标题栏 | `videoTitle` |
| 移动网络流量提示 | `needShowWifiTip` |
| 错误点击重试 | `surfaceErrorPlay` |
| 自动旋转 / 横屏全屏 | `rotateViewAuto`、`lockLand`、`needOrientationUtils` |
| 进度条拖动时间文字 | `showDragProgressTextOnSeekBar` |
| 进度条缩略图预览 | `previewVttUrl` / `gsySetPreviewVttUrl` |
| 倍速 / 循环 | `setRate()` / `setLooping()` 或 `GsyUiConfig.speed` / `looping` |

宿主 Activity 需在 `onBackPressed` 中调用 `KineticPlayerPlugin.handleBackPressed(this)`，全屏时系统返回键才能退出 GSY 窗口全屏（example 已配置）。

完整 GSY 高级能力对照见 [GSY_FEATURES.md](GSY_FEATURES.md)（滤镜、截图、GIF、字幕、列表、PiP 等）。

### iOS — SGVideoControllerImpl

原生播放器界面（与 Android GSY 控制栏对齐）：

| 能力 | 说明 / API |
|------|------------|
| 播放 / 暂停 | 画面中央按钮；也可 `play()` / `pause()` |
| 进度条拖动 | 底部 Seek 条 + 当前/总时长 |
| 单击显隐控制栏 | 点击画面空白区域；播放中约 2.5s 自动隐藏 |
| 全屏 | 底部全屏按钮、`sgStartFullscreen()` / `sgExitFullscreen()` |
| 音量 | 底部音量条（`showVolumeToolbar`） |

```dart
if (controller is SGVideoControllerImpl) {
  await controller.sgStartFullscreen();
  await controller.sgExitFullscreen();
  final inFullscreen = await controller.sgIsFullscreen();
  await controller.sgSetVRMode(enabled: true);
  await controller.sgSetSyncGroupId('group-1');
}
```

`creationParams` 可配置：`showNativeControls`、`showVolumeToolbar`、`showFullscreenButton`、`dismissControlTime`（与 Android `gsyUi` 字段兼容）。

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
2. Android Activity 建议配置 `android:configChanges` 含 `orientation|screenSize`（GSY 全屏场景），并在 Activity 中转发：

```kotlin
override fun onConfigurationChanged(newConfig: Configuration) {
  super.onConfigurationChanged(newConfig)
  KineticPlayerPlugin.handleConfigurationChanged(this, newConfig)
}

override fun onBackPressed() {
  if (KineticPlayerPlugin.handleBackPressed(this)) return
  super.onBackPressed()
}
```
3. iOS 需在真机测试 SGPlayer 相关功能。
