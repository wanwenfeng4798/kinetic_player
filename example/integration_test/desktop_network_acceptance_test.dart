import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kinetic_player/kinetic_player.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

// Project demo URLs, kept explicit so the report names each failing provider.
const sources = <(String, String, String)>[
  ('Sample 5s', 'https://samplelib.com/lib/preview/mp4/sample-5s.mp4', 'MP4'),
  (
    'Flower',
    'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4',
    'MP4',
  ),
  (
    'Flower',
    'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.webm',
    'WebM',
  ),
  (
    'XGPlayer Demo 360p',
    'https://sf1-cdn-tos.huoshanstatic.com/obj/media-fe/xgplayer_doc_video/mp4/xgplayer-demo-360p.mp4',
    'MP4',
  ),
  ('Sintel Trailer', 'https://media.w3.org/2010/05/sintel/trailer.mp4', 'MP4'),
  (
    'Big Buck Bunny',
    'https://cdn.jsdelivr.net/gh/mediaelement/mediaelement-files@master/big_buck_bunny.mp4',
    'MP4',
  ),
  (
    'Apple BipBop fMP4',
    'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8',
    'HLS',
  ),
  (
    'Mux Big Buck Bunny',
    'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
    'HLS',
  ),
  (
    'Tears of Steel VOD',
    'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8',
    'HLS',
  ),
  (
    'XGPlayer HLS Demo',
    'https://sf1-cdn-tos.huoshanstatic.com/obj/media-fe/xgplayer_doc_video/hls/xgplayer-demo.m3u8',
    'HLS',
  ),
  (
    'Envivio MultiRate',
    'https://dash.akamaized.net/envivio/EnvivioDash3/manifest.mpd',
    'DASH',
  ),
  (
    'BBB 30fps MultiRate',
    'https://dash.akamaized.net/akamai/bbb_30fps/bbb_30fps.mpd',
    'DASH',
  ),
  (
    'Shaka Angel One',
    'https://storage.googleapis.com/shaka-demo-assets/angel-one/dash.mpd',
    'DASH',
  ),
  (
    'XGPlayer MPEG-TS 片段',
    'https://sf1-cdn-tos.huoshanstatic.com/obj/media-fe/xgplayer_doc_video/hls/segment-0.ts',
    'TS',
  ),
  (
    'Sintel Trailer Ogg',
    'https://media.w3.org/2010/05/sintel/trailer.ogv',
    'Ogg',
  ),
  (
    'ExoPlayer 音频',
    'https://storage.googleapis.com/exoplayer-test-media-0/play.mp3',
    'MP3',
  ),
  (
    'ExoPlayer lavf sample',
    'https://storage.googleapis.com/exoplayer-test-media-1/mkv/android-screens-lavf-56.36.100-aac-avc-main-1280x720.mkv',
    'MKV',
  ),
  (
    'XGPlayer Demo 360p',
    'https://sf1-cdn-tos.huoshanstatic.com/obj/media-fe/xgplayer_doc_video/flv/xgplayer-demo-360p.flv',
    'FLV',
  ),
];

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'all project network sources decode and expose selectable native tracks',
    (tester) async {
      if (!Platform.isWindows && !Platform.isLinux) return;
      final directory = await Directory(
        '${(await getTemporaryDirectory()).path}/kinetic-network-acceptance',
      ).create(recursive: true);
      final file = File('${directory.path}/seed.mp4');
      final asset = await rootBundle.load(
        'integration_test/fixtures/orientation.mp4',
      );
      await file.writeAsBytes(
        asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes),
      );
      MpvVideoControllerImpl? player;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 480,
              height: 320,
              child: CommonVideoPlayerViewBuilder(
                config: KineticPlayerConfig(
                  url: file.uri.toString(),
                  ui: const KineticUiConfig(enableNativeControls: false),
                ),
                builder: (controller) =>
                    player = controller as MpvVideoControllerImpl,
              ),
            ),
          ),
        ),
      );
      Future<bool> until(bool Function() ready, {int seconds = 30}) async {
        for (var tick = 0; tick < seconds * 10; tick++) {
          if (ready()) return true;
          await tester.pump(const Duration(milliseconds: 100));
        }
        return ready();
      }

      expect(await until(() => player != null), true);
      final p = player!;
      // Bound stalled requests during acceptance; production defaults stay intact.
      await p.mpvCommand(['set', 'network-timeout', '8']);
      await p.setAutoPlayNext(false);
      final failures = <String>[];
      for (final (name, url, format) in sources) {
        debugPrint('NETWORK START $format $name $url');
        try {
          await p.stop();
          expect(
            await until(
              () => p.playerState.value == CommonPlayerState.idle,
              seconds: 5,
            ),
            true,
          );
          await p.load(url);
          final ready = await until(
            () =>
                p.playerState.value == CommonPlayerState.error ||
                (p.playerState.value == CommonPlayerState.playing &&
                    p.position.value.inMilliseconds > 500),
          );
          expect(
            ready && p.playerState.value != CommonPlayerState.error,
            true,
            reason: '${p.playerState.value} ${p.playerError.value}',
          );
          final audio = await p.getAudioTracks();
          if (audio.isNotEmpty) {
            await p.selectAudioTrack(audio.first.index);
            await tester.pump(const Duration(milliseconds: 300));
            expect(
              (await p.getAudioTracks()).any(
                (t) => t.index == audio.first.index && t.selected,
              ),
              true,
            );
          }
          if (format != 'MP3') {
            final video = await p.mpvListVideoTracks();
            expect(video, isNotEmpty);
            expect(await p.mpvSelectVideoTrack(video.first.index), true);
            await tester.pump(const Duration(milliseconds: 300));
            expect(
              (await p.mpvListVideoTracks()).any(
                (t) => t.index == video.first.index && t.selected,
              ),
              true,
            );
            final png = await p.captureFrame();
            expect(png, isNotEmpty);
            expect(png!.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
          } else {
            expect(audio, isNotEmpty);
          }
          debugPrint(
            'NETWORK PASS $format $name time=${p.position.value} audioTracks=${audio.length}',
          );
        } catch (error) {
          failures.add('$format $name: $error');
          debugPrint('NETWORK FAIL $format $name: $error');
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      await directory.delete(recursive: true);
      expect(failures, isEmpty, reason: failures.join('\n'));
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
