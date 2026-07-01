# kinetic_player

双核 Flutter 视频播放器插件：**Android** 使用 [GSYVideoPlayer 13.0.0](https://github.com/CarGuo/GSYVideoPlayer)，**iOS** 使用 [libobjc/SGPlayer](https://github.com/libobjc/SGPlayer)（master）。

仓库：[github.com/wanwenfeng4798/kinetic_player](https://github.com/wanwenfeng4798/kinetic_player)

## 特性

- 统一的 `CommonVideoController` API（播放 / 暂停 / 跳转 / 缩放 / 倍速 / 音量 / 音轨 / 循环 / 截图等）
- 平台自动选型：Android → GSY，iOS → SGPlayer
- B 站风格原生控制栏：竖向音量弹窗、设置面板选音轨、统一进度条配色
- Android 画中画（PiP）**默认开启**（API 26+，需宿主 Manifest 与 `onUserLeaveHint`）
- 独有功能通过显式向下转型调用（不污染公共接口）
- iOS 支持 **CocoaPods** 与 **Swift Package Manager (SPM)** 双集成
- iOS 预编译 `SGPlayer.xcframework` 可通过 **GitHub Release** 下载，避免本地编译

## 文档

| 文档 | 说明 |
|------|------|
| [docs/USAGE.md](docs/USAGE.md) | 集成步骤、公共 API、原生 UI、平台差异、PiP 配置 |
| [docs/GSY_FEATURES.md](docs/GSY_FEATURES.md) | Android GSY 高级能力对照表 |
| [docs/EXAMPLE.md](docs/EXAMPLE.md) | Example 应用说明 |
| [docs/IOS_SGPLAYER.md](docs/IOS_SGPLAYER.md) | SGPlayer 预编译产物、Release 发布、本地编译 |

## 快速开始

### 1. 添加依赖

```yaml
dependencies:
  kinetic_player:
    path: ../kinetic_player   # 或 pub.dev / git 引用
```

### 2. 启用 iOS SPM（推荐）

在应用与插件 `pubspec.yaml` 中：

```yaml
flutter:
  config:
    enable-swift-package-manager: true
```

### 3. 准备 iOS SGPlayer 二进制

**推荐（插件使用者）：** 下载预编译产物（维护者发布 Release 后）

```bash
bash kinetic_player/ios/scripts/ensure_sgplayer.sh
```

**或** 在 CocoaPods 模式下首次 `pod install` 时自动执行上述逻辑。

**备选：** 本地从源码编译（约 30–60 分钟，仅首次）

```bash
bash kinetic_player/ios/scripts/build_sgplayer.sh
```

### 4. 最小示例

```dart
import 'package:kinetic_player/kinetic_player.dart';

CommonVideoPlayerViewBuilder(
  url: 'https://example.com/video.mp4',
  creationParams: const GsyUiConfig(
    showVolumeToolbar: true,
    showSettingsButton: true,
    pictureInPictureEnabled: true, // Android only
  ).toCreationParams(),
  builder: (controller) {
    // controller 为 CommonVideoController，可按平台向下转型
  },
);
```

完整示例见 [docs/EXAMPLE.md](docs/EXAMPLE.md) 与 `example/` 目录。

## 平台支持

| 平台 | 内核 | 真机 | 模拟器 | 画中画 |
|------|------|------|--------|--------|
| Android | GSYVideoPlayer 13.0.0 | ✅ | ✅ | ✅ 默认开启 |
| iOS | SGPlayer master | ✅ | ❌（FFmpeg 预编译仅 arm64 真机） | ❌ |

## 许可证

本插件代码采用 [MIT License](LICENSE)。

SGPlayer 为独立第三方项目，其许可证以 [libobjc/SGPlayer](https://github.com/libobjc/SGPlayer) 仓库为准。
