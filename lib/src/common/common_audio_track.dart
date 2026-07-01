/// Describes one selectable audio track exposed by the native player.
class CommonAudioTrack {
  const CommonAudioTrack({
    required this.index,
    required this.label,
    this.language,
    this.selected = false,
  });

  final int index;
  final String label;
  final String? language;
  final bool selected;

  factory CommonAudioTrack.fromMap(Map<Object?, Object?> map) {
    return CommonAudioTrack(
      index: map['index'] as int? ?? 0,
      label: map['label'] as String? ?? '',
      language: map['language'] as String?,
      selected: map['selected'] as bool? ?? false,
    );
  }
}
