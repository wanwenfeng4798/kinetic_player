import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kinetic_player/kinetic_player.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('desktop visual effects, subtitles, timing, EOF and recovery', (
    tester,
  ) async {
    if (!Platform.isWindows && !Platform.isLinux) return;
    final directory = await Directory(
      '${(await getTemporaryDirectory()).path}/kinetic-acceptance',
    ).create(recursive: true);
    final media = File('${directory.path}/orientation.mp4');
    final data = await rootBundle.load(
      'integration_test/fixtures/orientation.mp4',
    );
    await media.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    final boundary = GlobalKey();
    MpvVideoControllerImpl? player;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 480,
            height: 320,
            child: RepaintBoundary(
              key: boundary,
              child: CommonVideoPlayerViewBuilder(
                config: KineticPlayerConfig(
                  url: media.uri.toString(),
                  ui: const KineticUiConfig(enableNativeControls: false),
                ),
                builder: (controller) =>
                    player = controller as MpvVideoControllerImpl,
              ),
            ),
          ),
        ),
      ),
    );
    Future<void> until(
      bool Function() ready,
      String label, {
      int seconds = 20,
    }) async {
      for (var tick = 0; tick < seconds * 10; tick++) {
        if (ready()) return;
        await tester.pump(const Duration(milliseconds: 100));
      }
      fail(
        '$label: state=${player?.playerState.value}, time=${player?.position.value}, error=${player?.playerError.value}',
      );
    }

    Future<Uint8List> rgba(Uint8List png) async {
      final codec = await ui.instantiateImageCodec(
        png,
        targetWidth: 480,
        targetHeight: 320,
      );
      final frame = await codec.getNextFrame();
      final result = (await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      frame.image.dispose();
      codec.dispose();
      return result;
    }

    Future<Uint8List> capture() async {
      final png = await player!.captureFrame();
      expect(png, isNotEmpty);
      return rgba(png!);
    }

    int difference(Uint8List a, Uint8List b) {
      expect(a.length, b.length);
      var changed = 0;
      for (var i = 0; i < a.length; i += 4) {
        if ((a[i] - b[i]).abs() +
                (a[i + 1] - b[i + 1]).abs() +
                (a[i + 2] - b[i + 2]).abs() >
            40) {
          changed++;
        }
      }
      return changed;
    }

    await until(() => player != null, 'controller');
    final p = player!;
    await p.play();
    await until(
      () => p.position.value.inMilliseconds > 500,
      'load local video',
    );
    await p.pause();
    await until(() => p.playerState.value == CommonPlayerState.paused, 'pause');
    await tester.pump(const Duration(milliseconds: 400));
    final still = p.position.value;
    await tester.pump(const Duration(milliseconds: 700));
    expect(
      (p.position.value - still).inMilliseconds.abs(),
      lessThan(150),
      reason: 'pause must stop native time',
    );
    final base = await capture();
    // Compare the actual Flutter texture with native RGBA, not just a PNG signature.
    final image =
        await (boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary)
            .toImage(pixelRatio: 1);
    final rendered = (await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!.buffer.asUint8List();
    final size = await p.getVideoSize();
    debugPrint(
      'ACCEPT texture=${image.width}x${image.height} native=$size bytes=${base.length}',
    );
    // Both captures use the 480x320 texture output. The colored corners expose R/B swaps.
    expect(rendered.length, base.length);
    for (final fraction in [0.25, 0.75]) {
      final offset =
          ((image.height * fraction).floor() * image.width +
              (image.width * 0.25).floor()) *
          4;
      for (var channel = 0; channel < 3; channel++) {
        expect(
          rendered[offset + channel],
          closeTo(base[offset + channel], 25),
          reason: 'texture channel $channel at $fraction',
        );
      }
    }
    image.dispose();
    debugPrint('ACCEPT native/texture colors passed');
    await p.setMirrorVertical(true);
    await tester.pump(const Duration(milliseconds: 700));
    expect(
      difference(base, await capture()),
      greaterThan(1000),
      reason: 'vertical mirror changes actual frame',
    );
    await p.setMirrorVertical(false);
    await tester.pump(const Duration(milliseconds: 700));
    expect(
      difference(base, await capture()),
      lessThan(500),
      reason: 'mirror restores original frame',
    );
    debugPrint('ACCEPT render transform passed');
    for (final format in ['vtt', 'srt']) {
      final subtitle = File('${directory.path}/acceptance.$format');
      await subtitle.writeAsString(
        format == 'vtt'
            ? 'WEBVTT\n\n00:00:00.000 --> 00:00:59.000\nACCEPTANCE SUBTITLE\n'
            : '1\n00:00:00,000 --> 00:00:59,000\nACCEPTANCE SUBTITLE\n',
      );
      await p.setSubtitleSource(subtitle.uri.toString());
      await p.setSubtitlesEnabled(true);
      await tester.pump(const Duration(seconds: 1));
      final visible = await capture();
      await p.setSubtitlesEnabled(false);
      await tester.pump(const Duration(milliseconds: 700));
      final hidden = await capture();
      expect(
        difference(visible, hidden),
        greaterThan(100),
        reason: '$format subtitles must render and hide',
      );
      debugPrint('ACCEPT $format rendered/hidden passed');
    }
    await p.setRate(2);
    final before = p.position.value;
    await p.play();
    final watch = Stopwatch()..start();
    await tester.pump(const Duration(seconds: 2));
    await p.pause();
    watch.stop();
    final ratio =
        (p.position.value - before).inMilliseconds / watch.elapsedMilliseconds;
    expect(
      ratio,
      inInclusiveRange(1.5, 2.6),
      reason: '2x must affect native playback time',
    );
    await p.setRate(1);
    debugPrint('ACCEPT 2x native timing passed ($ratio)');
    await p.mpvSetKeepLastFrameWhenComplete(enabled: true);
    await p.seekTo(p.duration.value - const Duration(milliseconds: 400));
    await p.play();
    await until(
      () => p.playerState.value == CommonPlayerState.completed,
      'EOF',
    );
    expect(
      await p.captureFrame(),
      isNotEmpty,
      reason: 'keep last frame at EOF',
    );
    await p.play();
    await until(
      () =>
          p.position.value.inMilliseconds > 100 &&
          p.position.value.inSeconds < 3 &&
          p.playerState.value == CommonPlayerState.playing,
      'replay after EOF',
    );
    await p.setPlaylist([
      media.uri.toString(),
      media.uri.toString(),
    ], autoPlay: false);
    await until(
      () =>
          p.playerState.value == CommonPlayerState.paused &&
          p.position.value.inMilliseconds < 500,
      'playlist restart',
    );
    await p.play();
    await until(
      () => p.position.value.inMilliseconds > 100,
      'playlist playback',
    );
    await p.setAutoPlayNext(true);
    await p.seekTo(p.duration.value - const Duration(milliseconds: 400));
    await until(
      () => p.position.value > p.duration.value - const Duration(seconds: 2),
      'seek near playlist EOF',
    );
    await until(
      () =>
          p.position.value.inMilliseconds > 100 &&
          p.position.value.inSeconds < 3 &&
          p.playerState.value == CommonPlayerState.playing,
      'automatic next at EOF',
    );
    await p.setAutoPlayNext(false);
    expect(await p.playNext(), false, reason: 'playlist reached final item');
    debugPrint('ACCEPT EOF/replay/automatic next/playlist end passed');
    await p.setLooping(true);
    await p.seekTo(p.duration.value - const Duration(milliseconds: 500));
    await until(() => p.position.value > p.duration.value - const Duration(seconds: 2), 'seek near loop EOF');
    await until(() => p.position.value.inMilliseconds > 100 && p.position.value.inSeconds < 3 && p.playerState.value == CommonPlayerState.playing, 'native loop restarts');
    await p.setLooping(false);
    debugPrint('ACCEPT native loop passed');

    await p.pause();
    await p.setUiConfig(
      const KineticUiConfig(
        locale: 'en',
        videoTitle: 'Acceptance title',
        progressColor: Color(0xff12ab34),
        volumeColor: Color(0xffab3412),
      ),
    );
    await p.mpvSetPurePlayMode(enabled: true);
    await tester.pump();
    expect(find.byIcon(Icons.settings), findsNothing);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    await tester.tap(find.byIcon(Icons.play_arrow));
    await until(
      () => p.playerState.value == CommonPlayerState.playing,
      'pure mode play',
    );
    await tester.tap(find.byIcon(Icons.pause));
    await until(
      () => p.playerState.value == CommonPlayerState.paused,
      'pure mode pause',
    );
    final watermark = File('${directory.path}/watermark.png');
    await watermark.writeAsBytes((await p.captureFrame())!);
    await p.mpvSetWatermarkUrl(watermark.path);
    await tester.pump(const Duration(milliseconds: 700));
    expect(
      find.byType(Image),
      findsOneWidget,
      reason: 'watermark creates a visible image',
    );
    await p.mpvSetWatermarkUrl(null);
    await tester.pump();
    expect(find.byType(Image), findsNothing);
    await p.mpvSetPurePlayMode(enabled: false);
    await tester.pump();
    expect(find.text('Acceptance title'), findsOneWidget);
    debugPrint('ACCEPT pure play/pause/watermark/title passed');
    await p.stop();
    await p.load(media.uri.toString());
    await until(
      () =>
          p.playerState.value == CommonPlayerState.playing &&
          p.position.value.inMilliseconds > 100,
      'reload after stop',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    await directory.delete(recursive: true);
  });
}
