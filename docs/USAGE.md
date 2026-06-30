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
  builder: (controller) {
    // 保存 controller 引用
  },
)
```

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
}
```

### iOS — SGVideoControllerImpl

```dart
if (controller is SGVideoControllerImpl) {
  await controller.sgSetVRMode(enabled: true);
  await controller.sgSetSyncGroupId('group-1');
}
```

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
2. Android Activity 建议配置 `android:configChanges` 含 `orientation|screenSize`（GSY 全屏场景）。
3. iOS 需在真机测试 SGPlayer 相关功能。
