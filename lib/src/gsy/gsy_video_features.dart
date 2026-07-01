import '../common/common_scale_mode.dart';

/// GSY extended show types (maps to `GSYVideoType` on Android).
enum GsyShowType {
  /// SCREEN_TYPE_DEFAULT
  defaultRatio,

  /// SCREEN_TYPE_16_9
  ratio16x9,

  /// SCREEN_TYPE_4_3
  ratio4x3,

  /// SCREEN_TYPE_FULL (crop fill)
  full,

  /// SCREEN_MATCH_FULL (stretch)
  matchFull,

  /// SCREEN_TYPE_18_9
  ratio18x9,
}

/// GSY render surface type. GL filters require [glSurface].
enum GsyRenderType {
  texture,
  surface,
  glSurface,
}

/// Built-in GSY GL filter names (see [GSYVideoControllerImpl.gsyListEffectFilters]).
typedef GsyEffectFilterName = String;

extension GsyShowTypeIndex on GsyShowType {
  int get gsyIndex => index;
}

extension GsyRenderTypeIndex on GsyRenderType {
  int get gsyIndex => index;
}

/// Maps [CommonScaleMode] to GSY show type indices.
extension CommonScaleModeGsy on CommonScaleMode {
  int get gsyShowTypeIndex {
    switch (this) {
      case CommonScaleMode.fit:
        return GsyShowType.defaultRatio.gsyIndex;
      case CommonScaleMode.fill:
        return GsyShowType.full.gsyIndex;
      case CommonScaleMode.stretch:
        return GsyShowType.matchFull.gsyIndex;
    }
  }
}

/// Render core: 0=IJK, 1=Exo/Media3, 2=System MediaPlayer.
enum GsyRenderCore {
  ijk,
  exo,
  system,
}

extension GsyRenderCoreIndex on GsyRenderCore {
  int get gsyIndex => index;
}

/// Network speed sample from GSY.
class GsyNetSpeed {
  const GsyNetSpeed({required this.bytesPerSecond, required this.text});

  final int bytesPerSecond;
  final String text;
}
