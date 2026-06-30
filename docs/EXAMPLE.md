# Example 示例

Example 项目位于 `kinetic_player/example/`，演示双核播放器的最小集成。

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

1. **视频区域** — `CommonVideoPlayerViewBuilder` 加载远程 MP4
2. **控制面板** — Play / Pause / Seek 10s
3. **平台独有按钮** — 运行时按 controller 类型显示：
   - Android：`GSY Danmaku`
   - iOS：`SG VR`

## 核心代码

```dart
class _PlayerDemoPageState extends State<PlayerDemoPage> {
  CommonVideoController? _controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: CommonVideoPlayerViewBuilder(
              url: _demoUrl,
              builder: (controller) {
                if (!identical(_controller, controller)) {
                  setState(() => _controller = controller);
                }
              },
            ),
          ),
          _ControlPanel(controller: _controller),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
```

## 控制面板逻辑

```dart
// 公共控制
await controller?.play();
await controller?.pause();
await controller?.seekTo(const Duration(seconds: 10));

// 监听状态
ValueListenableBuilder<CommonPlayerState>(
  valueListenable: controller!.playerState,
  builder: (_, state, __) => Text('State: $state'),
);

// GSY 独有（Android）
if (controller is GSYVideoControllerImpl) {
  await controller.gsyToggleDanmaku(enabled: true);
}

// SG 独有（iOS）
if (controller is SGVideoControllerImpl) {
  await controller.sgSetVRMode(enabled: true);
}
```

## 演示 URL

默认使用 GitHub 托管的公开 MP4：

```
https://user-images.githubusercontent.com/28951144/229373695-22f88f13-d18f-4288-9bf1-c3e078d83722.mp4
```

可在 `main.dart` 中替换 `_demoUrl`。

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
