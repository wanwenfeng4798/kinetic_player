# Example 示例

Example 项目位于 `kinetic_player/example/`，演示双核播放器的集成与主要能力。

## 运行

```bash
cd kinetic_player/example

# iOS：先确保 SGPlayer 二进制存在
bash ../ios/scripts/ensure_sgplayer.sh

flutter pub get
flutter run
```

Android 可直接 `flutter run`。

## 界面结构

`example/lib/main.dart` 包含：

1. **视频区域** — `CommonVideoPlayerViewBuilder` 加载远程 MP4，Android 附带 `GsyUiConfig`（原生控制栏、进度条缩略图等）
2. **设置 · 音轨** — 下拉选择音轨（`getAudioTracks` / `selectAudioTrack`）；播放器内齿轮按钮亦可切换
3. **Android 专属** — GL 滤镜、字幕（WebVTT / 推送文本）、弹幕（B 站 XML）
4. **循环 / 截图** — `setLooping`、`captureFrame`
5. **公共控制** — Play / Pause / Seek 10s、状态与进度显示
6. **平台独有按钮** — Android：`GSY Fullscreen`；iOS：`SG Fullscreen`、`SG VR`

## 原生控制栏（Example 中已启用）

| 交互 | 说明 |
|------|------|
| 点击画面 | 显隐控制栏与中央播放按钮 |
| 喇叭 | 弹出竖向音量条（B 站风格） |
| 齿轮 | 弹出设置面板，选择音轨 |
| 全屏 | 窗口级全屏 |

Android 播放中按 Home 键可进入画中画（需 `MainActivity` 已配置 PiP，example 已配置）。

## 核心代码

```dart
CommonVideoPlayerViewBuilder(
  url: _DemoMedia.videoUrl,
  creationParams: isAndroid
      ? GsyUiConfig(
          enableNativeControls: true,
          showFullscreenButton: true,
          showVolumeToolbar: true,
          showSettingsButton: true,
          pictureInPictureEnabled: true,
          showDragProgressTextOnSeekBar: true,
          videoTitle: 'GSY Demo',
          previewVttUrl: _previewVttUri,
        ).toCreationParams()
      : null,
  builder: (controller) {
    setState(() => _controller = controller);
  },
)
```

## 控制面板逻辑

```dart
// 公共控制
await controller?.play();
await controller?.pause();
await controller?.seekTo(const Duration(seconds: 10));
await controller?.setLooping(true);
final path = await controller?.captureFrame(highQuality: true, includeOverlay: true);

// 音轨
final tracks = await controller?.getAudioTracks();
await controller?.selectAudioTrack(tracks.first.index);

// 监听状态
ValueListenableBuilder<CommonPlayerState>(
  valueListenable: controller!.playerState,
  builder: (_, state, __) => Text('State: $state'),
);

// GSY 独有（Android）
if (controller is GSYVideoControllerImpl) {
  await controller.gsyToggleDanmaku(enabled: true);
  await controller.gsyStartFullscreen();
}

// SG 独有（iOS）
if (controller is SGVideoControllerImpl) {
  await controller.sgSetVRMode(enabled: true);
  await controller.sgStartFullscreen();
}
```

## Android 宿主配置（example 已包含）

`example/android/app/src/main/AndroidManifest.xml`：

- `android:supportsPictureInPicture="true"`
- `android:resizeableActivity="true"`

`MainActivity.kt`：

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
  KineticPlayerPlugin.handleUserLeaveHint(this)
}
```

## 演示 URL

默认使用 W3Schools 公开 MP4：

```
https://www.w3schools.com/html/mov_bbb.mp4
```

可在 `main.dart` 的 `_DemoMedia.videoUrl` 中替换。

## 测试

```bash
cd kinetic_player
flutter analyze
flutter test
```

Integration test 位于 `example/integration_test/`。

## pubspec 配置

Example 已启用 SPM：

```yaml
flutter:
  config:
    enable-swift-package-manager: true
```

依赖本地 path 插件：

```yaml
dependencies:
  kinetic_player:
    path: ../
```
