import '../common/kinetic_ui_config.dart';

/// Web-only Artplayer configuration extensions.
///
/// Universal UI toggles reuse [KineticUiConfig] via [ui].
/// Advanced Artplayer-only features go in [artplayerOptions] /
/// [artPlugins] / [webCustomExtensions] and never pollute
/// [CommonVideoController].
class ArtplayerUiConfig {
  const ArtplayerUiConfig({
    this.ui = const KineticUiConfig(),
    this.artplayerOptions,
    this.artPlugins,
    this.webCustomExtensions,
  });

  /// Shared chrome / PiP / looping / cover options (same keys as native).
  final KineticUiConfig ui;

  /// Passed through to `new Artplayer({...})` (layers, theme, etc.).
  final Map<String, dynamic>? artplayerOptions;

  /// Declarative Artplayer plugin enablement (Artplayer 5.4 + official plugins).
  ///
  /// Keys: `danmuku`, `danmukuMask`, `hlsControl`, `dashControl`,
  /// `vttThumbnail`, `multipleSubtitles`, `chromecast`, `vast`, `chapter`,
  /// `autoThumbnail`, `ambilight`, `documentPip`, `audioTrack`, `jassub`,
  /// `asr`, `ads`.
  ///
  /// Values: `true` for defaults, or a JSON map of plugin options.
  final Map<String, dynamic>? artPlugins;

  /// Alias hook for host-app Artplayer-only extensions.
  final Map<String, dynamic>? webCustomExtensions;

  Map<String, dynamic> toCreationParams() => <String, dynamic>{
        ...ui.toCreationParams(),
        if (artplayerOptions != null) 'artplayerOptions': artplayerOptions,
        if (artPlugins != null) 'artPlugins': artPlugins,
        if (webCustomExtensions != null)
          'webCustomExtensions': webCustomExtensions,
      };
}

/// Known [ArtplayerUiConfig.artPlugins] keys bundled in kinetic_player Web.
abstract final class ArtplayerPluginKeys {
  static const danmuku = 'danmuku';
  static const danmukuMask = 'danmukuMask';
  static const hlsControl = 'hlsControl';
  static const dashControl = 'dashControl';
  static const vttThumbnail = 'vttThumbnail';
  static const multipleSubtitles = 'multipleSubtitles';
  static const chromecast = 'chromecast';
  static const vast = 'vast';
  static const chapter = 'chapter';
  static const autoThumbnail = 'autoThumbnail';
  static const ambilight = 'ambilight';
  static const documentPip = 'documentPip';
  static const audioTrack = 'audioTrack';
  static const jassub = 'jassub';
  static const asr = 'asr';
  static const ads = 'ads';

  static const all = <String>[
    danmuku,
    danmukuMask,
    hlsControl,
    dashControl,
    vttThumbnail,
    multipleSubtitles,
    chromecast,
    vast,
    chapter,
    autoThumbnail,
    ambilight,
    documentPip,
    audioTrack,
    jassub,
    asr,
    ads,
  ];
}
