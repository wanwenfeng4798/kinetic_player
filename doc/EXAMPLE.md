# Example 示例

English version: [EXAMPLE_EN.md](EXAMPLE_EN.md)

Example 项目位于 `kinetic_player/example/`，演示双核播放器的集成与主要能力。

## 运行

```bash
cd kinetic_player/example

bash ../darwin/scripts/sgplayer/spm_prebuild_hook.sh ios
bash ../darwin/scripts/sgplayer/spm_prebuild_hook.sh macos

flutter pub get
flutter run          # iOS 真机 / Android
flutter run -d macos
```

Android 可直接 `flutter run`。iOS / macOS 细节见 [DARWIN_SGPLAYER.md](DARWIN_SGPLAYER.md)。

## 界面结构

`example/lib/main.dart` 包含：

1. **视频区域** — `CommonVideoPlayerViewBuilder` 加载远程片源，Android 附带 `GsyUiConfig`（原生控制栏、进度条缩略图等）
2. **设置 · 片源 / 音轨** — 下拉切换演示片源（含 Big Buck Bunny 与 4K HEVC 测试流）；音轨可下拉选择（`getAudioTracks` / `selectAudioTrack`），播放器内齿轮按钮亦可切换
3. **Android 专属** — GL 滤镜、字幕（WebVTT / 推送文本）、弹幕（B 站 XML）
4. **循环 / 截图** — `setLooping`、`captureFrame`
5. **公共控制** — Play / Pause / Seek 10s、状态与进度显示
6. **平台独有按钮** — Android：`GSY Fullscreen`；iOS：`SG Fullscreen`、`SG VR`

## 原生控制栏（Example 中已启用）

| 交互 | 说明 |
|------|------|
| 点击画面 | 显隐控制栏与中央播放按钮 |
| 喇叭 | 弹出竖向音量条（B 站风格）；**拖动时在滑轨左侧显示百分比** |
| 齿轮 | 弹出设置面板，选择音轨 |
| 全屏 | 窗口级全屏（图标与设置/音量同尺寸） |
| 滑动手势 | 横向调进度；左半屏纵向调亮度；右半屏纵向调音量（`enableNativeControls`） |
| 旋转 / 镜像 | 左转/右转 90°、复位、左右镜像、上下镜像（Android / iOS） |
| 封面 / 最后一帧 | 开关封面、播完保留最后一帧（Android / iOS） |
| SG 高级（iOS） | 音高、VR/VRBox、后台播放、demuxer 选项、视频轨；缓冲与错误显示 |

**画中画（Android）**：播放中（含自动播放或原生播放按钮）按 **Home** 或切到其他 App 会自动进入 PiP。Example 已在 `MainActivity` 与 `AndroidManifest` 中配置；`GsyUiConfig(pictureInPictureEnabled: true)` 已显式开启。

## 核心代码

```dart
CommonVideoPlayerViewBuilder(
  url: _selectedSource.url,
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

iOS / macOS Scheme Pre-action 已分别调用 `example/{ios,macos}/scripts/run_kinetic_sgplayer_prebuild.sh`（同步远程 binaryTarget + ensure 本地 xcframework）。详见 [DARWIN_SGPLAYER.md](DARWIN_SGPLAYER.md)。

依赖本地 path 插件：

```yaml
dependencies:
  kinetic_player:
    path: ../
```
