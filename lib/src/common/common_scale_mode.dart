/// Unified video scaling / render mode for both player cores.
enum CommonScaleMode {
  /// Fit inside the view bounds (letterbox).
  fit,

  /// Fill the view, cropping if necessary.
  fill,

  /// Stretch to fill without preserving aspect ratio.
  stretch,
}
