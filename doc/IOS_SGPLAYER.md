# iOS SGPlayer 二进制集成

kinetic_player 的 iOS 端依赖预编译的 `SGPlayer.xcframework`（约 250 MiB，**真机 arm64**）。

## 能否直接提交到 Git 仓库？

| 方式 | 是否可行 | 说明 |
|------|----------|------|
| 提交到 `main` 分支 | ❌ 不推荐 | GitHub 单文件软限制 50 MiB，硬限制 100 MiB；xcframework 约 257 MiB |
| **GitHub Release 附件** | ✅ **推荐** | 单文件最大 **2 GiB**，适合分发预编译包 |
| Git LFS | ⚠️ 可选 | 可行但有 LFS 带宽配额，Release 更简单 |
| 独立 binaries 仓库 | ✅ 可选 | 与 Release 方案类似 |

**结论：** 请把 `SGPlayer.xcframework.zip` 作为 **GitHub Release 资源** 发布，在 manifest 中填写下载 URL，插件使用者无需本地编译。

## 使用者：获取二进制

### 方式 A — 自动（推荐）

```bash
bash kinetic_player/ios/scripts/ensure_sgplayer.sh
```

执行顺序：

1. 已存在 `ios/Frameworks/SGPlayer.xcframework` → 跳过
2. 读取 `ios/sgplayer_binary_manifest.json` 中的 `download_url` → 下载解压
3. 下载失败或未配置 URL → 本地从源码编译（30–60 分钟）

### 方式 B — 环境变量指定 URL

```bash
export KINETIC_PLAYER_SGPLAYER_DOWNLOAD_URL="https://github.com/wanwenfeng4798/kinetic_player/releases/download/sgplayer-v1.0.0/SGPlayer.xcframework.zip"
bash kinetic_player/ios/scripts/ensure_sgplayer.sh
```

### 方式 C — CocoaPods prepare_command

关闭 SPM、使用 CocoaPods 时，`pod install` 会自动调用 `ensure_sgplayer.sh`。

### 方式 D — 本地编译

```bash
bash kinetic_player/ios/scripts/build_sgplayer.sh
```

清理：

```bash
bash kinetic_player/ios/scripts/build_sgplayer.sh clean
```

## 维护者：发布预编译包到 GitHub

### 1. 本地构建 xcframework

```bash
bash kinetic_player/ios/scripts/build_sgplayer.sh
```

产物路径：

```
kinetic_player/ios/Frameworks/SGPlayer.xcframework
```

### 2. 打包 zip 并生成 SHA256

```bash
bash kinetic_player/ios/scripts/package_sgplayer_release.sh
```

输出：

- `ios/Frameworks/SGPlayer.xcframework.zip`
- `ios/Frameworks/SGPlayer.xcframework.zip.sha256`

### 3. 创建 GitHub Release

```bash
cd kinetic_player

# 需安装 GitHub CLI: https://cli.github.com/
gh release create sgplayer-v1.0.0 \
  ios/Frameworks/SGPlayer.xcframework.zip \
  --repo wanwenfeng4798/kinetic_player \
  --title "SGPlayer prebuilt v1.0.0" \
  --notes "Prebuilt SGPlayer.xcframework (ios-arm64) for kinetic_player."
```

Release tag 命名建议：`sgplayer-v<manifest.version>`，与 `ios/sgplayer_binary_manifest.json` 中 `version` 一致。

### 4. 更新 manifest

编辑 `ios/sgplayer_binary_manifest.json`：

```json
{
  "version": "1.0.0",
  "sgplayer_branch": "master",
  "asset_name": "SGPlayer.xcframework.zip",
  "download_url": "https://github.com/wanwenfeng4798/kinetic_player/releases/download/sgplayer-v1.0.0/SGPlayer.xcframework.zip",
  "sha256": "<package 脚本输出的 sha256>"
}
```

提交 manifest 到 git（**不要**提交 zip 本身）。

### 5. 验证

```bash
rm -rf ios/Frameworks/SGPlayer.xcframework
bash ios/scripts/download_sgplayer.sh
ls ios/Frameworks/SGPlayer.xcframework
```

## manifest 字段说明

| 字段 | 说明 |
|------|------|
| `version` | 预编译包版本，与 Release tag 对应 |
| `sgplayer_branch` | 对应 libobjc/SGPlayer 分支（文档用） |
| `asset_name` | Release 附件文件名 |
| `download_url` | 完整 HTTPS 下载地址；留空则跳过下载、走本地编译 |
| `sha256` | zip 校验和；留空则跳过校验 |

## CocoaPods 与 SPM 共用同一产物

```
ios/Frameworks/SGPlayer.xcframework
    ├── kinetic_player.podspec     → vendored_frameworks
    └── kinetic_player/Package.swift → binaryTarget
```

两者读取同一路径，Release 只需发布一份 zip。

## 模拟器说明

当前 SGPlayer 的 FFmpeg/OpenSSL 预编译库仅包含 **真机 arm64**，因此：

- ✅ 真机 `flutter run` / 归档上架
- ❌ iOS 模拟器无法链接 SGPlayer

若未来需要模拟器 slice，需为 `iphonesimulator` 单独编译 FFmpeg（工作量大，见 `build_sgplayer.sh` 注释）。

## 第三方许可

SGPlayer 源码与二进制遵循 [libobjc/SGPlayer](https://github.com/libobjc/SGPlayer) 项目自身许可证。

kinetic_player 插件封装代码采用 [MIT License](../LICENSE)。
