import 'package:flutter/services.dart';

/// Native SDK enums retain the upstream ordinal values.
enum SgPlaybackKernel { ffmpeg, native }

enum SgKernelPolicy { manual, preferNative, preferFfmpeg, automatic }

enum SgLoopMode { none, one, all }

enum SgMediaContainer { matroska, mp4, mpegTs }

/// Direct SGPlayer 2 adapters. Media processing always runs in the native SDK.
/// Times in maps use milliseconds unless the upstream field explicitly uses seconds.
class SgNativeFeatures {
  SgNativeFeatures(this._channel, this._isDisposed);
  void Function(Map<Object?, Object?> event)? onEvent;

  /// Navigate/restore the host screen before acknowledging the system PiP request.
  Future<bool> Function()? onRestorePictureInPicture;
  Future<bool> completePictureInPictureRestore(
    String requestId,
    bool restored,
  ) async =>
      await call<bool>('pip.restoreComplete', {
        'requestId': requestId,
        'restored': restored,
      }) ??
      false;
  final MethodChannel _channel;
  final bool Function() _isDisposed;

  /// Advanced access to the documented native operation inventory.
  Future<T?> call<T>(
    String operation, [
    Map<String, Object?> arguments = const {},
  ]) {
    if (_isDisposed()) throw StateError('Player disposed');
    return _channel.invokeMethod<T>('sgFeature', {
      'operation': operation,
      'arguments': arguments,
    });
  }

  Future<Map<Object?, Object?>> _map(
    String operation, [
    Map<String, Object?> arguments = const {},
  ]) async =>
      Map<Object?, Object?>.from(await call<Map>(operation, arguments) ?? {});

  Future<Map<Object?, Object?>> capabilities() => _map('capabilities');
  Future<bool> loadItems(
    List<Map<String, Object?>> items, {
    int startIndex = 0,
    bool autoPlay = true,
  }) async =>
      await call<bool>('session.load', {
        'items': items,
        'startIndex': startIndex,
        'autoPlay': autoPlay,
      }) ??
      false;
  Future<void> configureSession({
    SgKernelPolicy? kernelPolicy,
    bool? requiresFfmpeg,
    SgLoopMode? loopMode,
    bool? resumeEnabled,
    bool? automaticAdvance,
    Duration? loadingTimeout,
  }) => call<void>('session.configure', {
    if (kernelPolicy != null) 'kernelPolicy': kernelPolicy.index,
    'requiresFFmpeg': ?requiresFfmpeg,
    if (loopMode != null) 'loopMode': loopMode.index,
    'resumeEnabled': ?resumeEnabled,
    'automaticAdvance': ?automaticAdvance,
    if (loadingTimeout != null)
      'loadingTimeout': loadingTimeout.inMilliseconds / 1000,
  });
  Future<bool> selectItem(int index) async =>
      await call<bool>('session.selectItem', {'index': index}) ?? false;
  Future<bool> next() async => await call<bool>('session.next') ?? false;
  Future<bool> previous() async =>
      await call<bool>('session.previous') ?? false;
  Future<bool> selectRendition(int index) async =>
      await call<bool>('session.rendition', {'index': index}) ?? false;
  Future<bool> switchKernel(SgPlaybackKernel kernel) async =>
      await call<bool>('session.kernel', {'kernel': kernel.index}) ?? false;
  Future<bool> setLoopRange(Duration start, Duration end) async =>
      await call<bool>('session.loopRange', {
        'startMs': start.inMilliseconds,
        'endMs': end.inMilliseconds,
      }) ??
      false;
  Future<void> clearLoopRange() => call<void>('session.clearLoop');
  Future<bool> playAdvertisement(
    String url, {
    Duration skipAfter = const Duration(seconds: 3),
    bool fromBeginning = false,
  }) async =>
      await call<bool>('ads.play', {
        'url': url,
        'fromBeginning': fromBeginning,
        'skipAfterMs': skipAfter.inMilliseconds,
      }) ??
      false;
  Future<void> scheduleAdvertisements(List<Map<String, Object?>> items) =>
      call<void>('ads.schedule', {'items': items});
  Future<bool> skipAdvertisement() async =>
      await call<bool>('ads.skip') ?? false;
  Future<Map<Object?, Object?>> advertisementStatus() => _map('ads.status');
  Future<void> retry() => call<void>('session.retry');
  Future<void> saveResumePosition() => call<void>('session.saveResume');
  Future<Map<Object?, Object?>> diagnostics() => _map('session.diagnostics');
  Future<bool> exportDiagnostics(String destination) async =>
      await call<bool>('session.exportDiagnostics', {
        'destination': destination,
      }) ??
      false;
  Future<void> activateExclusivePlayback() =>
      call<void>('coordinator.activate');
  Future<void> pauseAllPlayers() => call<void>('coordinator.pauseAll');

