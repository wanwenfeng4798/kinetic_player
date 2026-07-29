/// Web / Artplayer view type and channel helpers.
abstract final class ArtplayerConstants {
  /// HtmlElementView / platform view type for Artplayer.
  static const String viewType = 'com.example.player/art_view_ui';

  /// MethodChannel name for a given [viewId].
  static String channelName(int viewId) => 'com.example.player/art_$viewId';
}
