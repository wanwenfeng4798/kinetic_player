import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_player/kinetic_player.dart';
import 'package:kinetic_player/src/common/common_video_controller_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test(
    'typed configuration wins over legacy fields, explicit URL wins last',
    () {
      final params = kineticCreationParams(
        url: 'https://explicit.test/v.mp4',
        legacy: {
          'url': 'legacy',
          'headers': {'old': 'yes'},
        },
        config: const KineticPlayerConfig(
          url: 'typed',
          autoPlay: true,
          autoPlayNext: false,
          playlist: ['one', 'two'],
          startIndex: 1,
          http: KineticHttpRequestOptions(
            headers: {'Authorization': 'test-only'},
          ),
          ui: KineticUiConfig(speed: 1.5, looping: true),
        ),
      );
      expect(params['url'], 'https://explicit.test/v.mp4');
      expect(params['autoPlay'], true);
      expect(params['autoPlayNext'], false);
      expect(params['playlistStartIndex'], 1);
      expect(params['headers'], {'Authorization': 'test-only'});
      expect((params['ui'] as Map)['speed'], 1.5);
      expect((params['ui'] as Map)['looping'], true);
    },
  );

  test('invalid common parameters fail before reaching native code', () {
    expect(() => kineticPlaybackRate(double.nan), throwsArgumentError);
    expect(() => kineticPlaybackRate(0), throwsArgumentError);
    expect(() => kineticVolume(double.infinity), throwsArgumentError);
    expect(kineticVolume(2), 1);
    expect(kineticVolume(-1), 0);
    expect(
      () => const KineticPlayerConfig(
        playlist: ['one'],
        startIndex: 2,
      ).toCreationParams(),
      throwsRangeError,
    );
  });

  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ]) {
    test('common playlist/fullscreen parameters route on $platform', () async {
      debugDefaultTargetPlatformOverride = platform;
      final controller = CommonVideoPlayerFactory.createAuto(731);
      final bridge = controller as CommonVideoControllerBridge;
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(bridge.bridgeChannel, (call) async {
            calls.add(call);
            if (call.method.endsWith('IsFullscreen') ||
                call.method.endsWith('PlayNextInPlaylist')) {
              return true;
            }
            return null;
          });
      await controller.setPlaylist(
        ['one', 'two'],
        startIndex: 1,
        autoPlay: true,
      );
      expect(calls.last.arguments, {
        'urls': ['one', 'two'],
        'startIndex': 1,
        'autoPlay': true,
      });
      expect(await controller.playNext(), true);
      await controller.enterFullscreen();
      expect(calls.last.method.endsWith('EnterFullscreen'), true);
      expect(await controller.isFullscreen(), true);
      await controller.exitFullscreen();
      await controller.setAutoPlayNext(false);
      expect(calls.last.arguments, {'enabled': false});
      final count = calls.length;
      await expectLater(
        controller.setPlaylist([], autoPlay: true),
        throwsArgumentError,
      );
      expect(calls.length, count);
      await controller.load(
        'https://media.test/file.mp4',
        http: const KineticHttpRequestOptions(headers: {'X-Test': 'value'}),
        autoPlay: false,
      );
      expect(calls[calls.length - 2].method, 'setHttpRequestOptions');
      expect(calls.last.method, 'switchVideoSource');
      expect(calls.last.arguments, {
        'url': 'https://media.test/file.mp4',
        'autoPlay': false,
      });
      await controller.setRenderRotation(-90);
      expect(calls.last.arguments, {'degrees': 270});
      await controller.setCoverUrl(null);
      expect(calls.last.arguments, {'url': null});
      await controller.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(bridge.bridgeChannel, null);
    });
  }

  test(
    'SG features forward to the SDK and deliver native task events',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final controller = SGVideoControllerImpl(732);
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(controller.bridgeChannel, (call) async {
            calls.add(call);
            if (call.method == 'sgFeature') {
              final operation = (call.arguments as Map)['operation'];
              if (operation == 'export.transcode') return 'job-1';
              if (operation == 'session.loopRange') return true;
              if (operation == 'job.status') {
                return {
                  'state': 'completed',
                  'result': {'url': 'file:///output.mp4'},
                };
              }
            }
            return null;
          });
      await controller.native.setFilter({
        'grayscale': true,
        'bloomRadius': 2.0,
      });
      expect((calls.last.arguments as Map)['arguments'], {
        'grayscale': true,
        'bloomRadius': 2.0,
      });
      expect(
        await controller.native.setLoopRange(
          const Duration(seconds: 1),
          const Duration(seconds: 5),
        ),
        true,
      );
      expect((calls.last.arguments as Map)['arguments'], {
        'startMs': 1000,
        'endMs': 5000,
      });
      final job = await controller.native.transcode(
        'https://media.test/video',
        '/tmp/output.mp4',
        start: Duration.zero,
        end: const Duration(seconds: 2),
        configuration: {'includeVideo': false},
      );
      expect(job, 'job-1');
      expect((await controller.native.jobStatus(job))['state'], 'completed');
      await controller.dispose();
      await expectLater(controller.native.capabilities(), throwsStateError);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(controller.bridgeChannel, null);
    },
  );
}
