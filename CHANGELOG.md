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

- 滤镜、弹幕、字幕、截图/GIF、列表、Exo 轨道、水印等（见 [GSY_FEATURES.md](docs/GSY_FEATURES.md)）

### iOS SGPlayer

- 原生控制栏、全屏、`sgSetVRMode` / `sgSetSyncGroupId`
- 音轨 API 与 Android 公共层对齐
