import 'package:flutter/foundation.dart';

import '../common/common_audio_track.dart';
import '../common/common_player_state.dart';
import '../common/common_scale_mode.dart';
import '../common/common_video_controller.dart';
import '../common/common_video_size.dart';
import '../common/platform_guard.dart';
import 'artplayer_ui_config.dart';
import 'artplayer_view_host.dart';

/// Web Artplayer implementation of [CommonVideoController].
///
/// Talks to [ArtplayerViewHost] via an in-Dart registry (no MethodChannel),
/// because both ends run in the same isolate on Flutter Web.
class ArtplayerVideoControllerImpl implements CommonVideoController {
  ArtplayerVideoControllerImpl(this.viewId) {
    assertWebPlatform('ArtplayerVideoControllerImpl');
    final host = ArtplayerViewRegistry.get(viewId);
    host?.setEventSink(_onHostEvent);
  }

  final int viewId;
  bool _isDisposed = false;

  final ValueNotifier<bool> pipActive = ValueNotifier(false);

  @override
  final ValueNotifier<CommonPlayerState> playerState =
      ValueNotifier(CommonPlayerState.idle);
  @override
  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);
  @override
  final ValueNotifier<Duration> duration = ValueNotifier(Duration.zero);

  ArtplayerViewHost? get _host => ArtplayerViewRegistry.get(viewId);

  void _onHostEvent(String method, Map<String, dynamic> args) {
    if (_isDisposed) return;
    switch (method) {
      case 'onPlayerStateChanged':
        final index = args['state'];
        if (index is int &&
            index >= 0 &&
            index < CommonPlayerState.values.length) {
          playerState.value = CommonPlayerState.values[index];
        }
      case 'onPositionChanged':
        final pos = args['position'];
        final dur = args['duration'];
        if (pos is num) {
          position.value = Duration(milliseconds: pos.toInt());
        }
        if (dur is num) {
          duration.value = Duration(milliseconds: dur.toInt());
        }
      case 'onPipChanged':
        pipActive.value = args['active'] == true;
      case 'onError':
        playerState.value = CommonPlayerState.error;
    }
  }

  Future<void> _invoke(String method, [Map<String, dynamic>? arguments]) async {
    if (_isDisposed) return;
    final host = _host;
    if (host == null) return;
    await host.invoke<void>(method, arguments);
  }

  @override
  Future<void> play() => _invoke('play');

  @override
  Future<void> pause() => _invoke('pause');

  @override
  Future<void> stop() => _invoke('stop');

  @override
  Future<void> seekTo(Duration position) =>
      _invoke('seekTo', {'position': position.inMilliseconds});

  @override
  Future<void> setScaleMode(CommonScaleMode mode) =>
      _invoke('setScaleMode', {'mode': mode.index});

  @override
  Future<void> setRate(double rate) => _invoke('setRate', {'rate': rate});

  @override
  Future<void> setVolume(double volume) =>
      _invoke('setVolume', {'volume': volume});

  @override
  Future<void> setMute(bool muted) => _invoke('setMute', {'muted': muted});

  @override
  Future<void> switchVideoSource(String url, {bool autoPlay = true}) =>
      _invoke('switchVideoSource', {'url': url, 'autoPlay': autoPlay});

  @override
  Future<List<CommonAudioTrack>> getAudioTracks() async {
    final host = _host;
    if (host == null) return const [];
    final result = await host.invoke<Object>('getAudioTracks');
    if (result is! List) return const [];
    return result.map((item) {
      if (item is Map) {
        return CommonAudioTrack.fromMap(
          Map<Object?, Object?>.from(item),
        );
      }
      return const CommonAudioTrack(index: 0, label: 'Default', selected: true);
    }).toList();
  }

  @override
  Future<void> selectAudioTrack(int index) =>
      _invoke('selectAudioTrack', {'index': index});

  @override
  Future<Duration> getDuration() async => duration.value;

  @override
  Future<Duration> getCurrentPosition() async => position.value;

  @override
  Future<CommonVideoSize?> getVideoSize() async {
    final host = _host;
    if (host == null) return null;
    final result = await host.invoke<Object>('getVideoSize');
    if (result is! Map) return null;
    final size = CommonVideoSize.fromMap(Map<Object?, Object?>.from(result));
    return size.isValid ? size : null;
  }

  @override
  Future<void> setLooping(bool looping) =>
      _invoke('setLooping', {'looping': looping});

  @override
  Future<String?> captureFrame({
    bool highQuality = true,
    bool includeOverlay = false,
  }) async {
    final host = _host;
    if (host == null) return null;
    final result = await host.invoke<Object>('captureFrame', {
      'highQuality': highQuality,
      'includeOverlay': includeOverlay,
    });
    return result is String ? result : null;
  }

  /// Toggle browser / Artplayer Picture-in-Picture.
  Future<bool> togglePip() async {
    final host = _host;
    if (host == null) return false;
    final result = await host.invoke<Object>('togglePip');
    return result == true;
  }

  Future<bool> artIsPipSupported() async {
    final host = _host;
    if (host == null) return false;
    final result = await host.invoke<Object>('artIsPipSupported');
    return result == true;
  }

  Future<void> artSetUiConfig(ArtplayerUiConfig config) =>
      _invoke('artSetUiConfig', config.toCreationParams());

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    final host = _host;
    host?.setEventSink(null);
    await host?.dispose();
    playerState.dispose();
    position.dispose();
    duration.dispose();
    pipActive.dispose();
  }
}
