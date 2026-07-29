import 'dart:ui_web' as ui_web;

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'src/web/artplayer_constants.dart';
import 'src/web/artplayer_view_host.dart';

/// Flutter Web plugin entry — registers the Artplayer HtmlElementView factory.
class KineticPlayerPlugin {
  static bool _registered = false;

  static void registerWith(Registrar registrar) {
    if (_registered) return;
    _registered = true;

    ui_web.platformViewRegistry.registerViewFactory(
      ArtplayerConstants.viewType,
      (int viewId, {Object? params}) {
        final element = web.HTMLDivElement()
          ..id = 'kinetic-artplayer-$viewId'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.position = 'relative'
          ..style.overflow = 'hidden'
          ..style.backgroundColor = '#000';

        final map = <String, dynamic>{};
        if (params is Map) {
          params.forEach((key, value) {
            map[key.toString()] = value;
          });
        }

        final host = ArtplayerViewHost(
          viewId: viewId,
          element: element,
          params: map,
        );
        ArtplayerViewRegistry.register(viewId, host);
        return element;
      },
    );

    // Warm the JS bridge in the background.
    ensureKineticArtplayerLoaded().ignore();
  }
}

extension on Future<void> {
  void ignore() {
    then((_) {}, onError: (_) {});
  }
}
