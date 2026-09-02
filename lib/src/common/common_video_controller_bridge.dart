import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../gsy/gsy_chrome_strings.dart';
import 'common_audio_track.dart';
import 'common_video_controller.dart';
import 'common_video_size.dart';
import 'kinetic_http_request_options.dart';

/// PNG bytes from a MethodChannel / JS result (raw bytes, or a data URL).
Uint8List? screenshotBytesFromNative(Object? value) {
  if (value == null) return null;
  if (value is Uint8List) return value;
  if (value is ByteBuffer) return value.asUint8List();
  if (value is ByteData) {
    return value.buffer.asUint8List(value.offsetInBytes, value.lengthInBytes);
  }
  if (value is String) {
    if (value.isEmpty) return null;
    var payload = value;
    final comma = payload.indexOf(',');
    if (payload.startsWith('data:') && comma >= 0) {
      payload = payload.substring(comma + 1);
    }
    try {
      return base64Decode(payload);
    } catch (_) {
      return null;
    }
  }
  if (value is List) {
    try {
      return Uint8List.fromList(List<int>.from(value));
    } catch (_) {
      return null;
    }
  }
  return null;
}

/// Shared MethodChannel bindings for cross-platform playback controls.
mixin CommonVideoControllerBridge implements CommonVideoController {
  MethodChannel get bridgeChannel;
  bool get bridgeDisposed;

  @override
  void Function(Uint8List? bytes)? onScreenshotCaptured;

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
  Future<void> setLocale(String locale) =>
      _invoke('setLocale', KineticChromeStrings.toCreationParams(locale));

  @override
  Future<void> setHttpRequestOptions(KineticHttpRequestOptions? options) =>
      _invoke(
        'setHttpRequestOptions',
        options?.toMethodChannelArgs() ?? const <String, dynamic>{},
      );

  @override
  Future<Uint8List?> captureFrame({
    bool highQuality = true,
    bool includeOverlay = false,
  }) async {
    final result = await bridgeChannel.invokeMethod<dynamic>(
      'captureFrame',
      {
        'highQuality': highQuality,
        'includeOverlay': includeOverlay,
      },
    );
    return screenshotBytesFromNative(result);
  }

  Future<void> _invoke(String method, [Object? arguments]) async {
    if (bridgeDisposed) return;
    await bridgeChannel.invokeMethod(method, arguments);
  }
}
