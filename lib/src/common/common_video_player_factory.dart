import 'package:flutter/foundation.dart';

import '../gsy/gsy_video_controller_impl.dart';
import '../sg/sg_video_controller_impl.dart';
import 'common_video_controller.dart';
import 'platform_guard.dart';
import 'player_view_types.dart';

/// Platform-safe factory: Android → GSY, iOS/macOS → SGPlayer.
abstract final class CommonVideoPlayerFactory {
  /// Creates the platform-correct controller for [viewId] from
  /// [CommonVideoPlayerView.onPlatformViewCreated].
  static CommonVideoController createAuto(int viewId) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return GSYVideoControllerImpl(viewId);
    } else if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return SGVideoControllerImpl(viewId);
    } else {
      throw UnsupportedError(
        'This video player plugin supports Android (GSY), iOS and macOS (SGPlayer).',
      );
    }
  }

  /// Returns the [PlayerViewTypes] entry for the current platform.
  static String viewTypeForCurrentPlatform() {
    assertSupportedPlayerPlatform();
    return defaultTargetPlatform == TargetPlatform.android
        ? PlayerViewTypes.gsy
        : PlayerViewTypes.sg;
  }
}
