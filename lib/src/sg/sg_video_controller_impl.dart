import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../common/common_player_state.dart';
import '../common/common_scale_mode.dart';
import '../common/common_video_controller.dart';
import '../common/common_video_controller_bridge.dart';
import '../common/platform_guard.dart';

class SGVideoControllerImpl
    with CommonVideoControllerBridge
    implements CommonVideoController {
  final int viewId;
  late MethodChannel _channel;
  bool _isDisposed = false;

  @override
  MethodChannel get bridgeChannel => _channel;

  @override
  bool get bridgeDisposed => _isDisposed;

  @override
  final ValueNotifier<CommonPlayerState> playerState =
      ValueNotifier(CommonPlayerState.idle);
  @override
  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);
  @override
  final ValueNotifier<Duration> duration = ValueNotifier(Duration.zero);

  SGVideoControllerImpl(this.viewId) {
    assertIosPlatform('SGVideoControllerImpl');
    _channel = MethodChannel('com.example.player/sg_$viewId');
    _channel.setMethodCallHandler(_handleNativeEvents);
  }

  Future<void> _handleNativeEvents(MethodCall call) async {
    if (_isDisposed) return;
    switch (call.method) {
      case 'onPlayerStateChanged':
        final args = call.arguments as Map;
        playerState.value =
            CommonPlayerState.values[args['state'] as int];
        break;
      case 'onPositionChanged':
        final args = call.arguments as Map;
        position.value =
            Duration(milliseconds: args['position'] as int);
        duration.value =
            Duration(milliseconds: args['duration'] as int);
        break;
    }
  }

  @override
  Future<void> play() => _invoke('play');

  @override
  Future<void> pause() => _invoke('pause');

  @override
  Future<void> seekTo(Duration position) =>
      _invoke('seekTo', {'position': position.inMilliseconds});

  @override
  Future<void> setScaleMode(CommonScaleMode mode) =>
      _invoke('setScaleMode', {'mode': mode.index});

  /// SG unique: enable or disable VR rendering mode.
  Future<void> sgSetVRMode({required bool enabled}) =>
      _invoke('sgSetVRMode', {'enabled': enabled});

  /// SG unique: assign sync group for multi-device playback.
  /// No-op on SGPlayer (reserved hook).
  Future<void> sgSetSyncGroupId(String id) =>
      _invoke('sgSetSyncGroupId', {'id': id});

  /// SG unique: enter window-level fullscreen overlay.
  Future<void> sgStartFullscreen() => _invoke('sgStartFullscreen');

  /// SG unique: exit window-level fullscreen overlay.
  Future<void> sgExitFullscreen() => _invoke('sgExitFullscreen');

  Future<bool> sgIsFullscreen() async {
    final result = await _channel.invokeMethod<bool>('sgIsFullscreen');
    return result ?? false;
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    _channel.setMethodCallHandler(null);
    await _channel.invokeMethod('dispose');
    playerState.dispose();
    position.dispose();
    duration.dispose();
  }

  Future<void> _invoke(String method, [Object? arguments]) async {
    if (_isDisposed) return;
    await _channel.invokeMethod(method, arguments);
  }
}
