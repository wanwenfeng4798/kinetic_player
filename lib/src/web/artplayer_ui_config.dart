import '../gsy/gsy_ui_config.dart';

/// Web-only Artplayer configuration extensions.
///
/// Universal UI toggles reuse [GsyUiConfig] via [ui].
/// Advanced Artplayer-only features go in [artplayerOptions] /
/// [webCustomExtensions] and never pollute [CommonVideoController].
class ArtplayerUiConfig {
  const ArtplayerUiConfig({
    this.ui = const GsyUiConfig(),
    this.artplayerOptions,
    this.webCustomExtensions,
  });

  /// Shared chrome / PiP / looping / cover options (same keys as native).
  final GsyUiConfig ui;

  /// Passed through to `new Artplayer({...})` (plugins, layers, etc.).
  final Map<String, dynamic>? artplayerOptions;

  /// Alias hook for host-app Artplayer-only extensions.
  final Map<String, dynamic>? webCustomExtensions;

  Map<String, dynamic> toCreationParams() => <String, dynamic>{
        ...ui.toCreationParams(),
        if (artplayerOptions != null) 'artplayerOptions': artplayerOptions,
        if (webCustomExtensions != null)
          'webCustomExtensions': webCustomExtensions,
      };
}
