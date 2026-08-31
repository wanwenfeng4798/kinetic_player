/// libmpv-only APIs live on [MpvVideoControllerImpl]; keep them off
/// [CommonVideoController].
abstract final class MpvChannelNames {
  static const String plugin = 'com.example.player/mpv';

  static String instance(int viewId) => 'com.example.player/mpv_$viewId';
}

/// Network speed sample from libmpv `cache-speed` (same shape as GSY).
class MpvNetSpeed {
  const MpvNetSpeed({required this.bytesPerSecond, required this.text});

  final int bytesPerSecond;
  final String text;
}

/// One selectable video track from libmpv `track-list`.
class MpvVideoTrack {
  const MpvVideoTrack({
    required this.index,
    required this.label,
    this.language,
    this.selected = false,
    this.width = 0,
    this.height = 0,
    this.bitrate = 0,
  });

  final int index;
  final String label;
  final String? language;
  final bool selected;
  final int width;
  final int height;
  final int bitrate;

  factory MpvVideoTrack.fromMap(Map<Object?, Object?> map) {
    return MpvVideoTrack(
      index: map['index'] as int? ?? 0,
      label: map['label'] as String? ?? '',
      language: map['language'] as String?,
      selected: map['selected'] as bool? ?? false,
      width: map['width'] as int? ?? 0,
      height: map['height'] as int? ?? 0,
      bitrate: map['bitrate'] as int? ?? 0,
    );
  }
}