  Future<bool> setNativePolicy({
    double? preferredPeakBitRate,
    int? maximumWidth,
    int? maximumHeight,
    double? preferredForwardBufferDuration,
    bool? automaticallyWaitsToMinimizeStalling,
    bool? allowsNetworkWhilePaused,
  }) async =>
      await call<bool>('native.policy', {
        'preferredPeakBitRate': ?preferredPeakBitRate,
        'maximumWidth': ?maximumWidth,
        'maximumHeight': ?maximumHeight,
        'preferredForwardBufferDuration': ?preferredForwardBufferDuration,
        'automaticallyWaitsToMinimizeStalling':
            ?automaticallyWaitsToMinimizeStalling,
        'allowsNetworkWhilePaused': ?allowsNetworkWhilePaused,
      }) ??
      false;
  Future<Map<Object?, Object?>> nativeMetrics() => _map('native.metrics');
  Future<List<Object?>> readSubtitles(String url) async =>
      await call<List<Object?>>('subtitles.read', {'url': url}) ?? [];
  Future<Uint8List?> composeImage(String localImage, Duration time) =>
      call<Uint8List>('effects.compose', {
        'imageURL': localImage,
        'timeMs': time.inMilliseconds,
      });
  Future<int> presentationMode() async =>
      await call<int>('presentation.status') ?? 0;
  Future<void> loadSubtitles(String url) =>
      call<void>('subtitles.load', {'url': url});
  Future<Map<Object?, Object?>> subtitleTracks() => _map('subtitles.tracks');
  Future<bool> selectSubtitle(int index, {bool secondary = false}) async =>
      await call<bool>('subtitles.select', {
        'index': index,
        'secondary': secondary,
      }) ??
      false;

  /// Offset/position, opacity, text size, subtitle font, sticker rect/start and limits.
  Future<void> configureEffects(Map<String, Object?> options) =>
      call<void>('effects.configure', options);

