# GSY 高级能力对照表

Android 侧基于 **GSYVideoPlayer 13.1.0**（`io.github.carguo:gsyvideoplayer-*`）。iOS 仍为 SGPlayer，不含下列 GSY 能力。

## 图例

| 状态 | 含义 |
|------|------|
| ✅ | 已通过插件 MethodChannel 暴露 |
| ⚠️ | 部分实现 / 需宿主配合 |
| ❌ | GSY 13 Maven 无此模块或需 Demo 级集成 |

---

## 1. 滤镜 / 动画 / 水印 / 多重播放

| 能力 | 状态 | API |
|------|------|-----|
| 26 种 GL 滤镜（马赛克、黑白、高斯模糊等） | ✅ | `gsySetRenderType(GsyRenderType.glSurface)` + `gsySetEffectFilter(name)` + `gsyListEffectFilters()` |
| 水印 / 画面多重播放 | ⚠️ | `gsySetWatermarkUrl(url)` 右上角图片 overlay；多重同播需自定义布局 |

---

## 2. 截图 / GIF

| 能力 | 状态 | API |
|------|------|-----|
| 视频帧截图 | ✅ | `captureFrame()`（公共 API） |
| 播放器 UI 组合截图 | ✅ | `captureFrame(includeOverlay: true)` |
| 保存截图到文件 | ✅ | `gsySaveScreenshot()`（Android GSY 专属） |
| 生成 GIF | ✅ | `gsyStartGifRecording()` → `gsyStopGifRecording()` |

---

## 3. 列表 / 旋转 / 倍速 / 网速

| 能力 | 状态 | API |
|------|------|-----|
| 列表播放 / 连续播放 | ✅ | `creationParams['playlist']` / `gsySetPlaylist()` / `gsyPlayNextInPlaylist()` |
| 重力 / 手动旋转 | ✅ | `GsyUiConfig.rotateViewAuto` + Activity `configChanges` 转发 |
| 视频 rotation 元数据 | ✅ | GSY 内核自动应用 |
| 手动旋转 0/90/180/270 | ✅ | `gsySetRenderRotation(degrees)` |
| 快播 / 慢播 | ✅ | `setRate()` 或 `GsyUiConfig.speed` |
| 网络加载速度 | ✅ | `gsyGetNetSpeed()` |

---

## 4. 显示比例 / 镜像

| 能力 | 状态 | API |
|------|------|-----|
| 默认 / 16:9 / 4:3 / 填充 / 拉伸 | ✅ | `setScaleMode()` 或 `gsySetGsyShowType(GsyShowType.*)` |
| 镜像 | ✅ | `gsySetMirrorHorizontal(enabled: true)` |

---

## 5. 播放内核

| 内核 | 状态 | API |
|------|------|-----|
| IJKPlayer | ✅ | `gsySwitchRenderCore(GsyRenderCore.ijk)` |
| Media3 (Exo2) | ✅ | `gsySwitchRenderCore(GsyRenderCore.exo)` |
| MediaPlayer | ✅ | `gsySwitchRenderCore(GsyRenderCore.system)` |
| AliPlayer | ❌ | Maven 13.1.0 无 `gsyvideoplayer-ali` 模块 |
| 自定义内核 | ⚠️ | 需 fork 插件注册 `PlayerFactory.setPlayManager` |

Exo 模式下 **DASH / HLS 自适应**由 Media3 自动处理；切换轨道见 `gsyListExoVideoTracks` / `gsySelectExoVideoTrack`。

**音轨（音频）** 公共 API：`getAudioTracks()` / `selectAudioTrack(index)`（Exo / IJK 内核，见 `GsyAudioTrackHelper`）。

---

## 6. 布局 / 纯播放 / 弹幕 / 自定义布局

| 能力 | 状态 | API |
|------|------|-----|
| 全屏 / 非全屏两套布局 | ✅ | 原生 `startWindowFullscreen` + `GsyUiConfig` |
| 无控件纯播放 | ✅ | `gsySetPurePlayMode(enabled: true)` |
| 弹幕 | ✅ | `gsySetDanmakuUrl(url)` + `gsyToggleDanmaku(enabled)`（DanmakuFlameMaster + B 站 XML） |
| B 站风格控制栏 | ✅ | 竖向音量弹窗 + 设置面板音轨；见 `GsyUiConfig` |
| 继承自定义布局 | ⚠️ | fork `KineticGSYVideoPlayer` 并重写 `getLayoutId()` |

