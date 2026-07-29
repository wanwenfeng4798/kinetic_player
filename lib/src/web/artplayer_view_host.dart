import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Host that owns one Artplayer instance and talks to the JS bridge.
class ArtplayerViewHost {
  ArtplayerViewHost({
    required this.viewId,
    required this.element,
    required Map<String, dynamic> params,
  }) {
    _init(params);
  }

  final int viewId;
  final web.HTMLDivElement element;

  JSObject? _bridge;
  bool _disposed = false;
  void Function(String method, Map<String, dynamic> args)? _eventSink;
  final Completer<void> _ready = Completer<void>();

  Future<void> get ready => _ready.future;

  void setEventSink(
    void Function(String method, Map<String, dynamic> args)? sink,
  ) {
    _eventSink = sink;
  }

  Future<void> _init(Map<String, dynamic> params) async {
    try {
      await ensureKineticArtplayerLoaded();
      if (_disposed) return;

      final kinetic =
          web.window.getProperty('KineticArtplayer'.toJS) as JSObject;
      final createBridge =
          kinetic.getProperty('createBridge'.toJS) as JSFunction;
      final bridge = createBridge.callAsFunction(kinetic) as JSObject;
      _bridge = bridge;

      final config = JSObject();
      config.setProperty('container'.toJS, element);
      final url = params['url'];
      if (url is String && url.isNotEmpty) {
        config.setProperty('url'.toJS, url.toJS);
      }
      final ui = params['gsyUi'];
      if (ui is Map) {
        config.setProperty('ui'.toJS, _mapToJs(ui));
      }
      final artOptions = params['artplayerOptions'];
      if (artOptions is Map) {
        config.setProperty('artplayerOptions'.toJS, _mapToJs(artOptions));
      }
      final extensions = params['webCustomExtensions'];
      if (extensions is Map) {
        config.setProperty('webCustomExtensions'.toJS, _mapToJs(extensions));
      }

      final onEvent = (JSString method, JSAny? args) {
        if (_disposed) return;
        final dartArgs = _jsToStringKeyedMap(args);
        _eventSink?.call(method.toDart, dartArgs);
      }.toJS;
      config.setProperty('onEvent'.toJS, onEvent);

      final attach = bridge.getProperty('attach'.toJS) as JSFunction;
      attach.callAsFunction(bridge, config);

      if (!_ready.isCompleted) _ready.complete();
    } catch (error, stack) {
      debugPrint('ArtplayerViewHost init failed: $error\n$stack');
      if (!_ready.isCompleted) {
        _ready.completeError(error, stack);
      }
      _eventSink?.call('onPlayerStateChanged', {'state': 6});
      _eventSink?.call('onError', {'message': error.toString()});
    }
  }

  Future<T?> invoke<T>(String method, [Map<String, dynamic>? arguments]) async {
    if (_disposed) return null;
    await ready;
    final bridge = _bridge;
    if (bridge == null) {
      throw StateError('Artplayer bridge not ready for view $viewId');
    }
    final handle = bridge.getProperty('handleMethod'.toJS) as JSFunction;
    final jsArgs = (arguments ?? <String, dynamic>{}).jsify();
    final result = handle.callAsFunction(bridge, method.toJS, jsArgs);
    if (result == null) return null;

    final resolved = await _awaitJs(result);
    final dartified = resolved?.dartify();
    return dartified as T?;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      final bridge = _bridge;
      if (bridge != null) {
        final handle = bridge.getProperty('handleMethod'.toJS) as JSFunction;
        final result =
            handle.callAsFunction(bridge, 'dispose'.toJS, JSObject());
        if (result != null) {
          await _awaitJs(result);
        }
      }
    } catch (_) {
      // ignore
    }
    _bridge = null;
    _eventSink = null;
    ArtplayerViewRegistry.unregister(viewId);
  }

  static JSAny? _mapToJs(Map map) {
    return Map<String, dynamic>.from(
      map.map((k, v) => MapEntry(k.toString(), v)),
    ).jsify();
  }

  static Map<String, dynamic> _jsToStringKeyedMap(JSAny? args) {
    final dartified = args?.dartify();
    if (dartified is Map) {
      return Map<String, dynamic>.from(
        dartified.map((k, v) => MapEntry(k.toString(), v)),
      );
    }
    return <String, dynamic>{};
  }

  static Future<JSAny?> _awaitJs(JSAny value) async {
    // If it's a Promise, await it; otherwise return as-is.
    try {
      final promise = value as JSPromise<JSAny?>;
      return await promise.toDart;
    } catch (_) {
      return value;
    }
  }
}

/// Registry mapping platform view ids to [ArtplayerViewHost].
abstract final class ArtplayerViewRegistry {
  static final Map<int, ArtplayerViewHost> _hosts = <int, ArtplayerViewHost>{};

  static void register(int viewId, ArtplayerViewHost host) {
    _hosts[viewId] = host;
  }

  static ArtplayerViewHost? get(int viewId) => _hosts[viewId];

  static void unregister(int viewId) {
    _hosts.remove(viewId);
  }
}

Completer<void>? _scriptCompleter;

/// Loads `assets/web/kinetic_artplayer.js` once and waits for `window.KineticArtplayer`.
Future<void> ensureKineticArtplayerLoaded() async {
  if (_isBridgeAvailable()) return;
  if (_scriptCompleter != null) return _scriptCompleter!.future;

  final completer = Completer<void>();
  _scriptCompleter = completer;

  try {
    final existing = web.document.querySelector(
      'script[data-kinetic-artplayer="1"]',
    );
    if (existing == null) {
      final script = web.HTMLScriptElement()
        ..async = true
        ..dataset['kineticArtplayer'] = '1'
        ..src =
            'assets/packages/kinetic_player/assets/web/kinetic_artplayer.js';

      final load = Completer<void>();
      script.onload = (web.Event _) {
        load.complete();
      }.toJS;
      script.onerror = (web.Event _) {
        load.completeError(
          StateError('Failed to load kinetic_artplayer.js'),
        );
      }.toJS;
      web.document.head!.append(script);
      await load.future;
    }

    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (!_isBridgeAvailable()) {
      if (DateTime.now().isAfter(deadline)) {
        throw StateError('window.KineticArtplayer is not available');
      }
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
    completer.complete();
  } catch (error, stack) {
    _scriptCompleter = null;
    completer.completeError(error, stack);
    rethrow;
  }
}

bool _isBridgeAvailable() {
  final value = web.window.getProperty('KineticArtplayer'.toJS);
  return value != null;
}
