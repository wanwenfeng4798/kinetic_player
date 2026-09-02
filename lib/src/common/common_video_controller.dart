import 'package:flutter/foundation.dart';

import 'common_audio_track.dart';
import 'common_player_state.dart';
import 'common_scale_mode.dart';
import 'common_video_size.dart';
import 'kinetic_http_request_options.dart';

/// Pure unified controller contract. Player-specific APIs live on concrete
/// implementations and must be accessed via explicit downcasting.
abstract class CommonVideoController {
  ValueNotifier<CommonPlayerState> get playerState;
  ValueNotifier<Duration> get position;
  ValueNotifier<Duration> get duration;

  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seekTo(Duration position);
  Future<void> setScaleMode(CommonScaleMode mode);
  Future<void> setRate(double rate);
  Future<void> setVolume(double volume);
  Future<void> setMute(bool muted);
  Future<void> switchVideoSource(String url, {bool autoPlay = true});
  Future<List<CommonAudioTrack>> getAudioTracks();
  Future<void> selectAudioTrack(int index);
  Future<Duration> getDuration();
  Future<Duration> getCurrentPosition();
  Future<CommonVideoSize?> getVideoSize();
  Future<void> setLooping(bool looping);

  /// Chrome copy language: `zh` / `en` / `vi` / `ms` / `id` / `fil`.
  ///
  /// Unknown codes fall back to `zh`. Pass `KineticUiConfig.locale` at create;
  /// call this to hot-swap native / Artplayer chrome without `gsySetUiConfig`.
  Future<void> setLocale(String locale);

  /// Persist custom HTTP [User-Agent] / headers for subsequent media loads.
  ///
  /// Pass `null` or an empty [KineticHttpRequestOptions] to clear. Also
  /// accept `creationParams['userAgent']` / `creationParams['headers']` at
  /// view create. Does not change [switchVideoSource] signature — call this
  /// before switching sources when needed.
  Future<void> setHttpRequestOptions(KineticHttpRequestOptions? options);

  /// [includeOverlay] includes native chrome on Android (GSY); ignored on iOS.
  /// Returns PNG bytes, or null on failure. The plugin does not write files.
  Future<Uint8List?> captureFrame({
    bool highQuality = true,
    bool includeOverlay = false,
  });

  /// Native settings screenshot finished. [bytes] is PNG data (null on failure).
  ///
  /// The plugin does not write to disk or Photos; save [bytes] in the host.
  void Function(Uint8List? bytes)? onScreenshotCaptured;

  Future<void> dispose();
}