  /// Native validation covers curves, 3D cube, bloom, blur, color and flip controls.
  Future<void> setFilter(Map<String, Object?> options) =>
      call<void>('effects.filter', options);
  Future<void> setSubtitleCues(List<Map<String, Object?>> cues) =>
      call<void>('effects.subtitles', {'cues': cues});
  Future<int> loadDanmakuXml(String url) async =>
      await call<int>('effects.danmakuLoad', {'url': url}) ?? 0;
  Future<void> setDanmaku(List<Map<String, Object?>> items) =>
      call<void>('effects.danmaku', {'items': items});
  Future<void> setWatermarks(List<Map<String, Object?>> items) =>
      call<void>('effects.watermarks', {'items': items});
  Future<Map<Object?, Object?>> setSticker(
    String localFile, {
    int maximumBytes = 64 * 1024 * 1024,
  }) =>
      _map('effects.sticker', {'url': localFile, 'maximumBytes': maximumBytes});
  Future<void> removeSticker() => call<void>('effects.sticker');
  Future<void> flushEffects() => call<void>('effects.flush');
  Future<Map<Object?, Object?>> effectsStatus() => _map('effects.status');
  Future<void> configureControls({
    bool? enabled,
    bool? keepLastFrameWhenComplete,
    bool? automaticPictureInPictureEnabled,
    bool? locked,
    bool? showsKernelSelection,
    Duration? autoHideInterval,
  }) => call<void>('controls.configure', {
    'enabled': ?enabled,
    'keepLastFrameWhenComplete': ?keepLastFrameWhenComplete,
    'automaticPictureInPictureEnabled': ?automaticPictureInPictureEnabled,
    'locked': ?locked,
    'showsKernelSelection': ?showsKernelSelection,
    if (autoHideInterval != null)
      'autoHideInterval': autoHideInterval.inMilliseconds / 1000,
  });
  Future<void> loadTimelineSprites(String? url) =>
      call<void>('controls.preview.load', {'url': ?url});
  Future<Uint8List?> timelinePreviewImage(Duration time) => call<Uint8List>(
    'controls.preview.image',
    {'timeMs': time.inMilliseconds},
  );
  Future<void> revealControls() => call<void>('controls.reveal');
  Future<bool> seekBy(Duration offset) async =>
      await call<bool>('controls.seekBy', {
        'seconds': offset.inMilliseconds / 1000,
      }) ??
      false;
  Future<void> setCover(String? url, {Map<String, String>? headers}) =>
      call<void>('controls.cover', {'url': ?url, 'headers': ?headers});
  Future<bool> showFloating({
    double x = 16,
    double y = 16,
    double width = 400,
    double height = 225,
  }) async =>
      await call<bool>('presentation.floating', {
        'rect': {'x': x, 'y': y, 'width': width, 'height': height},
      }) ??
      false;
  Future<bool> showFullscreenInWindow() async =>
      await call<bool>('presentation.fullscreen') ?? false;
  Future<void> restorePresentation() => call<void>('presentation.restore');

  Future<String> createPreview(String url) async =>
      (await call<String>('preview.create', {'url': url}))!;
  Future<Uint8List?> previewImage(
    String id,
    Duration time, {
    int maximumDimension = 320,
  }) => call<Uint8List>('preview.image', {
    'id': id,
    'timeMs': time.inMilliseconds,
    'maximumDimension': maximumDimension,
  });
  Future<void> cancelPreview(String id) =>
      call<void>('preview.cancel', {'id': id});
  Future<String> createSpriteIndex(String webVtt, String baseUrl) async =>
      (await call<String>('preview.spriteIndex', {
        'webVTT': webVtt,
        'baseURL': baseUrl,
      }))!;
  Future<Map<Object?, Object?>?> spriteCue(String id, Duration time) async {
    final result = await call<Map>('preview.spriteCue', {
      'id': id,
      'timeMs': time.inMilliseconds,
    });
    return result == null ? null : Map<Object?, Object?>.from(result);
  }

