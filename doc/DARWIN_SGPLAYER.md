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

PiP 受系统与宿主后台音频配置限制；返回 false 时读取 playerError。分段拼接仍走 FFmpeg，不能获得自动选核策略。

## UI 与平台差异

| 平台 | 控制栏与交互 | 公共播放 API |
| --- | --- | --- |
| Android | GSY 原生视图、手势、全屏与 PiP | 保持 CommonVideoController |
| iOS/macOS | SGPlayer 2 原生控制栏；iOS 手势 / macOS 键盘 | 同上；新增原生 PiP 与诊断入口 |
| Windows/Linux | 独立 libmpv 纹理与 Flutter 桌面控制栏 | 同上；窗口全屏，系统依赖见 DESKTOP_MPV.md |
| Web | 独立 Artplayer DOM 控制栏 | 同上；音轨依赖 HLS/DASH，截图受 CORS 限制 |

SGPlayer 2 没有暴露控制栏运行时语言、主题、单个按钮显隐的配置接口。`setLocale` 明确返回 UNSUPPORTED；原生 UI 使用 SDK 自带文案。`enableNativeControls` 与自动隐藏时间有效，旧版自绘控制栏专属设置不再生效。宿主需要自定义 UI 时关闭 enableNativeControls，并调用公共控制器。原生设置中的操作由 SDK 自己处理；需要 PNG 字节时调用 captureFrame。

## 验证边界

本次仅执行静态检查和单元测试，不运行真机、模拟器或桌面播放器。明日手动检查：自动选核与失败回退、带鉴权请求头、拖动与倍速、音轨与循环、播放列表、原生设置、全屏恢复、PiP/后台返回、销毁重建。Windows/Linux 需在对应系统验证纹理、全屏与依赖安装，Web 检查浏览器 CORS/PiP。

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
| 弹幕、水印、GIF 动画贴纸 | setDanmaku / setWatermarks / setSticker / removeSticker |
| 灰度、亮度、对比度、饱和度、翻转、模糊、曲线、3D LUT、Bloom | setFilter；cubeText 可直接传入 .cube 文本 |
| 独立图像效果合成、状态和缓存清理 | composeImage / effectsStatus / flushEffects |
| 原生控制栏、锁定、内核调试选项、封面 | configureControls / revealControls / seekBy / setCover |
| 同一播放器浮窗、窗口内全屏、还原 | showFloating / showFullscreenInWindow / restorePresentation / presentationMode |
| 系统窗口全屏 | 公共 enterFullscreen / exitFullscreen / isFullscreen |
| PiP 及恢复宿主界面 | startPictureInPicture / stopPictureInPicture；native.onRestorePictureInPicture |
| FFmpeg 独立预览帧与 WebVTT sprite | createPreview / previewImage / cancelPreview / createSpriteIndex / spriteCue / spriteImage |
| 渐进式媒体下载、SHA-256、配额、pin/unpin、清理 | openCache / download / cachedUrl / cacheInfo / pinCached / unpinCached / clearUnpinnedCache / closeCache |
| 后台 HLS 下载、恢复、查询、取消、删除 | hlsSupported / openHlsStore / downloadHls / restoreHlsDownloads / hlsDownloads / offlineHlsUrl / cancelHls / removeHls / closeHlsStore |
| 独立 GIF 导出、无重编码 remux、视频转码、纯音频 AAC 导出 | exportGif / remux / transcode |
| 长任务进度、结果、取消、释放历史记录 | jobStatus / cancelJob / removeJob；native.onEvent 接收完成事件 |
| 传统 FFmpeg VR、视口、变调、分段组合、后台策略、视频轨 | 保留 SGVideoControllerImpl 已有 sg* 方法 |

所有 `Duration` 参数在通道中统一为毫秒；`configureEffects` 对应 SDK 原始字段，例如 `subtitleOffset`、`stickerStart` 仍用秒。弹幕 map：`text/startMs/durationMs/mode`，mode 为滚动/顶部/底部的 0/1/2。水印 map：`text/imageURL/rect/opacity`，rect 为归一化 `x/y/width/height`。位图、水印及 GIF 贴纸文件须由宿主先下载到本地，避免主线程进行远程图像读取。

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
