/// Native PlatformView type identifiers registered per platform.
abstract final class PlayerViewTypes {
  /// Android-only GSY surface.
  static const String gsy = 'com.example.player/gsy_view_ui';

  /// iOS / macOS SG surface.
  static const String sg = 'com.example.player/sg_view_ui';

  /// Flutter Web Artplayer surface ([HtmlElementView]).
  static const String art = 'com.example.player/art_view_ui';

  /// Windows / Linux libmpv texture surface.
  static const String mpv = 'com.example.player/mpv_view_ui';
}
