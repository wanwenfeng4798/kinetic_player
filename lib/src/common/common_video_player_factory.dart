import 'package:flutter/foundation.dart';

import '../gsy/gsy_video_controller_impl.dart';
import '../mpv/mpv_video_controller_impl.dart';
import '../sg/sg_video_controller_impl.dart';
import '../web/artplayer_video_controller.dart';
import 'common_video_controller.dart';
import 'platform_guard.dart';
import 'player_view_types.dart';

/// Platform-safe factory: Android → GSY, iOS/macOS → SGPlayer, Web → Artplayer,
/// Windows/Linux → libmpv.
abstract final class CommonVideoPlayerFactory {
  /// Creates the platform-correct controller for [viewId] from
  /// [CommonVideoPlayerView.onPlatformViewCreated].
  static CommonVideoController createAuto(int viewId) {
    if (kIsWeb) {
      return ArtplayerVideoControllerImpl(viewId);
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return GSYVideoControllerImpl(viewId);
    }
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return SGVideoControllerImpl(viewId);
    }
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
      return MpvVideoControllerImpl(viewId);
    }
    throw UnsupportedError(
      'This video player plugin supports Android (GSY), iOS/macOS (SGPlayer), '
      'Web (Artplayer), and Windows/Linux (libmpv).',
    );
  }

  /// Returns the [PlayerViewTypes] entry for the current platform.
  static String viewTypeForCurrentPlatform() {
    assertSupportedPlayerPlatform();
    if (kIsWeb) return PlayerViewTypes.art;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return PlayerViewTypes.gsy;
    }
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
      return PlayerViewTypes.mpv;
    }
    return PlayerViewTypes.sg;
  }
}
