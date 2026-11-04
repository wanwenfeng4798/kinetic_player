import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kinetic_player/kinetic_player.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Apple autoplay prepares background PiP audio configuration', (
    tester,
  ) async {
    if (!Platform.isIOS) return;
    final bytes = await rootBundle.load(
      'integration_test/fixtures/orientation.mp4',
    );
    final file = File(
      '${(await getTemporaryDirectory()).path}/kinetic-background-config.mp4',
    );
    await file.writeAsBytes(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
    SGVideoControllerImpl? player;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 360,
            height: 240,
            child: CommonVideoPlayerViewBuilder(
              config: KineticPlayerConfig(
                url: file.uri.toString(),
                autoPlay: true,
                ui: const KineticUiConfig(
                  pictureInPictureEnabled: true,
                  looping: true,
                ),
              ),
              builder: (controller) =>
                  player = controller as SGVideoControllerImpl,
            ),
          ),
        ),
      ),
    );
    // Do not call Dart play(): exercise native autoplay, the previously bypassed path.
    for (
      var i = 0;
      i < 150 &&
          (player == null || player!.position.value.inMilliseconds < 500);
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(player, isNotNull);
    expect(player!.position.value.inMilliseconds, greaterThanOrEqualTo(500));
    final diagnostics = await player!.getDiagnostics();
    final controls = await player!.native.call<Map>('controls.status');
    debugPrint(
      'AUTOPLAY_BACKGROUND_CONFIGURATION $diagnostics controls=$controls',
    );
    expect(diagnostics['backgroundAudioEnabled'], true);
    expect(controls?['automaticPictureInPictureEnabled'], true);
    expect(
      diagnostics['audioSessionCategory'],
      'AVAudioSessionCategoryPlayback',
    );
    expect(diagnostics['audioSessionMode'], 'AVAudioSessionModeMoviePlayback');
    if (const bool.fromEnvironment('KINETIC_TEST_BACKGROUND_PIP')) {
      debugPrint('KINETIC_PLUGIN_BACKGROUND_PIP_READY');
      var confirmed = false;
      Duration? initial;
      await tester.runAsync(() async {
        final deadline = DateTime.now().add(const Duration(minutes: 5));
        while (DateTime.now().isBefore(deadline)) {
          if (await player!.isPictureInPictureActive()) {
            final position = await player!.getCurrentPosition();
            initial ??= position;
            if (position - initial! > const Duration(seconds: 2)) {
              confirmed = true;
              break;
            }
          }
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      });
      expect(
        confirmed,
        true,
        reason: 'Autoplay PiP must activate and advance in background',
      );
      debugPrint('KINETIC_PLUGIN_BACKGROUND_PIP_PASSED');
      await player!.stopPictureInPicture();
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    await file.delete();
  });
}
