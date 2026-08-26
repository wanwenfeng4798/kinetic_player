## 2.0.3

### 新功能

- **弹幕输入框**（Android）：输入框始终显示；点击弹幕图标改为启用/禁用，并同步开关弹幕画布。
- **设置面板滚动**：一级 / 二级设置超出可用高度时可上下滚动（Android GSY 与 Darwin SGPlayer）。
- **控制栏语言**：`KineticUiConfig.locale` + 公共 `setLocale` / `KineticChromeStrings`（`zh` / `en` / `vi` / `ms` / `id` / `fil`），下发 Android、共享 Darwin、Web Artplayer `lang`。
- **KineticUiConfig**：由 `GsyUiConfig` 更名（全平台，非 Android 专属）。语言随 `creationParams['ui']` 下发。热切换仍用 `setLocale`。
- **底栏图标**：第一行播放 / 音量 / 设置 / 全屏图标加大（20pt / 36dp 点击区）。
- **material_ui**：依赖 `material_ui ^1.1.0`；最低 **Dart 3.12 / Flutter 3.44**。示例移除 `cupertino_icons`。

### 文档

- USAGE / README / Darwin / Web / Example：locale API、SDK 下限、版本 `2.0.3`。

## 2.0.2

### 新功能

- **Android 弹幕 / 水印**：挂入播放器 layout，**窗口全屏**同步显示。
- **Android 广告**：完整片头 / 中插 + 跳过倒计时（`gsyPlayWithPreRollAd`、`gsySetMidRollAds` 键名 `positionMs`/`adUrl`/`contentUrl`、`gsySkipAd`）。
- **列表滑动自动播放**：`GsyAutoPlayVideoList` 列表级可见区，仅活跃 cell 挂载播放器。
- **纯播放模式**：同时隐藏喇叭 / 齿轮 / 标题。
- **SG 创建**：`GsyUiConfig.speed` / `looping` 在 iOS / macOS 生效。

### 修复

- 截图 / GIF / 滤镜 / 旋转 / 镜像 / 字幕在全屏时作用于当前全屏窗。

### 移除

- **详情页无缝**（删除 `gsySeamlessHandoffParams`）。
- 不再宣称多实例同播；移除死参数 `customRatio`。

### 文档

- GSY_FEATURES / USAGE / README 仅保留完整能力；HDR 标明为测试片源；macOS 手势说明与实现一致。

---

## 2.0.1

### 修复

- **macOS 中央播放/暂停图标**：播放与暂停 SF Symbol 均绘制到固定方画布，并将 `imageScaling` / cell 设为 `.scaleNone`，避免 AppKit 把 `pause.fill` 拉胖变形。

### 文档

