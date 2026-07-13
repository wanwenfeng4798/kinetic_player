/// SGPlayer display / VR modes.
enum SgDisplayMode {
  plane,
  vr,
  vrBox,
}

/// One segment in an [SGMutableAsset]-style playlist.
class SgMediaSegment {
  const SgMediaSegment({
    required this.url,
    this.streamIndex = 0,
    this.start,
    this.end,
  });

  final String url;

  /// Stream index inside the media file (0 = first matching type).
  final int streamIndex;

  /// Optional in-file start.
  final Duration? start;

  /// Optional in-file end.
  final Duration? end;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'url': url,
        'streamIndex': streamIndex,
        if (start != null) 'startMs': start!.inMilliseconds,
        if (end != null) 'endMs': end!.inMilliseconds,
      };
}

/// VR viewport parameters (maps to SGVRViewport).
class SgVrViewport {
  const SgVrViewport({
    this.degrees = 60,
    this.x = 0,
    this.y = 0,
    this.flipX = false,
    this.flipY = false,
    this.sensorEnable = true,
  });

  /// Field of view in degrees (SGPlayer property `degress`).
  final double degrees;
  final double x;
  final double y;
  final bool flipX;
  final bool flipY;
  final bool sensorEnable;

  factory SgVrViewport.fromMap(Map<Object?, Object?> map) {
    return SgVrViewport(
      degrees: (map['degrees'] as num?)?.toDouble() ?? 60,
      x: (map['x'] as num?)?.toDouble() ?? 0,
      y: (map['y'] as num?)?.toDouble() ?? 0,
      flipX: map['flipX'] as bool? ?? false,
      flipY: map['flipY'] as bool? ?? false,
      sensorEnable: map['sensorEnable'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'degrees': degrees,
        'x': x,
        'y': y,
        'flipX': flipX,
        'flipY': flipY,
        'sensorEnable': sensorEnable,
      };
}

/// Background / audio-interrupt policy (SGPlayer iOS).
class SgBackgroundPlaybackPolicy {
  const SgBackgroundPlaybackPolicy({
    this.pausesWhenInterrupted = true,
    this.pausesWhenEnteredBackground = false,
    this.pausesWhenEnteredBackgroundIfNoAudioTrack = true,
  });

  final bool pausesWhenInterrupted;
  final bool pausesWhenEnteredBackground;
  final bool pausesWhenEnteredBackgroundIfNoAudioTrack;

  factory SgBackgroundPlaybackPolicy.fromMap(Map<Object?, Object?> map) {
    return SgBackgroundPlaybackPolicy(
      pausesWhenInterrupted: map['pausesWhenInterrupted'] as bool? ?? true,
      pausesWhenEnteredBackground:
          map['pausesWhenEnteredBackground'] as bool? ?? false,
      pausesWhenEnteredBackgroundIfNoAudioTrack:
          map['pausesWhenEnteredBackgroundIfNoAudioTrack'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'pausesWhenInterrupted': pausesWhenInterrupted,
        'pausesWhenEnteredBackground': pausesWhenEnteredBackground,
        'pausesWhenEnteredBackgroundIfNoAudioTrack':
            pausesWhenEnteredBackgroundIfNoAudioTrack,
      };
}

/// FFmpeg demuxer / `avformat_open_input` options applied on next source load.
class SgDemuxerOptions {
  const SgDemuxerOptions({
    this.timeout,
    this.reconnect = true,
    this.userAgent,
    this.headers,
    this.extraOptions,
  });

  /// Socket timeout.
  final Duration? timeout;
  final bool reconnect;
  final String? userAgent;
  final Map<String, String>? headers;

  /// Raw FFmpeg option dictionary (string/number values).
  final Map<String, Object>? extraOptions;

  Map<String, dynamic> toMap() => <String, dynamic>{
        if (timeout != null)
          'timeoutMicros': timeout!.inMicroseconds,
        'reconnect': reconnect ? 1 : 0,
        if (userAgent != null) 'userAgent': userAgent,
        if (headers != null) 'headers': headers,
        if (extraOptions != null) 'options': extraOptions,
      };
}
