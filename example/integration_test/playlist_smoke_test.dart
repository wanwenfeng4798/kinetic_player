import 'network_access.dart';

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kinetic_player/kinetic_player.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native playlist and idempotent fullscreen', (tester) async {
    CommonVideoController? player;
    var url = const String.fromEnvironment(
      'KINETIC_TEST_MEDIA_URL',
      defaultValue: 'https://samplelib.com/lib/preview/mp4/sample-5s.mp4',
    );
    if (const bool.fromEnvironment(
      'KINETIC_TEST_OFFLINE',
      defaultValue: true,
    )) {
      final bytes = await rootBundle.load(
        'integration_test/fixtures/orientation.mp4',
      );
      final directory = await getTemporaryDirectory();
      await directory.create(recursive: true);
      final file = File('${directory.path}/kinetic-playlist-orientation.mp4');
      await file.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      url = file.uri.toString();
      addTearDown(() async {
        if (await file.exists()) await file.delete();
      });
    }
    if (!const bool.fromEnvironment(
      'KINETIC_TEST_OFFLINE',
      defaultValue: true,
    )) {
      await waitForMediaAccess(tester, url);
    }
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 360,
            height: 240,
            child: CommonVideoPlayerViewBuilder(
              config: KineticPlayerConfig(
                url: url,
                ui: const KineticUiConfig(
                  dismissControlTime:
                      bool.fromEnvironment('KINETIC_TEST_NATIVE_UI')
                      ? 120000
                      : 2500,
                  lockLand: true,
                  autoFullWithSize: false,
                ),
              ),
              builder: (value) => player = value,
            ),
          ),
        ),
      ),
    );
    Future<void> waitFor(bool Function() condition, String label) async {
      for (var i = 0; i < 300; i++) {
        if (condition()) return;
        expect(
          player?.playerState.value,
          isNot(CommonPlayerState.error),
          reason: label,
        );
        await tester.pump(const Duration(milliseconds: 200));
      }
      fail('Timeout: $label');
    }

    await waitFor(() => player != null, 'controller');
    debugPrint('KINETIC_PLAYLIST load');
    await player!.setPlaylist([url, url], autoPlay: true);
    await waitFor(
      () => player!.position.value > const Duration(milliseconds: 500),
      'first item',
    );
    if (player is GSYVideoControllerImpl) {
      final bytes = await rootBundle.load('assets/sgplayer/i-see-fire.mp4');
      final directory = await getTemporaryDirectory();
      await directory.create(recursive: true);
      final alternate = File('${directory.path}/kinetic-switch-source.mp4');
      await alternate.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      addTearDown(() async {
        if (await alternate.exists()) await alternate.delete();
      });
      debugPrint('KINETIC_PLAYLIST switch distinct source');
      await player!.setPlaylist([alternate.uri.toString()], autoPlay: true);
      await waitFor(
        () =>
            player!.position.value > const Duration(milliseconds: 500) &&
            player!.playerState.value == CommonPlayerState.playing,
        'changed source plays',
      );
      await player!.setPlaylist([url, url], autoPlay: true);
      await waitFor(
        () =>
            player!.position.value > const Duration(milliseconds: 500) &&
            player!.playerState.value == CommonPlayerState.playing,
        'switch back plays',
      );
    }
    await player!.setAutoPlayNext(false);
    debugPrint('KINETIC_PLAYLIST manual next');
    expect(await player!.playNext(), true);
    await tester.pump(const Duration(seconds: 1));
    await waitFor(
      () => player!.playerState.value == CommonPlayerState.playing,
      'manual next',
    );
    debugPrint('KINETIC_PLAYLIST enter fullscreen');
    await player!.enterFullscreen();
    await tester.pump(const Duration(seconds: 1));
    expect(await player!.isFullscreen(), true);
    if (player is GSYVideoControllerImpl) {
      await tester.pump(const Duration(seconds: 2));
      expect(
        tester.view.physicalSize.width,
        greaterThan(tester.view.physicalSize.height),
        reason: 'Fullscreen must rotate the Activity and controls to landscape',
      );
      if (const bool.fromEnvironment('KINETIC_TEST_NATIVE_UI')) {
        await player!.pause();
        await tester.pump(const Duration(seconds: 1));
        debugPrint('KINETIC_LANDSCAPE_UI_READY');
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 90)),
        );
      }
    }
    debugPrint('KINETIC_PLAYLIST enter fullscreen');
    await player!.enterFullscreen();
    await tester.pump(const Duration(milliseconds: 500));
    expect(await player!.isFullscreen(), true);
    debugPrint('KINETIC_PLAYLIST exit fullscreen');
    await player!.exitFullscreen();
    await tester.pump(const Duration(seconds: 1));
    expect(await player!.isFullscreen(), false);
    await player!.pause();
    if (player is GSYVideoControllerImpl) {
      final gsy = player as GSYVideoControllerImpl;
      final bytes = await rootBundle.load('assets/sgplayer/cover.jpg');
      final directory = await getTemporaryDirectory();
      await directory.create(recursive: true);
      final image = File('${directory.path}/kinetic-watermark.jpg');
      await image.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      addTearDown(() async {
        if (await image.exists()) await image.delete();
      });
      await tester.pump(const Duration(seconds: 1));
      final before = await gsy.captureFrame(includeOverlay: true);
      expect(before, isNotNull);
      await gsy.gsySetWatermarkUrl(image.uri.toString());
      await tester.pump(const Duration(seconds: 2));
      final after = await gsy.captureFrame(includeOverlay: true);
      expect(after, isNotNull);
      expect(
        listEquals(before, after),
        false,
        reason: 'Watermark must change the paused overlay capture',
      );
      await gsy.gsySetWatermarkUrl(null);
      debugPrint('KINETIC_PLAYLIST local watermark capture changed');
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
