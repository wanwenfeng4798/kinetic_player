/// Native video frame dimensions in pixels.
class CommonVideoSize {
  const CommonVideoSize({
    required this.width,
    required this.height,
  });

  final int width;
  final int height;

  factory CommonVideoSize.fromMap(Map<Object?, Object?> map) {
    return CommonVideoSize(
      width: map['width'] as int? ?? 0,
      height: map['height'] as int? ?? 0,
    );
  }

  bool get isValid => width > 0 && height > 0;
}
