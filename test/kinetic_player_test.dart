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
    });
  });
}
