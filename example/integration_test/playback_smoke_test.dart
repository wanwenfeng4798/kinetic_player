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
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
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
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();
    if (Platform.isIOS && player is SGVideoControllerImpl) {
      final sg = player as SGVideoControllerImpl;
      Map? nativeState;
      for (var attempt = 0; attempt < 100; attempt++) {
        nativeState = await sg.native.call<Map>('controls.status');
        if (nativeState?['applicationState'] == 0 &&
            nativeState?['windowAttached'] == true) {
          break;
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)),
        );
        await tester.pump();
      }
      expect(
        nativeState?['applicationState'],
        0,
        reason:
            'iOS App is inactive: dismiss system verification/permission '
            'dialogs and unlock the device before UI acceptance.',
      );
      expect(
        nativeState?['windowAttached'],
        true,
        reason: 'The native player must be attached to a visible window.',
      );
    }
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
      final sg = player as SGVideoControllerImpl;
      final directory = await getTemporaryDirectory();
      final vtt = File('${directory.path}/kinetic-parity.vtt');
      final xml = File('${directory.path}/kinetic-parity.xml');
      await vtt.writeAsString(
        'WEBVTT\n\n00:00:00.000 --> 00:00:04.000\nNative WebVTT\n',
      );
      await xml.writeAsString(
        '<i><d p="0,1,25,16711680">Native XML</d><d p="1,5,30,255">Top</d></i>',
      );
      await sg.setSubtitleSource(vtt.uri.toString(), mimeType: 'text/vtt');
      await sg.setSubtitlesEnabled(true);
      expect((await sg.native.subtitleTracks())['tracks'], isNotEmpty);
      final sprite = File('${directory.path}/kinetic-parity-sprite.png');
      await sprite.writeAsBytes(png);
      final preview = File('${directory.path}/kinetic-parity-preview.vtt');
      await preview.writeAsString(
        'WEBVTT\n\n00:00:00.000 --> 00:00:10.000\nkinetic-parity-sprite.png#xywh=0,0,32,32\n',
      );
      await sg.native.loadTimelineSprites(preview.uri.toString());
      final thumbnail = await sg.native.timelinePreviewImage(
        const Duration(seconds: 1),
      );
      expect(thumbnail, isNotNull);
      expect(thumbnail!.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
      await sg.native.loadTimelineSprites(null);
      await sprite.delete();
      await preview.delete();

      expect(await sg.native.loadDanmakuXml(xml.uri.toString()), 2);
      expect((await sg.native.effectsStatus())['danmakuCount'], 2);
      await sg.native.setWatermarks([
        {
          'text': 'Native watermark',
          'rect': {'x': .05, 'y': .05, 'width': .7, 'height': .2},
          'opacity': 1,
        },
      ]);
      expect((await sg.native.effectsStatus())['watermarkCount'], 1);
      await sg.native.configureEffects({
        'watermarksEnabled': false,
        'danmakuEnabled': false,
      });
      expect((await sg.native.effectsStatus())['watermarksEnabled'], false);
      await sg.native.configureControls(
        enabled: false,
        keepLastFrameWhenComplete: true,
        automaticPictureInPictureEnabled: true,
      );
      await tester.pump(const Duration(milliseconds: 600));
      final controls = await sg.native.call<Map>('controls.status');
      expect(controls?['hidden'], false); // Pure mode retains play/pause.
      expect(controls?['keepLastFrameWhenComplete'], true);
      await sg.native.configureControls(enabled: true);
      expect(await sg.native.showFloating(width: 280, height: 180), true);
      await tester.pump(const Duration(milliseconds: 600));
      expect(await sg.native.presentationMode(), 1);
      final floating = await sg.native.call<Map>('controls.status');
      expect(floating?['windowAttached'], true);
      expect((floating?['surfaceBounds'] as Map)['width'], closeTo(280, 1));
      expect(await sg.captureFrame(), isNotEmpty);
      await sg.native.restorePresentation();
      expect(await sg.native.presentationMode(), 0);
      if (Platform.isMacOS) {
        // Exercise the real composite player host, including controls/transforms.
        // Lifecycle assertions do not replace visible-window pixel acceptance.
        for (var attempt = 0; attempt < 2; attempt++) {
          expect(await sg.startPictureInPicture(), true);
          expect(await sg.isPictureInPictureActive(), true);
          expect(await sg.captureFrame(), isNotEmpty);
          await sg.stopPictureInPicture();
          expect(await sg.isPictureInPictureActive(), false);
          final restored = await sg.native.call<Map>('controls.status');
          expect(restored?['windowAttached'], true);
          expect((restored?['surfaceBounds'] as Map)['width'], closeTo(360, 1));
        }
      }
      // Native ad engine must restore the paused content at the same position.
      expect(
        await sg.native.playAdvertisement(
          source,
          skipAfter: const Duration(milliseconds: 400),
        ),
        true,
      );
      expect((await sg.native.advertisementStatus())['canSkip'], false);
      bool skippable = false;
      for (var attempt = 0; attempt < 100; attempt++) {
        final status = await sg.native.advertisementStatus();
        if (status['canSkip'] == true) {
          skippable = true;
          break;
        }
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(skippable, true);
      expect(await sg.native.skipAdvertisement(), true);
      await until(
        () => sg.playerState.value == CommonPlayerState.paused,
        'ad restores paused content',
      );
      if (Platform.isIOS &&
          const bool.fromEnvironment('KINETIC_TEST_BACKGROUND_PIP')) {
        await sg.native.configureControls(
          automaticPictureInPictureEnabled: true,
        );
        await sg.play();
        await until(
          () => sg.playerState.value == CommonPlayerState.playing,
          'ready for background PiP',
        );
        debugPrint('KINETIC_AUTO_PIP_BACKGROUND_READY');
        var sawActive = false;
        var sawProgress = false;
        Duration? activePosition;
        await tester.runAsync(() async {
          final deadline = DateTime.now().add(const Duration(seconds: 25));
          while (DateTime.now().isBefore(deadline)) {
            if (await sg.isPictureInPictureActive()) {
              sawActive = true;
              final position = await sg.getCurrentPosition();
              activePosition ??= position;
              if (position - activePosition! > const Duration(seconds: 1)) {
                sawProgress = true;
              }
            }
            await Future<void>.delayed(const Duration(milliseconds: 250));
          }
        });
        expect(
          sawActive,
          true,
          reason: 'PiP did not automatically activate in background',
        );
        expect(
          sawProgress,
          true,
          reason: 'Background PiP playhead did not advance',
        );
        await sg.stopPictureInPicture();
        await sg.pause();
        debugPrint('KINETIC_AUTO_PIP_BACKGROUND_PASSED');
      }
      await vtt.delete();
      await xml.delete();
      debugPrint(
        'KINETIC_PARITY subtitles/danmaku/WebVTT-preview/watermark/pure/last-frame/floating/ads passed',
      );
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
