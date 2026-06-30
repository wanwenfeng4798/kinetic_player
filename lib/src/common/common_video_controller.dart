import 'package:flutter/foundation.dart';

import 'common_player_state.dart';
import 'common_scale_mode.dart';

/// Pure unified controller contract. Player-specific APIs live on concrete
/// implementations and must be accessed via explicit downcasting.
abstract class CommonVideoController {
  ValueNotifier<CommonPlayerState> get playerState;
  ValueNotifier<Duration> get position;
  ValueNotifier<Duration> get duration;

  Future<void> play();
  Future<void> pause();
  Future<void> seekTo(Duration position);
  Future<void> setScaleMode(CommonScaleMode mode);
  Future<void> dispose();
}
