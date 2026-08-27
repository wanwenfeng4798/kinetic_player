import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_player/kinetic_player.dart';

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

    test('createAuto throws on unsupported platform', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(
        () => CommonVideoPlayerFactory.createAuto(1),
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
}
