# macOS SGPlayer 二进制集成

macOS 端与 iOS 一样使用 **SGPlayer**（[wanwenfeng4798/SGPlayer](https://github.com/wanwenfeng4798/SGPlayer)），通过预编译 `SGPlayer.xcframework` 集成。脚本与产物均在 **`darwin/`**（`darwin/scripts/sgplayer`、`darwin/Frameworks/{ios,macos}`）。

## 与 iOS 的差异

| 项 | iOS | macOS |
|----|-----|-------|
| 产物目录 | `darwin/Frameworks/ios/SGPlayer.xcframework` | `darwin/Frameworks/macos/SGPlayer.xcframework` |
| Manifest | `darwin/sgplayer/manifest.ios.json` | `darwin/sgplayer/manifest.macos.json` |
| Release 附件名 | `SGPlayer.xcframework.zip` | `SGPlayer-macOS.xcframework.zip` |
| 建议 Release tag | `sgplayer-v1.0.0` | `sgplayer-macos-v1.0.0` |
| SGPlayer 编译 | `./build.sh iOS build` + scheme `SGPlayer iOS` | `./build.sh macOS build` + scheme `SGPlayer macOS` |
| 源码克隆 | `darwin/third_party/SGPlayer` | 同上 |
| 原生 UI | 完整 B 站风格控制栏 | 与 iOS **同源**（`darwin/.../SgPlayerKit`，AppKit 实现） |
| Dart 视图 | `UiKitView` | `AppKitView` |
| 最低系统 | iOS 13 | **macOS 11**（chrome 使用 SF Symbols） |
| 共享 Bridge | `darwin/SgNativePlayerBridge`（UIKit / AppKit） | 同上 |

## 使用者：获取二进制

### 方式 A — SPM 远程 binaryTarget + 构建前钩子（推荐）

1. 在 `pubspec.yaml` 启用 SPM（与 iOS 相同）：

```yaml
flutter:
  config:
    enable-swift-package-manager: true
```

2. 宿主 macOS App 在 Xcode Scheme **Build → Pre-actions** 增加：

```bash
/bin/bash "${SRCROOT}/scripts/run_kinetic_sgplayer_prebuild.sh"
```

（可从 `example/macos/scripts/` 复制脚本，逻辑与 iOS Example 相同。）

3. 手动执行完整钩子：

```bash
bash kinetic_player/macos/scripts/spm_prebuild_hook.sh
```

钩子会：根据 manifest 生成 `macos/kinetic_player/Package.swift`（远程 `binaryTarget`），并 `ensure_sgplayer`（下载 → 本地编译）。

### 方式 B — 仅本地准备（无 Release 时）

```bash
bash kinetic_player/macos/scripts/ensure_sgplayer.sh
# 或从源码编译（首次 30–60 分钟，克隆在 darwin/third_party/SGPlayer）：
bash kinetic_player/macos/scripts/build_sgplayer.sh
```

### 方式 C — CocoaPods

`macos/kinetic_player.podspec` 的 `prepare_command` 会调用 `ensure_sgplayer.sh`。

### 环境变量

```bash
export KINETIC_PLAYER_SGPLAYER_DOWNLOAD_URL="https://github.com/.../SGPlayer-macOS.xcframework.zip"
bash kinetic_player/macos/scripts/ensure_sgplayer.sh
```

## 维护者：发布 macOS 预编译包

1. 本地构建：

```bash
bash kinetic_player/macos/scripts/build_sgplayer.sh
```

2. 打包（需先实现/运行 `macos/scripts/package_sgplayer_release.sh`，流程同 iOS，输出 `SGPlayer-macOS.xcframework.zip`）。

3. 创建 GitHub Release，例如 tag **`sgplayer-macos-v1.0.0`**，上传 zip。

4. 更新 `darwin/sgplayer/manifest.macos.json` 的 `download_url` 与 `sha256`，然后：

```bash
bash kinetic_player/macos/scripts/generate_package_swift.sh
```

5. 提交 manifest 与生成的 `Package.swift`（**不要**提交 zip）。

## manifest 字段

与 [IOS_SGPLAYER.md](IOS_SGPLAYER.md) 相同，另增 `sgplayer_repository` 指向 SGPlayer 源码仓库。

## Dart / API

- 路由：`TargetPlatform.macOS` 与 iOS 相同，使用 `SGVideoControllerImpl` 与 `CommonVideoPlayerView`（`AppKitView`）。
- 原生底栏、手势 seek/音量、设置音轨、封面等与 iOS 共用 **`darwin/kinetic_player/Sources/SgPlayerKit`** 源码（`#if os(macOS)` AppKit 分支）。

## 源码布局（与 iOS 对齐）

```
darwin/kinetic_player/Sources/SgPlayerKit/   ← iOS + macOS 共享（sg/*.swift）
darwin/SgNativePlayerBridge/               ← ObjC 桥
ios/kinetic_player/Sources/kinetic_player/   ← 仅 KineticPlayerPlugin + PrivacyInfo
macos/kinetic_player/Sources/kinetic_player/ ← 仅 KineticPlayerPlugin
```

## 许可

SGPlayer 遵循 [wanwenfeng4798/SGPlayer](https://github.com/wanwenfeng4798/SGPlayer) 仓库许可证；插件封装为 MIT。
