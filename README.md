<p align="center">
  <img src="doc/logo.png" alt="Kinetic Player" width="280" />
</p>

# kinetic_player

最强大的移动端android和ios双核 Flutter 视频播放器插件支持各种格式：**Android** 使用 [GSYVideoPlayer 13.1.0](https://github.com/CarGuo/GSYVideoPlayer)，**iOS** 使用 [libobjc/SGPlayer](https://github.com/libobjc/SGPlayer)（master）。

仓库：[github.com/wanwenfeng4798/kinetic_player](https://github.com/wanwenfeng4798/kinetic_player)

## 特性

- 统一的 `CommonVideoController` API（播放 / 暂停 / 跳转 / 缩放 / 倍速 / 音量 / 音轨 / 循环 / 截图等）
- 平台自动选型：Android → GSY，iOS → SGPlayer
- B 站风格原生控制栏：竖向音量弹窗（拖动显示百分比）、设置面板选音轨、统一进度条与底栏图标尺寸
- iOS 支持滑动手势调进度 / 音量 / 亮度（与 Android 共用 `enableNativeControls`）
- Android 画中画（PiP）**默认开启**（API 26+；播放中切后台自动进入，含 GSY 自动播放场景）
- 独有功能通过显式向下转型调用（不污染公共接口）
- iOS 支持 **CocoaPods** 与 **Swift Package Manager (SPM)** 双集成
- iOS 预编译 `SGPlayer.xcframework` 可通过 **GitHub Release** 下载，避免本地编译

## 文档

| 文档 | 说明 |
|------|------|
| [doc/USAGE.md](doc/USAGE.md) | 集成步骤、公共 API、原生 UI、平台差异、PiP 配置 |
| [doc/GSY_FEATURES.md](doc/GSY_FEATURES.md) | Android GSY 高级能力对照表 |
| [doc/EXAMPLE.md](doc/EXAMPLE.md) | Example 应用说明 |
| [doc/IOS_SGPLAYER.md](doc/IOS_SGPLAYER.md) | SGPlayer 预编译产物、Release 发布、本地编译 |

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

完整示例见 [doc/EXAMPLE.md](doc/EXAMPLE.md) 与 `example/` 目录。
# HDR 视频测试链接汇总

本文件整理了用于测试 HDR 视频显示及播放器硬件解码能力的稳定直链。
## 可以直接复制以下 .m3u8 或 .mpd 链接粘贴至播放器（如 GSYVideoPlayer、SGPlayer）中开启测试：
测试场景,协议/格式,直链 URL
虚拟频道 (45s 无缝切换),HLS,[https://virtual-channel.unified-streaming.com/demo_channel-stable.isml/.m3u8](https://virtual-channel.unified-streaming.com/demo_channel-stable.isml/.m3u8)
虚拟频道 (45s 无缝切换),DASH,[https://virtual-channel.unified-streaming.com/demo_channel-stable.isml/.mpd](https://virtual-channel.unified-streaming.com/demo_channel-stable.isml/.mpd)
标准 4K VOD 点播 (Tears of Steel),HLS,[https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8](https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8)
标准 4K VOD 点播 (Tears of Steel),DASH,[https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.mpd](https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.mpd)
SCTE-35 动态广告插播,HLS,[https://live-dai.unified-streaming.com/live/scte35/scte35.isml/.m3u8](https://live-dai.unified-streaming.com/live/scte35/scte35.isml/.m3u8)
SCTE-35 动态广告插播,DASH,[https://live-dai.unified-streaming.com/live/scte35/scte35.isml/.mpd](https://live-dai.unified-streaming.com/live/scte35/scte35.isml/.mpd)
低延迟直播 (LL-DASH),DASH,[https://livesim.dashif.org/livesim/testpic_2s/Manifest.mpd](https://livesim.dashif.org/livesim/testpic_2s/Manifest.mpd)

## 1. Jellyfish 4K HDR 测试流 (水母测试片)
HEVC 10-bit 编码，是发烧友测试显示设备 HDR 映射能力的金标准。
* **10bit 高码率测试
  `https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8`
* **140 Mbps 码率版本**
  `http://www.thismonkey.com/files/2160p/jellyfish-140-mbps-4k-uhd-hevc-10bit.mkv`
* **400 Mbps 极限码率版本**
  `http://www.thismonkey.com/files/2160p/jellyfish-400-mbps-4k-uhd-hevc-10bit.mkv`
  *(提示：码率较高，建议下载至本地后播放)*

## 2. 《特警判官》(Dredd) 4K 测试片段
用于测试电影场景下的 HDR 色彩表现。

* **测试片段 1**
  `http://www.thismonkey.com/files/2160p/dredd-1.mkv`
* **测试片段 2**
  `http://www.thismonkey.com/files/2160p/dredd-2.mkv`

## 平台支持

| 平台 | 内核 | 真机 | 模拟器 | 画中画 |
|------|------|------|--------|--------|
| Android | GSYVideoPlayer 13.1.0 | ✅ | ✅ | ✅ 默认开启 |
| iOS | SGPlayer master | ✅ | ❌（FFmpeg 预编译仅 arm64 真机） | ❌ |

## 许可证

本插件代码采用 [MIT License](LICENSE)。

SGPlayer 为独立第三方项目，其许可证以 [libobjc/SGPlayer](https://github.com/libobjc/SGPlayer) 仓库为准。
