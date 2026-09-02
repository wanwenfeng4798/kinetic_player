import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_player/kinetic_player.dart';
import 'package:kinetic_player/src/common/common_video_controller_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('CommonPlayerState indices match protocol contract', () {
    expect(CommonPlayerState.idle.index, 0);
    expect(CommonPlayerState.buffering.index, 1);
    expect(CommonPlayerState.ready.index, 2);
    expect(CommonPlayerState.playing.index, 3);
    expect(CommonPlayerState.paused.index, 4);
    expect(CommonPlayerState.completed.index, 5);
    expect(CommonPlayerState.error.index, 6);
  });

  group('platform routing', () {
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    test('createAuto returns GSY on Android', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final controller = CommonVideoPlayerFactory.createAuto(1);
      expect(controller, isA<GSYVideoControllerImpl>());
    });

    test('createAuto returns SG on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final controller = CommonVideoPlayerFactory.createAuto(1);
      expect(controller, isA<SGVideoControllerImpl>());
    });

    test('createAuto returns SG on macOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final controller = CommonVideoPlayerFactory.createAuto(1);
      expect(controller, isA<SGVideoControllerImpl>());
    });

    test('createAuto returns Mpv on Linux', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final controller = CommonVideoPlayerFactory.createAuto(1);
      expect(controller, isA<MpvVideoControllerImpl>());
    });

    test('createAuto returns Mpv on Windows', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final controller = CommonVideoPlayerFactory.createAuto(2);
      expect(controller, isA<MpvVideoControllerImpl>());
    });

    test('MpvVideoControllerImpl throws on Android', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(
        () => MpvVideoControllerImpl(3),
        throwsUnsupportedError,
      );
    });

    test('GSYVideoControllerImpl throws on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(
        () => GSYVideoControllerImpl(42),
        throwsUnsupportedError,
      );
    });

    test('SGVideoControllerImpl throws on Android', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(
        () => SGVideoControllerImpl(7),
        throwsUnsupportedError,
      );
    });

    test('ArtplayerVideoControllerImpl throws on non-web', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(
        () => ArtplayerVideoControllerImpl(9),
        throwsUnsupportedError,
      );
    });

    test('viewTypeForCurrentPlatform routes correctly', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(
        CommonVideoPlayerFactory.viewTypeForCurrentPlatform(),
        PlayerViewTypes.gsy,
      );

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(
        CommonVideoPlayerFactory.viewTypeForCurrentPlatform(),
        PlayerViewTypes.sg,
      );

      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(
        CommonVideoPlayerFactory.viewTypeForCurrentPlatform(),
        PlayerViewTypes.sg,
      );

      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(
        CommonVideoPlayerFactory.viewTypeForCurrentPlatform(),
        PlayerViewTypes.mpv,
      );

      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(
        CommonVideoPlayerFactory.viewTypeForCurrentPlatform(),
        PlayerViewTypes.mpv,
      );
    });
  });

  test('KineticChromeStrings normalizes locale and falls back to zh', () {
    expect(KineticChromeStrings.normalize(''), 'zh');
    expect(KineticChromeStrings.normalize('zh-CN'), 'zh');
    expect(KineticChromeStrings.normalize('tl'), 'fil');
    expect(KineticChromeStrings.normalize('fil'), 'fil');
    expect(KineticChromeStrings.normalize('unknown'), 'zh');
    expect(
      KineticChromeStrings.forLocale('en')['kinetic_settings_screenshot'],
      'Screenshot',
    );
    expect(
      KineticChromeStrings.forLocale('en')['kinetic_settings_gif'],
      'Record GIF',
    );
    expect(
      KineticChromeStrings.forLocale('zh')['kinetic_screenshot_saved'],
      '截图已保存',
    );
    expect(
      KineticChromeStrings.forLocale('xx')['kinetic_settings_title'],
      '设置',
    );
    final params = KineticChromeStrings.toCreationParams('ms');
    expect(params['locale'], 'ms');
    expect((params['strings'] as Map)['kinetic_settings_title'], 'Tetapan');
  });

  test('KineticUiConfig embeds locale and strings under ui', () {
    final params = const KineticUiConfig(locale: 'ms').toCreationParams();
    final ui = params['ui'] as Map;
    expect(ui['locale'], 'ms');
    expect((ui['strings'] as Map)['kinetic_settings_title'], 'Tetapan');
  });

  test('screenshotBytesFromNative accepts PNG bytes and data URLs', () {
    final png = Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47]);
    expect(screenshotBytesFromNative(png), png);
    expect(screenshotBytesFromNative(null), isNull);
    expect(
      screenshotBytesFromNative('data:image/png;base64,${base64Encode(png)}'),
      png,
    );
  });

  test('NativeSdkVersions pins latest desktop libmpv API', () {
    expect(NativeSdkVersions.libmpvWindows, '0.41.0');
    expect(NativeSdkVersions.libmpvLinux, '0.35.0');
  });

  test('MpvVideoTrack.fromMap parses GSY-shaped track maps', () {
    final track = MpvVideoTrack.fromMap({
      'index': 1,
      'label': '1080p',
      'language': 'und',
      'selected': true,
      'width': 1920,
      'height': 1080,
      'bitrate': 4000000,
    });
    expect(track.index, 1);
    expect(track.label, '1080p');
    expect(track.selected, isTrue);
    expect(track.width, 1920);
    expect(track.height, 1080);
    expect(track.bitrate, 4000000);
  });

  test('KineticHttpRequestOptions serializes channel args', () {
    const options = KineticHttpRequestOptions(
      userAgent: 'MyApp/1.0',
      headers: {'Authorization': 'Bearer x', 'Referer': 'https://a.test/'},
    );
    expect(options.isEmpty, isFalse);
    final args = options.toMethodChannelArgs();
    expect(args['userAgent'], 'MyApp/1.0');
    expect(args['headers'], isA<Map<String, String>>());
    expect((args['headers'] as Map)['Authorization'], 'Bearer x');

    final parsed = KineticHttpRequestOptions.fromMap({
      'userAgent': 'UA',
      'headers': {'A': '1'},
    });
    expect(parsed.userAgent, 'UA');
    expect(parsed.headers?['A'], '1');

    final fromCreate = KineticHttpRequestOptions.fromCreationParams({
      'userAgent': 'CreateUA',
      'headers': {'B': '2'},
      'url': 'https://ignored',
    });
    expect(fromCreate.userAgent, 'CreateUA');
    expect(fromCreate.headers?['B'], '2');

    expect(const KineticHttpRequestOptions().isEmpty, isTrue);
  });
}
