@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;
import 'package:kinetic_player/src/web/artplayer_view_host.dart';

void main() {
  test(
    'initial configuration converts dynamically typed playlist and flags',
    () async {
      JSObject? attached;
      final bridge = JSObject();
      bridge.setProperty(
        'attach'.toJS,
        ((JSObject config) {
          attached = config;
        }).toJS,
      );
      final api = JSObject();
      api.setProperty('createBridge'.toJS, (() => bridge).toJS);
      web.window.setProperty('KineticArtplayer'.toJS, api);
      final host = ArtplayerViewHost(
        viewId: 42,
        element: web.HTMLDivElement(),
        params: {
          'playlist': <String>['first.mp4', 'second.mp4'],
          'playlistStartIndex': 1,
          'autoPlay': false,
          'autoPlayNext': true,
        },
      );
      await host.ready;
      expect(attached!.getProperty<JSAny?>('playlist'.toJS)?.dartify(), [
        'first.mp4',
        'second.mp4',
      ]);
      expect(
        attached!.getProperty<JSAny?>('playlistStartIndex'.toJS)?.dartify(),
        1,
      );
      expect(attached!.getProperty<JSAny?>('autoPlay'.toJS)?.dartify(), false);
      expect(
        attached!.getProperty<JSAny?>('autoPlayNext'.toJS)?.dartify(),
        true,
      );
      await host.dispose();
      web.window.delete('KineticArtplayer'.toJS);
    },
  );
}