- 补充 **Linux / Windows** 场景选用 **GstPlayer**：[GitHub](https://github.com/wanwenfeng4798/GstPlayer)、[pub.dev](https://pub.dev/packages/gstplayer)。README / USAGE（中英文）已同步。

---

## 2.0.0

### 新功能

- **Flutter Web**：基于 Artplayer.js **5.4.0**（`HtmlElementView`）；公共 API 与 Android / iOS / macOS 对齐。Web 独有能力通过 `ArtplayerVideoControllerImpl` / `ArtplayerUiConfig` 暴露，**不污染** `CommonVideoController`。详见 [doc/WEB_ARTPLAYER.md](doc/WEB_ARTPLAYER.md)。
- **Web 流媒体**：HLS / DASH（`hls.js` / `dashjs`），`.m3u8` / `.mpd` 自动 `customType`。
- **Artplayer 官方插件**：经 `artPlugins` / `ArtplayerPluginKeys` 打包（弹幕、HLS/DASH 控制、VTT 缩略图、字幕、Chromecast、VAST、章节、自动缩略图、氛围光、Document PiP、外挂音轨、JASSUB、ASR、广告等）。`danmukuMask` 仍走 CDN 懒加载（MediaPipe 体积过大）。
- **Web 进程内桥**：使用 `ArtplayerViewRegistry`，避免 Web 上双端 MethodChannel 冲突。
- **pub.dev Darwin 开箱即用**：`sharedDarwinSource` 下唯一 `darwin/kinetic_player`（Package.swift + Sources）；远程 `binaryTarget` 自动下载 SGPlayer。宿主无需 Scheme Pre-action。CocoaPods 走 `darwin/kinetic_player.podspec` → `ensure_sgplayer`。

### 修复

- **Web 音轨**：浏览器无 `audioTracks` 时不再伪造 Default 轨；列表为空时 `selectAudioTrack(0)` 成功空操作。
- **macOS 中央播放图标**：避免 AppKit 将 SF Symbol 拉伸进 60×60 点击区导致变形（`imageScaling` + 固定字号 / `play.fill` 光学居中）。
- **macOS 滑动手势**：移除 Flutter `AppKitView` 内不可靠的滑动（且无系统亮度 API）。进度 / 音量 / 音轨改为与齿轮选音轨相同的按钮弹窗（进度条、喇叭弹窗、设置面板）。**iOS 仍保留**横向调进度、左半屏亮度、右半屏音量手势。

### 文档

- 新增 Web 说明 [WEB_ARTPLAYER.md](doc/WEB_ARTPLAYER.md) / [WEB_ARTPLAYER_EN.md](doc/WEB_ARTPLAYER_EN.md)；README / USAGE / EXAMPLE / Darwin 文档补充 Web、macOS 交互差异，以及 pub.dev SPM 开箱即用说明。

---

## 1.0.0

### 新功能

- **macOS 支持**：通过 `AppKitView` 使用 SGPlayer；与 iOS 共享 Darwin UI / 桥（`darwin/SgNativePlayerBridge`、`darwin/kinetic_player/Sources/SgPlayerKit`）。最低 **macOS 11**。
- **Darwin 统一工具链**：脚本集中在 `darwin/scripts/sgplayer/`（参数 `ios` | `macos`）；产物在 `darwin/Frameworks/{ios,macos}/`；manifest 在 `darwin/sgplayer/manifest.*.json`。
- **SPM remote binaryTarget**：iOS / macOS `Package.swift` 使用 `url` + `checksum`；Example Scheme Pre-action + `spm_prebuild_hook` / `ensure_sgplayer`（下载 → 本地编译回退）。
- **文档**：统一 [doc/DARWIN_SGPLAYER.md](doc/DARWIN_SGPLAYER.md)；README / USAGE / EXAMPLE 与 iOS、macOS 对齐。

### 修复

- **Android PiP**：钳制画中画宽高比并兜底异常，避免超宽比 / 极端比例视频崩溃。
- **大体积远程片源（Android）**：调整超时与边播边缓存策略，减轻大远程 MKV 等场景卡死。
- **iOS / macOS SPM**：目标路径限制在 Flutter ephemeral 包根内（同步共享源码与本地 xcframework）；`SgPlayerKit` 并入主 target `kinetic_player`，正确解析 `Flutter` / `FlutterMacOS`。
- **平台视图 API**：对齐 iOS / macOS Factory 签名（`FlutterPlatformView` vs 直接返回 `NSView`；`createArgsCodec` 可空性）。
- **macOS Example**：沙盒开启 `com.apple.security.network.client`；部署版本对齐 11.0。

### 增强

- **Example**：HDR / 高码率演示片源；Android 内核切换下拉；macOS Example 与 Pre-action 钩子。
- **Android**（承接 0.0.4）：默认内核 **IJKPlayer**；`GsyUiConfig.ijkEnableAccurateSeek` → `enable-accurate-seek`。

---

## 0.0.4

### 修复

- android **默认内核**：插件加载时设为 **IJKPlayer**
- android IJK 精确 seek：`GsyUiConfig.ijkEnableAccurateSeek`（默认 `true`）通过 `GSYVideoManager.setOptionModelList` 设置 `enable-accurate-seek=1`，减轻拖动进度条关键帧回弹；仅 IJK 内核生效。
- ios 更新快进进度条不准确以及后台播放问题

---

## 0.0.3

### 修复

- **音量持久化**：修复暂停后恢复播放、播放完成重播或切换片源后，音量数值与滑轨位置被重置的问题。Android 在 `onPrepared` / 播放开始时重新应用已保存音量；iOS 在 play/replay 时调用 `applySavedVolume`，`currentVolume()` 返回 `_savedVolume`。
- **画中画（Android）**：修复通过 GSY 自动播放或原生播放按钮启动时，切后台无法自动进入 PiP 的问题（此前仅 Flutter `play()` 会设置 `isPlaying`）。现与原生 GSY 播放状态同步，PiP 判定使用真实播放状态（`isPlaybackActive()`）。
- **音量手势冲突（Android）**：开启 `showVolumeToolbar` 时禁用 GSY 内置左侧边缘音量滑动手势，仅保留 B 站风格音量弹窗，避免画面左侧出现第二条音量条。
- **音量拖动数值**：修复拖动音量滑轨时左侧百分比（如 `50%`）时有时无的问题。
- **工具栏图标**：全屏按钮与设置/音量图标统一为 28dp；替换 GSY 默认放大图标为风格一致的矢量资源。

### 增强

- **音量 UI**：拖动竖向音量条时在滑轨左侧显示百分比，松手后隐藏；面板遮罩宽度收窄为 44dp（数值显示在遮罩外侧）。
- **iOS 手势调节**：新增与 GSY 对齐的滑动手势——横向调进度、左半屏调亮度、右半屏调音量，并显示中央 HUD。与 Android 共用 `enableNativeControls`。播放器销毁时恢复系统亮度。音量弹窗打开或拖动滑轨时禁用右侧滑动调音量（与 Android 一致），音量灵敏度对齐 GSY（约 3×）。
- **画面旋转 / 镜像**：Android 已有 `gsySetRenderRotation` / `gsySetMirrorHorizontal`；iOS 新增对应的 `sgSetRenderRotation` / `sgSetMirrorHorizontal`（对视频视图施加 `CGAffineTransform`）。Example 增加双端旋转/镜像控制。
- **封面 / 保留最后一帧**：Android 使用 GSY `setThumbImageView` + KeepLastFrameVideo 风格完成态；iOS 用封面层，开启保留最后一帧时隐藏封面露出画面。配置项 `GsyUiConfig.coverUrl` / `keepLastFrameWhenComplete`；运行时 `gsySetCoverUrl` / `gsySetKeepLastFrameWhenComplete`（iOS 为 `sgSet*`）。
- **旋转铺满 + 上下镜像**：90°/270° 旋转后按比例放大以居中铺满播放区域；新增 `gsySetMirrorVertical` / `sgSetMirrorVertical`。
- **旋转 / 镜像偏位修复**：Android 改为 GSY `View.setRotation` + `scaleX`/`scaleY`（由 MeasureHelper 重新测布局），不再使用错误枢轴的 TextureView matrix；iOS 使用 `SgTransformHostView`（外层裁剪 + 内层 content 变换，避免 Auto Layout 与 transform 冲突，Metal 渲染视图保持 identity）。
- **SGPlayer 深度 API**：缓冲进度与错误详情、音高、VR/VRBox + viewport、demuxer 选项（超时/UA/headers）、视频轨选择、多段 `SGMutableAsset`、后台播放策略。
- **Example**：显式开启 `pictureInPictureEnabled: true`；控制面板增加 PiP 使用说明。

---

## 0.0.2

### 修复与优化

- 音轨与手势修复：修复音轨设置后重播被重置的问题，并解决音轨设置与手势操作之间的冲突。
- 音频控制修复：修复音轨条与手势音频调整之间的冲突问题。
- 示例优化：优化示例项目，避免 Android 端开启混淆（ProGuard）后导致应用无法打开的问题。

---

## 0.0.1

### 公共 API

- 统一 `CommonVideoController`：`play` / `pause` / `stop` / `seekTo` / `setScaleMode` / `setRate` / `setVolume` / `setMute` / `switchVideoSource` / `getAudioTracks` / `selectAudioTrack` / `getDuration` / `getCurrentPosition` / `getVideoSize` / `setLooping` / `captureFrame` / `dispose`
- 双端 MethodChannel 状态与进度回调（`onPlayerStateChanged` / `onPositionChanged`，约 250ms 节流）

### 原生控制栏（Android GSY + iOS SGPlayer）

- B 站风格 UI：点击喇叭弹出**竖向**音量条；点击齿轮打开**设置面板**选择音轨
- 进度条与音量条轨道色统一（`kinetic_seek_progress` / `KineticPlayerColors`）
- 新增 `GsyUiConfig.showSettingsButton`（默认 `true`）
- `showVolumeToolbar` 现为控制喇叭按钮（非底部常驻音量条）
- 控制栏隐藏后底部区域不再拦截点击，右下角可正常唤出/隐藏控制栏

### 画中画（Android）

- `GsyUiConfig.pictureInPictureEnabled` 默认 `true`
- 播放中切后台（`onUserLeaveHint`）自动进入 PiP（API 26+）
- Android 12+ 支持 `setAutoEnterEnabled`
- 手动 API：`gsyEnterPictureInPicture()`
- 宿主需配置 `supportsPictureInPicture`、`resizeableActivity`，并转发 `KineticPlayerPlugin.handleUserLeaveHint`
- iOS：SGPlayer 自定义渲染，**不支持**系统 PiP

### 播放体验

- 修复播放完成后无法重播（Android 完成态先 seek(0)；iOS `replayFromBeginning`）

### Android GSY 高级能力

- 滤镜、弹幕、字幕、截图/GIF、列表、Exo 轨道、水印等（见 [GSY_FEATURES.md](doc/GSY_FEATURES.md)）

### iOS SGPlayer

- 原生控制栏、全屏、`sgSetVRMode`
- 音轨 API 与 Android 公共层对齐
