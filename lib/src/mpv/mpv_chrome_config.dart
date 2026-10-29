import 'package:flutter/painting.dart';

import '../common/kinetic_ui_config.dart';
import '../gsy/gsy_chrome_strings.dart';

/// Desktop chrome options parsed from [CommonVideoPlayerView.creationParams].
class MpvChromeConfig {
  const MpvChromeConfig({
    this.enableNativeControls = true,
    this.showVolumeToolbar = true,
    this.showSettingsButton = true,
    this.showFullscreenButton = true,
    this.showLockButton = true,
    this.dismissControlTime = 2500,
    this.keepLastFrameWhenComplete = false,
    this.coverUrl,
    this.speed = 1,
    this.looping = false,
    this.accentColor = const Color(kKineticDefaultAccentColor),
    this.locale = 'zh',
    this.videoTitle = '',
    this.thumbPlay = true,
  });

  final bool enableNativeControls;
  final bool showVolumeToolbar;
  final bool showSettingsButton;
  final bool showFullscreenButton;
  final bool showLockButton;
  final int dismissControlTime;
  final bool keepLastFrameWhenComplete;
  final String? coverUrl;
  final double speed;
  final bool looping;
  final Color accentColor;
  final String locale;
  final String videoTitle;
  final bool thumbPlay;

  factory MpvChromeConfig.fromCreationParams(Map<String, dynamic>? params) {
    final raw = params?['ui'];
    final ui = raw is Map
        ? Map<String, dynamic>.from(raw)
        : const <String, dynamic>{};
    T? read<T>(String key) {
      final value = ui[key] ?? params?[key];
      if (value is T) return value;
      if (T == double && value is num) return value.toDouble() as T;
      if (T == int && value is num) return value.toInt() as T;
      return null;
    }

    final locale = KineticChromeStrings.normalize(
      read<String>('locale') ?? 'zh',
    );
    final accent = read<int>('accentColor') ?? kKineticDefaultAccentColor;
    return MpvChromeConfig(
      enableNativeControls: read<bool>('enableNativeControls') ?? true,
      showVolumeToolbar: read<bool>('showVolumeToolbar') ?? true,
      showSettingsButton: read<bool>('showSettingsButton') ?? true,
      showFullscreenButton: read<bool>('showFullscreenButton') ?? true,
      showLockButton: read<bool>('showLockButton') ?? true,
      dismissControlTime: read<int>('dismissControlTime') ?? 2500,
      keepLastFrameWhenComplete:
          read<bool>('keepLastFrameWhenComplete') ?? false,
      coverUrl: read<String>('coverUrl'),
      speed: read<double>('speed') ?? 1,
      looping: read<bool>('looping') ?? false,
      accentColor: Color(accent),
      locale: locale,
      videoTitle: read<String>('videoTitle') ?? '',
      thumbPlay: read<bool>('thumbPlay') ?? true,
    );
  }
}
