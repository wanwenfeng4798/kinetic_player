/// Native UI options passed via [CommonVideoPlayerView.creationParams].
///
/// Shared by Android GSY and iOS SGPlayer. Defaults match
/// [StandardGSYVideoPlayer] / [GSYVideoOptionBuilder] where applicable.
class GsyUiConfig {
  const GsyUiConfig({
    this.enableNativeControls = true,
    this.enableNativeControlsFullscreen = true,
    this.videoTitle = '',
    this.previewVttUrl,
    this.showFullscreenButton = true,
    this.showLockButton = true,
    this.showVolumeToolbar = true,
    this.showSettingsButton = true,
    this.pictureInPictureEnabled = true,
    this.rotateViewAuto = true,
    this.rotateWithSystem = true,
    this.lockLand = false,
    this.needOrientationUtils = true,
    this.showFullAnimation = true,
    this.hideVirtualKey = true,
    this.showPauseCover = true,
    this.needShowWifiTip = true,
    this.surfaceErrorPlay = true,
    this.releaseWhenLossAudio = true,
    this.showDragProgressTextOnSeekBar = false,
    this.dismissControlTime = 2500,
    this.seekRatio = 1,
    this.speed = 1,
    this.looping = false,
    this.seekOnStartMs = -1,
    this.cacheWithPlay = true,
    this.startAfterPrepared = true,
    this.autoFullWithSize = false,
    this.fullHideActionBar = true,
    this.fullHideStatusBar = true,
    this.keepLastFrameWhenComplete = false,
    this.coverUrl,
    this.thumbPlay = true,
    this.ijkEnableAccurateSeek = true,
  });

  /// Native chrome + pan gestures (seek / volume / brightness).
  ///
  /// - Android: GSY touch widget (`setIsTouchWiget`).
  /// - iOS: bottom chrome visibility and GSY-style pan gestures.
  final bool enableNativeControls;

  /// Fullscreen pan gestures (Android GSY `setIsTouchWigetFull`).
  /// iOS uses [enableNativeControls] for both embedded and fullscreen.
  final bool enableNativeControlsFullscreen;

  final String videoTitle;
  final String? previewVttUrl;
  final bool showFullscreenButton;
  final bool showLockButton;
  final bool showVolumeToolbar;
  final bool showSettingsButton;
  final bool pictureInPictureEnabled;
  final bool rotateViewAuto;
  final bool rotateWithSystem;
  final bool lockLand;
  final bool needOrientationUtils;
  final bool showFullAnimation;
  final bool hideVirtualKey;
  final bool showPauseCover;
  final bool needShowWifiTip;
  final bool surfaceErrorPlay;
  final bool releaseWhenLossAudio;
  final bool showDragProgressTextOnSeekBar;
  final int dismissControlTime;
  final double seekRatio;
  final double speed;
  final bool looping;
  final int seekOnStartMs;
  final bool cacheWithPlay;
  final bool startAfterPrepared;
  final bool autoFullWithSize;
  final bool fullHideActionBar;
  final bool fullHideStatusBar;

  /// Keep the last rendered frame when playback completes (both platforms).
  ///
  /// Android mirrors GSY `KeepLastFrameVideo`; iOS hides the cover overlay
  /// so the SGPlayer last frame stays visible.
  final bool keepLastFrameWhenComplete;

  /// Cover / poster image URL (http/https or local `file://`).
  ///
  /// Shown before playback and again on complete unless
  /// [keepLastFrameWhenComplete] is true.
  final String? coverUrl;

  /// Tap the cover to start playback (Android GSY `setThumbPlay`).
  final bool thumbPlay;

  /// IJK FFmpeg accurate seek; reduces keyframe snap-back on drag (IJK core only).
  final bool ijkEnableAccurateSeek;

  Map<String, dynamic> toCreationParams() => <String, dynamic>{
        'gsyUi': <String, dynamic>{
          'enableNativeControls': enableNativeControls,
          'enableNativeControlsFullscreen': enableNativeControlsFullscreen,
          'videoTitle': videoTitle,
          if (previewVttUrl != null) 'previewVttUrl': previewVttUrl,
          'showFullscreenButton': showFullscreenButton,
          'showLockButton': showLockButton,
          'showVolumeToolbar': showVolumeToolbar,
          'showSettingsButton': showSettingsButton,
          'pictureInPictureEnabled': pictureInPictureEnabled,
          'rotateViewAuto': rotateViewAuto,
          'rotateWithSystem': rotateWithSystem,
          'lockLand': lockLand,
          'needOrientationUtils': needOrientationUtils,
          'showFullAnimation': showFullAnimation,
          'hideVirtualKey': hideVirtualKey,
          'showPauseCover': showPauseCover,
          'needShowWifiTip': needShowWifiTip,
          'surfaceErrorPlay': surfaceErrorPlay,
          'releaseWhenLossAudio': releaseWhenLossAudio,
          'showDragProgressTextOnSeekBar': showDragProgressTextOnSeekBar,
          'dismissControlTime': dismissControlTime,
          'seekRatio': seekRatio,
          'speed': speed,
          'looping': looping,
          if (seekOnStartMs >= 0) 'seekOnStartMs': seekOnStartMs,
          'cacheWithPlay': cacheWithPlay,
          'startAfterPrepared': startAfterPrepared,
          'autoFullWithSize': autoFullWithSize,
          'fullHideActionBar': fullHideActionBar,
          'fullHideStatusBar': fullHideStatusBar,
          'keepLastFrameWhenComplete': keepLastFrameWhenComplete,
          if (coverUrl != null) 'coverUrl': coverUrl,
          'thumbPlay': thumbPlay,
          'ijkEnableAccurateSeek': ijkEnableAccurateSeek,
        },
      };
}
