import '../gsy/gsy_video_controller_impl.dart';
import '../mpv/mpv_video_controller_impl.dart';
import '../sg/sg_video_controller_impl.dart';
import '../web/artplayer_video_controller.dart';
import '../web/artplayer_ui_config.dart';
import 'common_video_controller.dart';
import 'common_video_controller_bridge.dart';
import 'kinetic_http_request_options.dart';
import 'kinetic_ui_config.dart';

/// Common operations keep the same parameters; adapters route to native SDK APIs.
/// Backend-specific media/effects APIs remain on each concrete controller.
extension KineticPlayerActions on CommonVideoController {
  Future<Object?> _command(
    String suffix, [
    Map<String, dynamic> args = const {},
  ]) {
    final self = this;
    if (self is CommonVideoControllerBridge) {
      if (self.bridgeDisposed) throw StateError('Player disposed');
      final prefix = self is GSYVideoControllerImpl
          ? 'gsy'
          : self is SGVideoControllerImpl
          ? 'sg'
          : 'mpv';
      // Darwin retains these two historical GSY aliases for compatibility.
      final method =
          self is SGVideoControllerImpl &&
              (suffix == 'SetPlaylist' || suffix == 'PlayNextInPlaylist')
          ? 'gsy$suffix'
          : '$prefix$suffix';
      return self.bridgeChannel.invokeMethod<Object?>(method, args);
    }
    if (self is ArtplayerVideoControllerImpl) {
      return self.invokeCommand(suffix, args);
    }
    throw UnsupportedError('Unknown player backend');
  }

  /// Headers are applied before loading, identically on all platforms.
  Future<void> load(
    String url, {
    KineticHttpRequestOptions? http,
    bool autoPlay = true,
  }) async {
    await setHttpRequestOptions(http);
    await switchVideoSource(url, autoPlay: autoPlay);
  }

  Future<void> setPlaylist(
    List<String> urls, {
    int startIndex = 0,
    bool autoPlay = false,
  }) async {
    if (urls.isEmpty) {
      throw ArgumentError.value(urls, 'urls', 'Must not be empty');
    }
    if (startIndex < 0 || startIndex >= urls.length) {
      throw RangeError.index(startIndex, urls, 'startIndex');
    }
    await _command('SetPlaylist', {
      'urls': urls,
      'startIndex': startIndex,
      'autoPlay': autoPlay,
    });
  }

  Future<bool> playNext() async => await _command('PlayNextInPlaylist') == true;
  Future<void> setAutoPlayNext(bool enabled) async {
    final self = this;
    if (self is MpvVideoControllerImpl) {
      await self.mpvSetAutoPlayNext(enabled: enabled);
      return;
    }
    await _command('SetAutoPlayNext', {'enabled': enabled});
  }

  Future<void> enterFullscreen() async {
    await _command('EnterFullscreen');
  }

  Future<void> exitFullscreen() async {
    await _command('ExitFullscreen');
  }

  Future<bool> isFullscreen() async => await _command('IsFullscreen') == true;
  Future<void> setUiConfig(KineticUiConfig config) async {
    final self = this;
    if (self is MpvVideoControllerImpl) {
      await self.mpvSetUiConfig(config);
      return;
    }
    if (self is ArtplayerVideoControllerImpl) {
      await self.artSetUiConfig(ArtplayerUiConfig(ui: config));
      return;
    }
    await _command('SetUiConfig', config.toCreationParams());
  }

  Future<void> setCoverUrl(String? url) async {
    final self = this;
    if (self is MpvVideoControllerImpl) {
      await self.mpvSetCoverUrl(url);
      return;
    }
    await _command('SetCoverUrl', {'url': url});
  }

  bool get supportsRenderTransform => this is CommonVideoControllerBridge;
  Future<void> setRenderRotation(int degrees) async {
    if (!supportsRenderTransform) {
      throw UnsupportedError('This backend does not expose render rotation');
    }
    await _command('SetRenderRotation', {
      'degrees': ((degrees % 360) + 360) % 360,
    });
  }

  Future<void> setMirrorHorizontal(bool enabled) async {
    final self = this;
    if (!supportsRenderTransform) {
      throw UnsupportedError(
        'This backend does not expose combined render transforms',
      );
    }
    if (self is MpvVideoControllerImpl) {
      await self.mpvSetMirrorHorizontal(enabled: enabled);
      return;
    }
    await _command('SetMirrorHorizontal', {'enabled': enabled});
  }

  Future<void> setMirrorVertical(bool enabled) async {
    if (!supportsRenderTransform) {
      throw UnsupportedError(
        'This backend does not expose combined render transforms',
      );
    }
    await _command('SetMirrorVertical', {'enabled': enabled});
  }

  Future<void> setSubtitleSource(String url, {String? mimeType}) async {
    final self = this;
    if (self is SGVideoControllerImpl) {
      await self.native.loadSubtitles(url);
      return;
    }
    await _command('SetSubtitleUrl', {'url': url, 'mimeType': mimeType});
  }

  Future<void> setSubtitlesEnabled(bool enabled) async {
    final self = this;
    if (self is SGVideoControllerImpl) {
      await self.native.configureEffects({'subtitlesEnabled': enabled});
      return;
    }
    if (self is MpvVideoControllerImpl) {
      await self.mpvSetSubtitleEnabled(enabled: enabled);
      return;
    }
    await _command('SetSubtitleEnabled', {'enabled': enabled});
  }
}
