# iOS / macOS SGPlayer 集成（Darwin）

kinetic_player 在 **iOS** 与 **macOS** 上共用同一套 SGPlayer 集成方案：

- 源码：`darwin/SgNativePlayerBridge`、`darwin/kinetic_player/Sources/SgPlayerKit`
- 脚本：`darwin/scripts/sgplayer/`（统一入口，参数 `ios` | `macos`）
- 产物：`darwin/Frameworks/{ios,macos}/SGPlayer.xcframework`
- Manifest：`darwin/sgplayer/manifest.{ios,macos}.json`

内核：[wanwenfeng4798/SGPlayer](https://github.com/wanwenfeng4798/SGPlayer)（master）。

## 平台对照

| 项 | iOS | macOS |
|----|-----|-------|
| 最低系统 | iOS 13 | **macOS 11**（控制栏 SF Symbols） |
| Dart 视图 | `UiKitView` | `AppKitView` |
| 产物 | `darwin/Frameworks/ios/SGPlayer.xcframework` | `darwin/Frameworks/macos/SGPlayer.xcframework` |
| Manifest | `darwin/sgplayer/manifest.ios.json` | `darwin/sgplayer/manifest.macos.json` |
| Release 附件 | `SGPlayer.xcframework.zip` | `SGPlayer-macOS.xcframework.zip` |
| Release tag | `sgplayer-v1.0.0` | `sgplayer-macos-v1.0.0` |
| 本地编译 | `./build.sh iOS` + scheme `SGPlayer iOS` | `./build.sh macOS` + scheme `SGPlayer macOS` |
| 模拟器 | ❌（FFmpeg 仅真机 arm64） | ✅（`macosx` arm64 + x86_64） |
| 画中画 | ❌ | ❌ |
| 出站网络（Example） | ATS / 系统网络 | App Sandbox 需 `com.apple.security.network.client` |

其余能力（底栏、手势、音轨、封面、SG API）两端同源，见 [USAGE.md](USAGE.md)。

## 目录结构

```
darwin/
  scripts/sgplayer/          ← 统一 bash（build / download / ensure / generate / package / prebuild）
  sgplayer/
    manifest.ios.json
    manifest.macos.json
  Frameworks/
    ios/SGPlayer.xcframework
    macos/SGPlayer.xcframework
  third_party/SGPlayer/      ← 本地编译时的源码克隆（gitignore）
  SgNativePlayerBridge/      ← ObjC 桥（UIKit / AppKit）
  kinetic_player/Sources/SgPlayerKit/   ← 共享 Swift UI / 播放逻辑

ios/kinetic_player/          ← Package.swift + KineticPlayerPlugin（+ PrivacyInfo）
macos/kinetic_player/        ← Package.swift + KineticPlayerPlugin
ios/kinetic_player.podspec   ← CocoaPods（prepare → ensure ios）
macos/kinetic_player.podspec ← CocoaPods（prepare → ensure macos）
```

统一调用：

```bash
bash darwin/scripts/sgplayer/<script>.sh ios|macos
```

## 能否把 xcframework 提交进 Git？

| 方式 | 是否可行 | 说明 |
|------|----------|------|
| 提交到 `main` | ❌ 不推荐 | GitHub 单文件硬限制约 100 MiB；产物远超 |
| **GitHub Release 附件** | ✅ **推荐** | 单文件最大 2 GiB |
| Git LFS | ⚠️ 可选 | 有带宽配额 |

**结论：** zip 放 Release，在对应 manifest 填写 `download_url` / `sha256`。

## 使用者：获取二进制

两端流程相同，只改平台参数 `ios` 或 `macos`。

### 方式 A — SPM + 构建前钩子（推荐）

1. 应用与插件 `pubspec.yaml`：

```yaml
flutter:
  config:
    enable-swift-package-manager: true
```

2. 宿主 App 的 Xcode Scheme → **Build → Pre-actions**（放在 Flutter `prepare` **之前**）：

```bash
/bin/bash "${SRCROOT}/scripts/run_kinetic_sgplayer_prebuild.sh"
```

- Example 已配置：`example/ios/scripts/`、`example/macos/scripts/`
- 宿主可复制对应脚本；Pre-action 须勾选 **Provide build settings from** → Runner（否则 `${SRCROOT}` 为空）

3. 钩子会：

1. 按 `darwin/sgplayer/manifest.<platform>.json` 生成 `{ios|macos}/kinetic_player/Package.swift`
2. `ensure_sgplayer`：已有产物 → 跳过；否则下载；再失败则本地编译
3. 将共享 Swift/ObjC 源与本地 xcframework **同步进** SPM 包目录（Flutter 会把包软链到 `ephemeral/Packages`，包外相对路径不可用）

### 方式 B — 手动 / CI

```bash
bash darwin/scripts/sgplayer/spm_prebuild_hook.sh ios
bash darwin/scripts/sgplayer/spm_prebuild_hook.sh macos
```

仅 ensure（不重写 Package.swift）：

```bash
bash darwin/scripts/sgplayer/ensure_sgplayer.sh ios
bash darwin/scripts/sgplayer/ensure_sgplayer.sh macos
```

`ensure` 顺序：

1. 已存在 `darwin/Frameworks/<platform>/SGPlayer.xcframework` → 跳过构建，仍同步 SPM 包内副本  
2. 读 manifest `download_url` → 下载解压  
3. 未配置或失败 → 源码编译（首次约 30–60 分钟）

### 方式 C — 环境变量指定 URL

```bash
export KINETIC_PLAYER_SGPLAYER_DOWNLOAD_URL="https://github.com/wanwenfeng4798/kinetic_player/releases/download/sgplayer-v1.0.0/SGPlayer.xcframework.zip"
bash darwin/scripts/sgplayer/ensure_sgplayer.sh ios
```

### 方式 D — CocoaPods

关闭 SPM 时，`ios/kinetic_player.podspec` / `macos/kinetic_player.podspec` 的 `prepare_command` 会调用 `ensure_sgplayer.sh`；`vendored_frameworks` 指向 `../darwin/Frameworks/{ios,macos}/...`。

### 方式 E — 本地编译

```bash
bash darwin/scripts/sgplayer/build_sgplayer.sh ios
bash darwin/scripts/sgplayer/build_sgplayer.sh macos

# 清理（ios 会清 third_party + 产物；macos 只清该平台 Frameworks）
bash darwin/scripts/sgplayer/build_sgplayer.sh ios clean
bash darwin/scripts/sgplayer/build_sgplayer.sh macos clean
```

## 宿主 App：构建前钩子

| 平台 | 复制脚本 | 环境变量（可选） |
|------|----------|------------------|
| iOS | `example/ios/scripts/run_kinetic_sgplayer_prebuild.sh` → `your_app/ios/scripts/` | `KINETIC_PLAYER_IOS_DIR` |
| macOS | `example/macos/scripts/run_kinetic_sgplayer_prebuild.sh` → `your_app/macos/scripts/` | `KINETIC_PLAYER_MACOS_DIR` |

解析顺序：环境变量 → path 依赖旁的 `../../{ios|macos}` → `.flutter-plugins-dependencies`。

macOS Example 的 Pre-action 还会把 `FlutterGeneratedPluginSwiftPackage` 的最低版本抬到 **11.0**，与插件 `Package.swift` 对齐。

## 维护者：发布预编译包

### 1. 构建

```bash
bash darwin/scripts/sgplayer/build_sgplayer.sh ios    # → darwin/Frameworks/ios/
bash darwin/scripts/sgplayer/build_sgplayer.sh macos  # → darwin/Frameworks/macos/
```

### 2. 打包并写回 manifest + Package.swift

```bash
bash darwin/scripts/sgplayer/package_sgplayer_release.sh ios
bash darwin/scripts/sgplayer/package_sgplayer_release.sh macos
```

输出示例：

- iOS：`darwin/Frameworks/ios/SGPlayer.xcframework.zip` + `.sha256`，更新 `manifest.ios.json`、`ios/kinetic_player/Package.swift`
- macOS：`darwin/Frameworks/macos/SGPlayer-macOS.xcframework.zip` + `.sha256`，更新 `manifest.macos.json`、`macos/kinetic_player/Package.swift`

### 3. 创建 GitHub Release

```bash
gh release create sgplayer-v1.0.0 \
  darwin/Frameworks/ios/SGPlayer.xcframework.zip \
  --repo wanwenfeng4798/kinetic_player \
  --title "SGPlayer iOS prebuilt v1.0.0"

gh release create sgplayer-macos-v1.0.0 \
  darwin/Frameworks/macos/SGPlayer-macOS.xcframework.zip \
  --repo wanwenfeng4798/kinetic_player \
  --title "SGPlayer macOS prebuilt v1.0.0"
```

### 4. 提交（不要提交 zip）

- `darwin/sgplayer/manifest.ios.json` / `manifest.macos.json`
- `ios/kinetic_player/Package.swift` / `macos/kinetic_player/Package.swift`

### 5. 验证下载

```bash
rm -rf darwin/Frameworks/ios/SGPlayer.xcframework
bash darwin/scripts/sgplayer/download_sgplayer.sh ios
ls darwin/Frameworks/ios/SGPlayer.xcframework
```

手动改 manifest 后：

```bash
bash darwin/scripts/sgplayer/generate_package_swift.sh ios
bash darwin/scripts/sgplayer/generate_package_swift.sh macos
```

## manifest 字段

| 字段 | 说明 |
|------|------|
| `version` | 预编译版本，与 Release tag 对应 |
| `sgplayer_branch` | SGPlayer 分支（本地编译） |
| `sgplayer_repository` | SGPlayer git 地址 |
| `asset_name` | Release 附件名 |
| `download_url` | HTTPS 下载地址；空则跳过下载、走本地编译（macOS 本地 fallback 时 SPM 使用包内 `SGPlayer.xcframework` path） |
| `sha256` | zip SHA256（与 `swift package compute-checksum` 一致） |

## SPM 包内同步说明

Flutter 将 `{ios|macos}/kinetic_player` 软链到 `ephemeral/Packages`。因此：

- `Package.swift` 的 `binaryTarget` / `target.path` **不能**使用跳出包根的 `../../darwin/...`
- `ensure_sgplayer` 会把 `SgPlayerKit`、`SgNativePlayerBridge` 以及（本地 path 模式下的）xcframework **复制**到包内 `Sources/` / `SGPlayer.xcframework`
- 这些副本已 `.gitignore`；**请只改 `darwin/` 下的权威源码**，再跑 ensure / prebuild

Swift 目标结构：`SgNativePlayerBridge`（ObjC）+ `kinetic_player`（含同步进来的 SgPlayerKit Swift，依赖 `FlutterFramework`）。中间独立 Swift target 拿不到 Flutter 框架搜索路径。

## 平台视图 API（iOS vs macOS）

两端都支持 Flutter 平台视图，但原生 API 形态不同：

| | iOS | macOS |
|--|-----|-------|
| 协议 | `FlutterPlatformView` | 无同名协议 |
| Factory 返回 | `FlutterPlatformView` | **`NSView`** |
| 创建方法 | `create(withFrame:viewIdentifier:arguments:)` | `create(withViewIdentifier:arguments:)` |

实现见 `darwin/.../SgVideoPlatformView.swift`（`#if os` 分支）。

## Example 注意

- **macOS**：`DebugProfile.entitlements` / `Release.entitlements` 需 `com.apple.security.network.client`，否则沙盒下无法拉远程片源。
- **macOS 部署版本**：插件与 Example 均为 **11.0**；若 Flutter 生成包仍为 10.15，Example Pre-action 会抬到 11.0。
- `Failed to foreground app; open returned 1`：多为 Flutter 拉前台失败，可从 Dock 点开 App，一般与播放无关。

## 已暴露的 SG 高级能力

见 [USAGE.md](USAGE.md) 与 `lib/src/sg/sg_video_features.dart`（iOS / macOS 共用 Dart 侧 SG API）。

## 第三方许可

SGPlayer 遵循 [wanwenfeng4798/SGPlayer](https://github.com/wanwenfeng4798/SGPlayer) 仓库许可证；本插件封装为 [MIT](../LICENSE)。