  Future<Uint8List?> spriteImage(
    String id,
    Duration time,
    Uint8List imageData, {
    int maximumDimension = 320,
  }) => call<Uint8List>('preview.spriteImage', {
    'id': id,
    'timeMs': time.inMilliseconds,
    'imageData': imageData,
    'maximumDimension': maximumDimension,
  });
  Future<bool> openCache(String directory, {required int maximumBytes}) async =>
      await call<bool>('cache.open', {
        'directory': directory,
        'maximumBytes': maximumBytes,
      }) ??
      false;
  Future<Map<Object?, Object?>> cacheInfo() => _map('cache.info');
  Future<String?> cachedUrl(String url, {Map<String, String>? headers}) =>
      call<String>('cache.lookup', {'url': url, 'headers': ?headers});
  Future<String> download(
    String url, {
    Map<String, String>? headers,
    String? sha256,
  }) async => (await call<String>('cache.download', {
    'url': url,
    'headers': ?headers,
    'sha256': ?sha256,
  }))!;
  Future<bool> pinCached(String url, {Map<String, String>? headers}) async =>
      await call<bool>('cache.pin', {'url': url, 'headers': ?headers}) ?? false;
  Future<void> unpinCached(String url, {Map<String, String>? headers}) =>
      call<void>('cache.unpin', {'url': url, 'headers': ?headers});
  Future<void> clearUnpinnedCache() => call<void>('cache.clear');
  Future<void> closeCache() => call<void>('cache.close');
  Future<bool> hlsSupported() async =>
      await call<bool>('hls.supported') ?? false;
  Future<bool> openHlsStore(String backgroundIdentifier) async =>
      await call<bool>('hls.open', {
        'backgroundIdentifier':
            backgroundIdentifier.startsWith('kinetic_player.hls.')
            ? backgroundIdentifier
            : 'kinetic_player.hls.$backgroundIdentifier',
      }) ??
      false;
  Future<void> restoreHlsDownloads() => call<void>('hls.restore');
  Future<List<Object?>> hlsDownloads() async =>
      await call<List<Object?>>('hls.list') ?? [];
  Future<bool> downloadHls(
    String id,
    String url, {
    String? title,
    Map<String, String>? headers,
    List<Map<String, String>> cookies = const [],
  }) async =>
      await call<bool>('hls.download', {
        'cookies': cookies,
        'id': id,
        'url': url,
        'title': ?title,
        'headers': ?headers,
      }) ??
      false;
  Future<String?> offlineHlsUrl(String id) =>
      call<String>('hls.lookup', {'id': id});
  Future<void> cancelHls(String id) => call<void>('hls.cancel', {'id': id});
  Future<bool> removeHls(String id) async =>
      await call<bool>('hls.remove', {'id': id}) ?? false;
  Future<void> closeHlsStore() => call<void>('hls.close');
  Future<String> exportGif(
    String url,
    String destination, {
    required Duration start,
    required Duration end,
    int framesPerSecond = 10,
    int maximumDimension = 640,
    bool includeEffects = true,
  }) async => (await call<String>('export.gif', {
    'url': url,
    'destination': destination,
    'startMs': start.inMilliseconds,
    'endMs': end.inMilliseconds,
    'framesPerSecond': framesPerSecond,
    'maximumDimension': maximumDimension,
    'includeEffects': includeEffects,
  }))!;
  Future<String> remux(
    String url,
    String destination, {
    required Duration start,
    required Duration end,
    SgMediaContainer container = SgMediaContainer.mp4,
    Map<String, Object?> demuxerOptions = const {},
    double maximumWallTime = 3600,
  }) async => (await call<String>('export.remux', {
    'url': url,
    'destination': destination,
    'startMs': start.inMilliseconds,
    'endMs': end.inMilliseconds,
    'container': container.index,
    'demuxerOptions': demuxerOptions,
    'maximumWallTime': maximumWallTime,
  }))!;

  /// includeVideo=false in configuration exports audio only; effects are then omitted natively.
  Future<String> transcode(
    String url,
    String destination, {
    required Duration start,
    required Duration end,
    Map<String, Object?> configuration = const {},
    Map<String, Object?> demuxerOptions = const {},
    bool includeEffects = true,
    double maximumWallTime = 3600,
  }) async => (await call<String>('export.transcode', {
    'url': url,
    'destination': destination,
    'startMs': start.inMilliseconds,
    'endMs': end.inMilliseconds,
    'configuration': configuration,
    'demuxerOptions': demuxerOptions,
    'includeEffects': includeEffects,
    'maximumWallTime': maximumWallTime,
  }))!;
  Future<Map<Object?, Object?>> jobStatus(String id) =>
      _map('job.status', {'id': id});
  Future<void> cancelJob(String id) => call<void>('job.cancel', {'id': id});
  Future<void> removeJob(String id) => call<void>('job.remove', {'id': id});
}
