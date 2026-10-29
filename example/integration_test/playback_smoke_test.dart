import 'network_access.dart';

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kinetic_player/kinetic_player.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native playback, pause, seek, capture and dispose', (
    tester,
  ) async {
    var source = const String.fromEnvironment(
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
      final file = File(
        '${directory.path}/kinetic-integration-orientation.mp4',
      );
      await file.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      source = file.uri.toString();
      addTearDown(() async {
        if (await file.exists()) await file.delete();
      });
    } else {
      await waitForMediaAccess(tester, source);
    }

    CommonVideoController? player;
    debugPrint('KINETIC_SMOKE mount');
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 360,
            height: 240,
            child: CommonVideoPlayerViewBuilder(
              config: KineticPlayerConfig(
                url: source,
                ui: const KineticUiConfig(enableNativeControls: true),
              ),
              builder: (controller) {
                player = controller;
              },
            ),
          ),
        ),
      ),
    );
    Future<void> until(
      bool Function() condition,
      String label, {
      int seconds = 60,
    }) async {
      for (var tick = 0; tick < seconds * 5; tick++) {
        if (condition()) return;
        if (player?.playerState.value == CommonPlayerState.error) {
          final detail = player is SGVideoControllerImpl
              ? await (player as SGVideoControllerImpl).getDiagnostics()
              : player.runtimeType.toString();
          fail('$label: native error: $detail');
        }
        await tester.pump(const Duration(milliseconds: 200));
      }
      fail(
        'Timeout: $label; state=${player?.playerState.value} position=${player?.position.value}',
      );
    }

    debugPrint('KINETIC_SMOKE wait controller');
    await until(() => player != null, 'controller');
    debugPrint('KINETIC_SMOKE play');
    await player!.play();
    await until(
      () => player!.position.value > const Duration(milliseconds: 500),
      'playhead advances',
    );
    expect(player!.duration.value, greaterThan(Duration.zero));
    debugPrint('KINETIC_SMOKE pause');
    await player!.pause();
    await until(
      () => player!.playerState.value == CommonPlayerState.paused,
      'paused',
    );
    await player!.seekTo(const Duration(seconds: 1));
    await until(
      () => (player!.position.value.inMilliseconds - 1000).abs() < 250,
      'seek',
      seconds: 15,
    );
    await player!.setRate(1.25);
    await player!.setVolume(0.2);
    await player!.setLooping(true);
    await player!.setLooping(false);
    debugPrint('KINETIC_SMOKE capture');
    Uint8List? png;
    for (var tick = 0; tick < 50; tick++) {
      png = await player!.captureFrame();
      if (png != null) break;
      await tester.pump(const Duration(milliseconds: 200));
    }
    if (player is SGVideoControllerImpl) {
      debugPrint(
        'KINETIC_SMOKE diagnostics=${await (player as SGVideoControllerImpl).getDiagnostics()}',
      );
    }
    expect(await player!.getVideoSize(), isNotNull);
    expect(png, isNotNull);
    expect(png!.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
    if (!kIsWeb && player is SGVideoControllerImpl) {
      expect(
        await (player as SGVideoControllerImpl).native.capabilities(),
        isNotEmpty,
      );
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
