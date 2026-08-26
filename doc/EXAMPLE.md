# Example 示例

English version: [EXAMPLE_EN.md](EXAMPLE_EN.md)

Example 位于 `kinetic_player/example/`，按平台演示已完整交付的能力。

## 运行

Darwin（iOS / macOS）默认使用 **Swift Package Manager**（与插件一致），无需 Podfile / 额外脚本：

```bash
cd kinetic_player/example
flutter pub get
flutter run          # Android / iOS 真机
flutter run -d macos
flutter run -d chrome
```

macOS 需 `MACOSX_DEPLOYMENT_TARGET = 11.0`（Example 已配置）。若在 Xcode 直编遇 SPM 版本冲突，见 [DARWIN_SGPLAYER.md — SPM 包装包最低版本](DARWIN_SGPLAYER.md#spm-包装包最低版本)（可手动改 `FlutterGeneratedPluginSwiftPackage/Package.swift`，或先 `flutter run -d macos`）。

## 界面结构

1. **视频区域** — `CommonVideoPlayerViewBuilder`；按平台注入 `KineticUiConfig` / `ArtplayerUiConfig`
2. **公共控制** — 片源、**控制栏语言**、音轨、倍速、音量/静音、循环、截图、Play/Pause/Seek
3. **Android GSY** — 内核切换、GL 滤镜、字幕、弹幕、水印、片头/中插广告、GIF、保存截图、手动 PiP、播放列表、网速、Exo 视频轨、显示比例、纯播放、全屏；AppBar 进入**列表滑动自动播放**
4. **iOS / macOS SG** — 旋转/镜像、封面/末帧、音高、VR/VRBox/视口、后台策略（iOS）、Demuxer、视频轨、多段资源、seekable、全屏
5. **Web Artplayer** — 创建启用 danmuku / Document PiP / HLS·DASH 控制等；面板含 Video PiP、Document PiP、发送弹幕、可用插件列表

## 平台能力速查（Example 内）

| 能力 | Android | iOS/macOS | Web |
|------|---------|-----------|-----|
| 原生底栏 / 音轨 | ✅ | ✅ | Artplayer 控件 |
| 滑动手势 | ✅ | iOS ✅ / macOS ❌ | Artplayer |
| PiP | ✅ 自动+手动 | ❌ | Video / Document |
| 弹幕 | ✅ 含全屏 | ❌ | ✅ 插件 |
| 字幕 | ✅ | ❌ | 插件已启用 |
| 水印 / 滤镜 / GIF / 广告 | ✅ | ❌ | — |
| 列表自动播 | ✅ 独立页 | ❌ | — |
| VR / 音高 / 多段 | — | ✅ | — |

详情见 [GSY_FEATURES.md](GSY_FEATURES.md) / [DARWIN_SGPLAYER.md](DARWIN_SGPLAYER.md) / [WEB_ARTPLAYER.md](WEB_ARTPLAYER.md)。