布局文件：`kinetic_video_layout_preview.xml`（进度条、`kinetic_seek_progress` 配色、喇叭/齿轮/全屏按钮）。

---

## 7. 单例 / 多实例 / 列表自动播放 / 无缝切换

| 能力 | 状态 | 说明 |
|------|------|------|
| 单例播放 | ✅ | `gsyReleaseAllVideos()` |
| 多实例同时播放 | ✅ | 每 PlatformView 独立 `playTag` |
| 列表滑动自动播放 | ⚠️ | `GsyAutoPlayVideoList` / `GsyAutoPlayCoordinator`（可见性检测，非 GSY ListGSYVideoPlayer） |
| 详情页无缝切换 | ⚠️ | `creationParams['playTag']` + `gsySeamlessHandoffParams()` 共享同一 playTag |

---

## 8. 小窗口 / PiP

| 能力 | 状态 | API / 说明 |
|------|------|------------|
| Android 画中画 | ✅ | **`pictureInPictureEnabled: true`（默认）**；播放中按 Home / 切后台自动进入 PiP |
| 手动 PiP | ✅ | `gsyEnterPictureInPicture()` |
| Android 12+ 系统自动 PiP | ✅ | 内部 `PictureInPictureParams.setAutoEnterEnabled` |
| 宿主 Manifest | ⚠️ | `supportsPictureInPicture="true"`、`resizeableActivity="true"` |
| 宿主 Activity | ⚠️ | `KineticPlayerPlugin.handleUserLeaveHint(this)` |
| iOS 画中画 | ❌ | SGPlayer 自定义渲染，无系统 PiP |
| 桌面多窗体 | ⚠️ | 依赖 Android 系统多窗口 + PiP |

关闭 PiP：

```dart
GsyUiConfig(pictureInPictureEnabled: false)
```

---

## 9. 广告

| 能力 | 状态 | API |
|------|------|-----|
| 片头广告 + 跳过 | ⚠️ | `gsyPlayWithPreRollAd(adUrl, contentUrl)`（广告播完自动切正片） |
| 中间插入广告 | ⚠️ | `gsySetMidRollAds([{positionMs, adUrl, contentUrl}])` 进度触发片头广告逻辑；完整 `GSYADVideoPlayer` UI 未移植 |

---

## 10. 字幕

| 能力 | 状态 | API |
|------|------|-----|
| 外挂 SRT/WebVTT | ✅ | `gsySetSubtitleUrl(url, mimeType: ...)` |
| 启用 / 禁用 | ✅ | `gsySetSubtitleEnabled()` |
| Exo 内嵌字幕桥接 | ✅ | `gsySetEmbeddedSubtitleText(text)` |

---

## 11. DASH / 自适应清晰度

| 能力 | 状态 | 说明 |
|------|------|------|
| Exo DASH 播放 | ✅ | 使用 Exo 内核 + DASH URL 即可 |
| HLS/DASH 轨道切换 UI | ⚠️ | `gsyListExoVideoTracks()` / `gsySelectExoVideoTrack(index)`（无 Demo 级 UI） |

---

## 快速示例

```dart
if (controller is GSYVideoControllerImpl) {
  await controller.gsySetRenderType(GsyRenderType.glSurface);
  await controller.gsySetEffectFilter('gaussianBlur');
  await controller.gsySetGsyShowType(GsyShowType.ratio16x9);
  await controller.gsySetSubtitleUrl('https://example.com/subs.vtt');
  final path = await controller.captureFrame(includeOverlay: true);
  await controller.gsySetPlaylist(['url1', 'url2']);
  await controller.gsySetDanmakuUrl('https://example.com/danmaku.xml');
  await controller.gsyToggleDanmaku(enabled: true);
  final tracks = await controller.gsyListExoVideoTracks();
  if (tracks.isNotEmpty) await controller.gsySelectExoVideoTrack(0);
  final audioTracks = await controller.getAudioTracks();
  if (audioTracks.length > 1) {
    await controller.selectAudioTrack(audioTracks[1].index);
  }
}
```
