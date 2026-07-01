import 'package:flutter/services.dart';

import 'common_audio_track.dart';
import 'common_video_controller.dart';
import 'common_video_size.dart';

/// Shared MethodChannel bindings for cross-platform playback controls.
mixin CommonVideoControllerBridge implements CommonVideoController {
  MethodChannel get bridgeChannel;
  bool get bridgeDisposed;

  @override
  Future<void> stop() => _invoke('stop');

  @override
  Future<void> setRate(double rate) => _invoke('setRate', {'rate': rate});

  @override
  Future<void> setVolume(double volume) =>
      _invoke('setVolume', {'volume': volume});

  @override
  Future<void> setMute(bool muted) => _invoke('setMute', {'muted': muted});

  @override
  Future<void> switchVideoSource(
    String url, {
    bool autoPlay = true,
  }) =>
      _invoke('switchVideoSource', {
        'url': url,
        'autoPlay': autoPlay,
      });

  @override
  Future<List<CommonAudioTrack>> getAudioTracks() async {
    final result =
        await bridgeChannel.invokeMethod<List<Object?>>('getAudioTracks');
    return result
            ?.map(
              (item) => CommonAudioTrack.fromMap(item! as Map<Object?, Object?>),
            )
            .toList() ??
        const [];
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
    final result =
        await bridgeChannel.invokeMethod<Map<Object?, Object?>>('getVideoSize');
    if (result == null) return null;
    final size = CommonVideoSize.fromMap(result);
    return size.isValid ? size : null;
  }

  @override
  Future<void> setLooping(bool looping) =>
      _invoke('setLooping', {'looping': looping});

  @override
  Future<String?> captureFrame({
    bool highQuality = true,
    bool includeOverlay = false,
  }) =>
      bridgeChannel.invokeMethod<String>('captureFrame', {
        'highQuality': highQuality,
        'includeOverlay': includeOverlay,
      });

  Future<void> _invoke(String method, [Object? arguments]) async {
    if (bridgeDisposed) return;
    await bridgeChannel.invokeMethod(method, arguments);
  }
}
