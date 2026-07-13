## 0.0.3

### 修复

- **音量持久化**：修复暂停后恢复播放、播放完成重播或切换片源后，音量数值与滑轨位置被重置的问题。Android 在 `onPrepared` / 播放开始时重新应用已保存音量；iOS 在 play/replay 时调用 `applySavedVolume`，`currentVolume()` 返回 `_savedVolume`。
- **画中画（Android）**：修复通过 GSY 自动播放或原生播放按钮启动时，切后台无法自动进入 PiP 的问题（此前仅 Flutter `play()` 会设置 `isPlaying`）。现与原生 GSY 播放状态同步，PiP 判定使用真实播放状态（`isPlaybackActive()`）。
- **音量手势冲突（Android）**：开启 `showVolumeToolbar` 时禁用 GSY 内置左侧边缘音量滑动手势，仅保留 B 站风格音量弹窗，避免画面左侧出现第二条音量条。
- **音量拖动数值**：修复拖动音量滑轨时左侧百分比（如 `50%`）时有时无的问题。
- **工具栏图标**：全屏按钮与设置/音量图标统一为 28dp；替换 GSY 默认放大图标为风格一致的矢量资源。

### 增强

- **音量 UI**：拖动竖向音量条时在滑轨左侧显示百分比，松手后隐藏；面板遮罩宽度收窄为 44dp（数值显示在遮罩外侧）。
- **iOS 手势调节**：新增与 GSY 对齐的滑动手势——横向调进度、左半屏调亮度、右半屏调音量，并显示中央 HUD。与 Android 共用 `enableNativeControls`（已移除独立的 `enableGestureControls`）。播放器销毁时恢复系统亮度。音量弹窗打开或拖动滑轨时禁用右侧滑动调音量（与 Android 一致），音量灵敏度对齐 GSY（约 3×）。
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

- 原生控制栏、全屏、`sgSetVRMode` / `sgSetSyncGroupId`
- 音轨 API 与 Android 公共层对齐
