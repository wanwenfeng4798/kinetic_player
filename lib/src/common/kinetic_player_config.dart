import 'kinetic_http_request_options.dart';
import 'kinetic_ui_config.dart';

/// The same source, playback and UI parameters for every backend.
class KineticPlayerConfig {
  const KineticPlayerConfig({
    this.url,
    this.playlist = const [],
    this.startIndex = 0,
    this.autoPlay = false,
    this.autoPlayNext = true,
    this.ui = const KineticUiConfig(),
    this.http,
    this.platformOptions = const {},
  });

  final String? url;
  final List<String> playlist;
  final int startIndex;
  final bool autoPlay;
  final bool autoPlayNext;
  final KineticUiConfig ui;
  final KineticHttpRequestOptions? http;

  /// Backend-only options; common typed fields take precedence.
  final Map<String, dynamic> platformOptions;

  Map<String, dynamic> toCreationParams() {
    if (playlist.isNotEmpty &&
        (startIndex < 0 || startIndex >= playlist.length)) {
      throw RangeError.index(startIndex, playlist, 'startIndex');
    }
    return {
      ...platformOptions,
      ...ui.toCreationParams(),
      ...?http?.toMethodChannelArgs(),
      if (url != null) 'url': url,
      'playlist': List<String>.of(playlist),
      'playlistStartIndex': startIndex,
      'autoPlay': autoPlay,
      'autoPlayNext': autoPlayNext,
    };
  }
}

/// Merge once before platform routing. Explicit widget URL takes precedence.
Map<String, dynamic> kineticCreationParams({
  String? url,
  Map<String, dynamic>? legacy,
  KineticPlayerConfig? config,
}) => {...?legacy, ...?config?.toCreationParams(), 'url': ?url};
