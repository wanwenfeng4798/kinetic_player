# iOS / macOS SGPlayer 3.0 集成

原生依赖固定为 [SGPlayer v2.0.0](https://github.com/wanwenfeng4798/SGPlayer/releases/tag/v2.0.0)。最低 iOS 15 / macOS 12。使用官方 tag 中的集成包和 SHA-256，不再使用 kinetic_player 仓库的 1.x 二进制。

## 安装

SPM 首次解析前，在插件根目录执行（只下载二进制，不启动设备）：

```sh
bash darwin/scripts/sgplayer/spm_prebuild_hook.sh ios
```

该入口准备 iOS 和 macOS 两个条件 binaryTarget。官方 zip 内含本地 Package，XCFramework 位于嵌套的 Artifacts 目录，因此不能作为远程 binaryTarget URL 直接使用。脚本校验下载文件后复制到 `darwin/Frameworks/{ios,macos}` 与 `darwin/kinetic_player/Artifacts/{ios,macos}`。这些目录不提交 Git。

CocoaPods 发布准备支持 prepare_command；Flutter 的本地 path 依赖可能跳过该阶段，因此两种集成方式都建议首次先运行上面的准备脚本。下载失败直接报告错误；需要源码编译时显式设置 `KINETIC_PLAYER_SGPLAYER_BUILD_FROM_SOURCE=1`。旧缓存没有 2.0.0 版本标记时重新下载。

## 原生能力

`SGPlaybackSession` 管理自动选核、兼容失败回退、播放状态、播放列表、自动下一集与循环；`SGPlaybackController` 管理跳转、音轨、截图与 PiP；`SGPlaybackControls` 提供控制栏、iOS 手势与 macOS 键盘操作。插件仅转发 Flutter API 和事件，保留宿主全屏窗口、变换及 SGMutableAsset 分段适配。普通 URL 使用自动选核；自定义 HTTP/解复用选项、变调或 VR 需要 FFmpeg。

```dart
final diagnostics = await controller.getDiagnostics(); // SGVideoControllerImpl
final started = await controller.startPictureInPicture();
await controller.stopPictureInPicture();
```

iOS PiP 使用 AVKit，受系统与宿主后台音频配置限制；macOS 使用 SGPlayer 内的原生 AppKit 浮动面板（`pictureInPictureBackend=appKitPanel`、`systemPictureInPicture=false`）。返回 false 时读取 playerError。分段拼接仍走 FFmpeg，不能获得自动选核策略。

## UI 与平台差异

| 平台 | 控制栏与交互 | 公共播放 API |
| --- | --- | --- |
| Android | GSY 原生视图、手势、全屏与 PiP | 保持 CommonVideoController |
| iOS/macOS | SGPlayer 2 原生控制栏；iOS 手势 / macOS 键盘 | 同上；新增原生 PiP 与诊断入口 |
| Windows/Linux | 独立 libmpv 纹理与 Flutter 桌面控制栏 | 同上；窗口全屏，系统依赖见 DESKTOP_MPV.md |
| Web | 独立 Artplayer DOM 控制栏 | 同上；音轨依赖 HLS/DASH，截图受 CORS 限制 |

SGPlayer 2 没有暴露控制栏运行时语言、主题、单个按钮显隐的配置接口。`setLocale` 明确返回 UNSUPPORTED；原生 UI 使用 SDK 自带文案。`enableNativeControls` 与自动隐藏时间有效，旧版自绘控制栏专属设置不再生效。宿主需要自定义 UI 时关闭 enableNativeControls，并调用公共控制器。原生设置中的操作由 SDK 自己处理；需要 PNG 字节时调用 captureFrame。

## 验证边界

已有真机和 macOS 集成测试，具体已测项及当前阻塞见文末。Windows/Linux 仍需在对应系统验证纹理、全屏与依赖安装；浏览器测试通过不代表所有媒体跨域策略均可用。

## SGPlayer 2 原生功能接入清单（3.0.0）

入口为 `SGVideoControllerImpl.native`（`SgNativeFeatures`）。这些方法直接调用 SDK；不在 Dart 中实现解码、合成、缓存或媒体导出。底层帧指针、Metal/CoreVideo 对象不跨 Flutter 通道传递，对应图像输出转为 PNG。

| 原生能力 | Flutter 入口 |
| --- | --- |
| 运行时能力查询 | capabilities |
| 多集、多清晰度、自动选核、手动内核切换 | loadItems / configureSession / selectItem / selectRendition / switchKernel / next / previous |
| 单集/列表循环、A–B 循环、重试 | configureSession(loopMode) / setLoopRange / clearLoopRange / retry |
| 稳定 ID 断点续播、诊断与诊断文件 | configureSession(resumeEnabled) / saveResumePosition / diagnostics / exportDiagnostics |
| 多播放器互斥 | activateExclusivePlayback / pauseAllPlayers |
| AVPlayer ABR、缓冲偏好、访问日志指标 | setNativePolicy / nativeMetrics |
| 外挂/内嵌 SRT、WebVTT、ASS、位图、双字幕 | loadSubtitles / readSubtitles / subtitleTracks / selectSubtitle(secondary) / setSubtitleCues |
| 字幕延时、位置、字体、大小、透明度、合成限制 | configureEffects |
| XML 弹幕、水印开关、GIF 动画贴纸 | loadDanmakuXml / setDanmaku / configureEffects(watermarksEnabled/danmakuEnabled) / setWatermarks / setSticker / removeSticker |
| 灰度、亮度、对比度、饱和度、翻转、模糊、曲线、3D LUT、Bloom | setFilter；cubeText 可直接传入 .cube 文本 |
| 独立图像效果合成、状态和缓存清理 | composeImage / effectsStatus / flushEffects |
| 原生控制栏、纯播放、锁定、封面、最后一帧、后台 PiP | configureControls(enabled/keepLastFrameWhenComplete/automaticPictureInPictureEnabled) / revealControls / seekBy / setCover |
| 原生片头/中插/跳过广告，恢复正片位置和暂停状态 | playAdvertisement / scheduleAdvertisements / skipAdvertisement / advertisementStatus |
| 原生进度条 WebVTT 精灵预览 | KineticUiConfig.previewVttUrl / loadTimelineSprites / timelinePreviewImage |
| 同一播放器浮窗、窗口内全屏、还原 | showFloating / showFullscreenInWindow / restorePresentation / presentationMode |
| 系统窗口全屏 | 公共 enterFullscreen / exitFullscreen / isFullscreen |
| PiP 及恢复宿主界面 | startPictureInPicture / stopPictureInPicture；native.onRestorePictureInPicture |
| FFmpeg 独立预览帧与 WebVTT sprite | createPreview / previewImage / cancelPreview / createSpriteIndex / spriteCue / spriteImage |
| 渐进式媒体下载、SHA-256、配额、pin/unpin、清理 | openCache / download / cachedUrl / cacheInfo / pinCached / unpinCached / clearUnpinnedCache / closeCache |
| 后台 HLS 下载、恢复、查询、取消、删除 | hlsSupported / openHlsStore / downloadHls / restoreHlsDownloads / hlsDownloads / offlineHlsUrl / cancelHls / removeHls / closeHlsStore |
| 独立 GIF 导出、无重编码 remux、视频转码、纯音频 AAC 导出 | exportGif / remux / transcode |
| 长任务进度、结果、取消、释放历史记录 | jobStatus / cancelJob / removeJob；native.onEvent 接收完成事件 |
| 传统 FFmpeg VR、视口、变调、分段组合、后台策略、视频轨 | 保留 SGVideoControllerImpl 已有 sg* 方法 |

所有 `Duration` 参数在通道中统一为毫秒；`configureEffects` 对应 SDK 原始字段，例如 `subtitleOffset`、`stickerStart` 仍用秒。弹幕 map：`text/startMs/durationMs/mode`，mode 为滚动/顶部/底部/反向的 0/1/2/3，可选 color（RGB 整数）与 fontSize。XML 文件支持常规滚动、固定顶部/底部和反向弹幕；B 站高级/代码弹幕（模式 7/8）不作为普通文字执行。水印 map：`text/imageURL/rect/opacity`，rect 为归一化 `x/y/width/height`。位图、水印及 GIF 贴纸文件须由宿主先下载到本地，避免主线程进行远程图像读取。

```dart
final sg = controller as SGVideoControllerImpl;
await sg.native.configureSession(kernelPolicy: SgKernelPolicy.automatic);
await sg.native.loadSubtitles(subtitleUrl);
await sg.native.selectSubtitle(0);
await sg.native.configureEffects({'subtitleOffset': 0.25});
await sg.native.setFilter({'grayscale': true, 'bloomIntensity': 0.2});
final job = await sg.native.transcode(mediaUrl, localOutput,
  start: Duration.zero, end: const Duration(seconds: 5),
  configuration: {'includeVideo': false, 'audioBitRate': 128000});
final state = await sg.native.jobStatus(job);
sg.native.onRestorePictureInPicture = () async {
  // 此处恢复播放器所在的宿主页面，再返回结果。
  return true;
};
```

断点续播须先通过 loadItems 提供不含凭据的稳定 item/rendition ID；普通 URL 的随机临时 ID 不提供跨次持久续播。导出 job 状态为 running/completed/failed/cancelled，移除运行中的任务会报错；先取消并等待结束，再 removeJob。导出读取效果 snapshot，不修改当前播放位置。

HLS 下载仅在 SDK 的 hlsSupported 返回 true 时可用（iOS 18/macOS 14 起）。后台标识自动加 `kinetic_player.hls.` 前缀，iOS 插件已注册后台 NSURLSession 生命周期回调。HLS store 可跨播放器销毁继续下载，重新用同一标识打开并恢复任务；有活动下载时不能 closeHlsStore。支持显式 cookies；任意认证 resource-loader、DRM 许可证流程仍需宿主原生配置，不伪装为普通 header 参数。渐进式 cache 下载支持显式 Authorization/Cookie 请求头。

字体与许可证随官方包提取并作为 SPM/CocoaPods 资源打包，原生 ASS/CJK 字幕使用随包字体。SGPlayer 的系统/编码器/格式限制由 SDK 明确返回错误，Flutter 不偷偷换编码器或伪造支持。


## 本地 SGPlayer 联调

本机联调源使用 `/Users/mdw/Desktop/SGPlayer`。可通过环境变量 `KINETIC_PLAYER_SGPLAYER_LOCAL_ROOT`，或本机未跟踪文件 `darwin/sgplayer/.local-root` 指定路径。设置后 `ensure_sgplayer.sh` 只接入该目录的 `build/Package-iOS/Artifacts/SGPlayer.xcframework` 和 `build/Package-macOS/Artifacts/SGPlayer.xcframework`，不存在时直接失败，不回退下载 GitHub 产物。

SGPlayer 的源码或打包缺陷应在 SGPlayer 项目修复，消费端不修补 Framework 内容。切换到本地产物后必须重新执行设备回归，旧发布包的测试结果不能作为新产物的验证结果。全部调试和验证完成后再上传 tag 产物。

## 原生工具栏风格对齐

iOS/macOS 的 SGPlaybackControls 已在 SGPlayer 源码项目中改为播放器底栏：黑色半透明背景、白色图标、粉色进度、播放/时间/进度/倍速/设置/音量/全屏顺序，锁定按钮位于右侧。高级原生操作通过设置菜单访问，音量有原生滑块弹层。窄窗口分为进度行和操作行，Apple 平台保留 AirPlay。插件继续直接使用 SG 原生控件，无 Flutter 覆盖工具栏。

原生 AppKit 布局回归检查了 240/280/360/720/1280 五种宽度，并验证锁定和音量滑块；这些是窗口尺寸检查，不代表多台设备均已验收。iPhone/macOS 本地播放、列表及全屏集成回归已通过。


## Apple 功能回归（本地产物）

悬浮呈现保存并恢复原有 Auto Layout 约束，播放器与工具栏整体移动；恢复时同步完成嵌套视频布局，避免内部视图暂留画中画宽度。macOS 画中画使用 SGPlayer 内的 AppKit 原生浮动面板，移动同一个视频/工具栏/变换容器，按实际视频宽高比调整尺寸。它是应用管理的窗口，不是系统 AVKit PiP；iOS 继续使用 AVKit。对应修改位于本机 SGPlayer 源码。

原生回归覆盖：XML 实体/颜色/方向、WebVTT 相对精灵路径及裁切与可见拖动预览、工具栏 240/280/360/720/1280 宽度、锁定/音量、比例/镜像/循环/截图/纯播放/封面/最后一帧、悬浮约束恢复、广告倒计时/跳过/中插只触发一次/失败恢复。最新 macOS 双内核生命周期回归验证反复开启/退出、播放进度、三种缩放模式、尺寸比例、布局恢复和最小化自动进入；锁屏下不执行像素检查。

macOS 与 iPhone 应用集成回归覆盖本地播放、暂停、seek、截图、字幕、弹幕、WebVTT 预览、水印开关、纯播放、悬浮/恢复、广告跳过、列表与全屏。iPhone 还实际切换到后台验证自动 PiP 与继续播放。上述结果不代表所有网络媒体格式、所有尺寸设备，以及 Windows/Linux 目标系统已验收；发布上传仍待整体调试完成。


```dart
await sg.native.loadDanmakuXml(xmlUrl);
await sg.native.loadTimelineSprites(previewVttUrl); // null 清除预览
await sg.native.configureEffects({'watermarksEnabled': false});
await sg.native.configureControls(enabled: false); // 外部入口传 true 恢复
await sg.native.configureControls(
  automaticPictureInPictureEnabled: true,
  keepLastFrameWhenComplete: true,
);
await sg.native.playAdvertisement(adUrl,
  fromBeginning: true, skipAfter: const Duration(seconds: 3));
await sg.native.scheduleAdvertisements([
  {'positionMs': 8000, 'url': adUrl, 'skipAfterMs': 3000},
]);
final skipped = await sg.native.skipAdvertisement(); // 未达到可跳过时间返回 false
```

广告 map 的 `positionMs`、`skipAfterMs` 都是毫秒；调度、倒计时、完成/失败恢复和暂停状态均由 SGPlayer 会话执行。


当前验收限制：Mac 自动锁屏，最新浮动面板的可见边界检查尚待解锁后重跑 `scripts/test-pip-layout.py`；锁屏会返回 77。`--logic-only` 已分别通过原生/FFmpeg 内核的真实窗口生命周期测试，但不代表画面通过。iPhone 最新截图显示系统“无法验证 App”弹窗；尝试 UI 自动化时还要求设备密码，不能远程代输或绕过。临时自动化 Runner 已卸载，正常 App 已恢复，bundle id 仍为 `com.omnilink.fufucard`。需要系统验证完成后补跑最新 iPhone 界面/后台测试。此前通过的后台 PiP 结果不能替代最新构建验收。

纯播放返回：macOS 原生工具栏入口保留 Escape 关闭呈现；iOS 宿主全屏提供左侧边缘右滑返回，退出纯播放可使用全屏外的公共按钮。


最新本地交付状态：Apple 三个编译目标（macOS 通用、iOS 真机、iOS 模拟器）均编译成功；原生策略/工具栏回归通过；macOS 应用集成 2/2、Flutter 回归 32/32、静态分析通过。最新 iPhone 与 macOS 正常 release 演示入口 `lib/main.dart` 均构建成功，iPhone 已重新安装并尝试启动，截图仍显示上述系统验证阻塞；iOS bundle id 保持 `com.omnilink.fufucard`，应用版本 3.0.0。所有 Apple 产物来自本地 SGPlayer 目录；未上传 tag。Android 设备离线，当前轮未补跑其真机回归。
