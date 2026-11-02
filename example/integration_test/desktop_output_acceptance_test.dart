import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kinetic_player/kinetic_player.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  Future<void> until(
    WidgetTester tester,
    bool Function() ready,
    String label,
  ) async {
    for (var tick = 0; tick < 200; tick++) {
      if (ready()) return;
      await tester.pump(const Duration(milliseconds: 100));
    }
    fail('Timeout: $label');
  }

  Future<void> mount(
    WidgetTester tester,
    String url,
    void Function(MpvVideoControllerImpl) created,
  ) => tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: SizedBox(
          width: 480,
          height: 320,
          child: CommonVideoPlayerViewBuilder(
            config: KineticPlayerConfig(
              url: url,
              ui: const KineticUiConfig(enableNativeControls: false),
            ),
            builder: (controller) =>
                created(controller as MpvVideoControllerImpl),
          ),
        ),
      ),
    ),
  );

  testWidgets('desktop output volume and mute change actual audio amplitude', (
    tester,
  ) async {
    if (!Platform.isWindows && !Platform.isLinux) return;
    final meter = Platform.environment['KINETIC_AUDIO_METER_EXE'];
    if (Platform.isWindows) {
      expect(
        meter,
        isNotNull,
        reason:
            'Build example/windows/acceptance and set KINETIC_AUDIO_METER_EXE',
      );
      expect(File(meter!).existsSync(), true);
    }
    final directory = await Directory(
      '${(await getTemporaryDirectory()).path}/kinetic-audio-acceptance',
    ).create(recursive: true);
    final file = File('${directory.path}/tone.wav');
    const samples = 48000 * 6;
    final wav = ByteData(44 + samples * 2);
    void ascii(int offset, String text) {
      for (var i = 0; i < text.length; i++) {
        wav.setUint8(offset + i, text.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    wav.setUint32(4, wav.lengthInBytes - 8, Endian.little);
    ascii(8, 'WAVEfmt ');
    wav.setUint32(16, 16, Endian.little);
    wav.setUint16(20, 1, Endian.little);
    wav.setUint16(22, 1, Endian.little);
    wav.setUint32(24, 48000, Endian.little);
    wav.setUint32(28, 96000, Endian.little);
    wav.setUint16(32, 2, Endian.little);
    wav.setUint16(34, 16, Endian.little);
    ascii(36, 'data');
    wav.setUint32(40, samples * 2, Endian.little);
    for (var i = 0; i < samples; i++) {
      wav.setInt16(
        44 + i * 2,
        (8000 * math.sin(2 * math.pi * 1000 * i / 48000)).round(),
        Endian.little,
      );
    }
    await file.writeAsBytes(wav.buffer.asUint8List());
    MpvVideoControllerImpl? player;
    await mount(tester, file.uri.toString(), (p) => player = p);
    await until(tester, () => player != null, 'audio controller');
    final p = player!;
    await p.setLooping(true);
    await p.setVolume(1);
    await p.setMute(false);
    await p.play();
    await until(
      tester,
      () => p.position.value.inMilliseconds > 300,
      'tone playing',
    );
    Future<double> peak() async {
      await tester.pump(const Duration(milliseconds: 400));
      if (Platform.isLinux) {
        // Measure the output sink monitor, never a microphone input.
        return (await tester.runAsync(() async {
          final process = await Process.start('parec', [
            '--device=@DEFAULT_MONITOR@',
            '--format=float32le',
            '--channels=1',
            '--rate=48000',
            '--raw',
            '--latency-msec=50',
            '--process-time-msec=20',
          ]);
          final data = process.stdout.fold<List<int>>(
            [],
            (a, b) => a..addAll(b),
          );
          final errors = process.stderr.transform(utf8.decoder).join();
          await Future<void>.delayed(const Duration(milliseconds: 1200));
          process.kill();
          final bytes = Uint8List.fromList(await data);
          final message = await errors;
          expect(bytes.length, greaterThan(0), reason: message);
          final samples = ByteData.sublistView(bytes);
          var maximum = 0.0;
          for (var i = 0; i + 4 <= bytes.length; i += 4) {
            maximum = math.max(
              maximum,
              samples.getFloat32(i, Endian.little).abs(),
            );
          }
          return maximum;
        }))!;
      }
      final result = await tester.runAsync(() => Process.run(meter!, ['$pid']));
      expect(result!.exitCode, 0, reason: '${result.stdout} ${result.stderr}');
      final output = jsonDecode(result.stdout as String) as Map;
      expect(output['samples'] as int, greaterThan(0));
      return (output['peak'] as num).toDouble();
    }

    final full = await peak();
    expect(
      full,
      greaterThan(0.02),
      reason: 'Decoded tone must reach the system output',
    );
      // Use a midrange level to distinguish attenuation from explicit mute.
      await p.setVolume(Platform.isLinux ? 0.5 : 0.1);
    final quiet = await peak();
    // libmpv uses a perceptual volume curve; require audible attenuation,
    // without assuming a linear slider-to-amplitude mapping.
    debugPrint('OUTPUT MEASURE full=$full quiet=$quiet');
    expect(quiet, greaterThan(full * 0.0001));
    expect(quiet, lessThan(full * 0.3));
    await p.setMute(true);
    final silent = await peak();
    debugPrint('OUTPUT MEASURE muted=$silent');
    expect(silent, lessThan(quiet * 0.1));
    await p.setVolume(1);
    await p.setMute(false);
    final restored = await peak();
    expect(restored, greaterThan(full * 0.7));
    debugPrint(
      'OUTPUT PASS full=$full quiet=$quiet muted=$silent restored=$restored',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    await directory.delete(recursive: true);
  });

  testWidgets(
    'native HTTP headers, range loading, 404 recovery and clearing options',
    (tester) async {
      if (!Platform.isWindows && !Platform.isLinux) return;
      final asset = await rootBundle.load(
        'integration_test/fixtures/orientation.mp4',
      );
      final bytes = asset.buffer.asUint8List(
        asset.offsetInBytes,
        asset.lengthInBytes,
      );
      final requests = <Map<String, String?>>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        requests.add({
          'path': request.uri.path,
          'token': request.headers.value('x-kinetic-test'),
          'agent': request.headers.value('user-agent'),
        });
        final response = request.response;
        try {
          if (request.uri.path == '/missing') {
            response.statusCode = 404;
            await response.close();
            return;
          }
          if (request.uri.path == '/protected' &&
              (request.headers.value('x-kinetic-test') != 'on' ||
                  request.headers.value('user-agent') !=
                      'KineticAcceptance/3.0')) {
            response.statusCode = 403;
            await response.close();
            return;
          }
          var start = 0;
          var end = bytes.length - 1;
          final range = request.headers.value('range');
          if (range != null) {
            final match = RegExp(r'^bytes=(\d+)-(\d*)$').firstMatch(range);
            if (match != null) {
              start = int.parse(match[1]!);
              if (match[2]!.isNotEmpty) {
                end = math.min(end, int.parse(match[2]!));
              }
            }
            if (start >= bytes.length) {
              response.statusCode = 416;
              await response.close();
              return;
            }
            response.statusCode = 206;
            response.headers.set(
              'Content-Range',
              'bytes $start-$end/${bytes.length}',
            );
          }
          response.headers.set('Accept-Ranges', 'bytes');
          response.headers.contentType = ContentType('video', 'mp4');
          response.contentLength = end - start + 1;
          response.add(bytes.sublist(start, end + 1));
          await response.close();
        } on SocketException {
          /* Native cancellation closes in-flight requests. */
        } on HttpException {
          /* Native cancellation closes in-flight requests. */
        }
      });
      addTearDown(() => server.close(force: true));
      MpvVideoControllerImpl? player;
      final base = 'http://127.0.0.1:${server.port}';
      await mount(tester, '$base/public', (p) => player = p);
      await until(tester, () => player != null, 'HTTP controller');
      final p = player!;
      await p.load(
        '$base/protected',
        http: const KineticHttpRequestOptions(
          userAgent: 'KineticAcceptance/3.0',
          headers: {'X-Kinetic-Test': 'on'},
        ),
      );
      await until(
        tester,
        () =>
            p.playerState.value == CommonPlayerState.playing &&
            p.position.value.inMilliseconds > 300,
        'authenticated native HTTP playback',
      );
      expect(
        requests.any(
          (r) =>
              r['path'] == '/protected' &&
              r['token'] == 'on' &&
              r['agent'] == 'KineticAcceptance/3.0',
        ),
        true,
      );
      await p.load('$base/missing');
      await until(
        tester,
        () => p.playerState.value == CommonPlayerState.error,
        '404 surfaces error',
      );
      await p.load('$base/public');
      await until(
        tester,
        () =>
            p.playerState.value == CommonPlayerState.playing &&
            p.position.value.inMilliseconds > 300,
        'recover after HTTP error',
      );
      expect(p.playerError.value, isNull);
      final public = requests.lastWhere((r) => r['path'] == '/public');
      expect(public['token'], isNull);
      expect(public['agent'], isNot('KineticAcceptance/3.0'));
      debugPrint(
        'HTTP PASS headers/range/404/recovery/clear options requests=${requests.length}',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );
}
