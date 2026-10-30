import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kinetic_player/kinetic_player.dart';
import 'package:kinetic_player/src/mpv/mpv_chrome.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MpvVideoControllerImpl controller;
  final calls = <MethodCall>[];
  bool fullscreen = false;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    controller = MpvVideoControllerImpl(741);
    debugDefaultTargetPlatformOverride = null;
    calls.clear();
    fullscreen = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(controller.bridgeChannel, (call) async {
          calls.add(call);
          if (call.method == 'mpvIsFullscreen') return fullscreen;
          if (call.method == 'mpvEnterFullscreen') fullscreen = true;
          if (call.method == 'mpvExitFullscreen') fullscreen = false;
          if (call.method == 'mpvListVideoTracks' ||
              call.method == 'getAudioTracks') {
            return [];
          }
          return null;
        });
  });
  tearDown(() async {
    await controller.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(controller.bridgeChannel, null);
    debugDefaultTargetPlatformOverride = null;
  });
  Widget player({double width = 900}) => MaterialApp(
    home: Center(
      child: SizedBox(
        width: width,
        height: 400,
        child: MpvChromeOverlay(
          controller: controller,
          config: const MpvChromeConfig(locale: 'en'),
        ),
      ),
    ),
  );

  testWidgets('small desktop view keeps all toolbar actions without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(player(width: 320));
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.byIcon(Icons.lock_open), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('common toolbar and panels fit compact and wide windows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [240.0, 280.0, 360.0, 720.0, 1280.0]) {
      await tester.pumpWidget(player(width: width));
      await tester.pump();
      final bounds = tester.getRect(find.byType(MpvChromeOverlay));
      for (final icon in [
        Icons.settings,
        Icons.volume_up,
        Icons.fullscreen,
        Icons.lock_open,
      ]) {
        final target = find.byIcon(icon);
        expect(target, findsOneWidget);
        final rect = tester.getRect(target);
        expect(
          bounds.contains(rect.topLeft) && bounds.contains(rect.bottomRight),
          true,
          reason: '$icon clipped at $width',
        );
      }
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pump();
      expect(
        tester.takeException(),
        isNull,
        reason: 'Settings overflow at $width',
      );
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pump();
      await tester.tap(find.text('1.0x'));
      await tester.pump();
      expect(
        tester.takeException(),
        isNull,
        reason: 'Rate panel overflow at $width',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets('right side lock hides toolbar and unlock restores controls', (
    tester,
  ) async {
    await tester.pumpWidget(player(width: 360));
    await tester.tap(find.byIcon(Icons.lock_open));
    await tester.pump();
    expect(find.byIcon(Icons.settings), findsNothing);
    expect(find.byIcon(Icons.lock), findsOneWidget);
    await tester.tap(find.byIcon(Icons.lock));
    await tester.pump();
    expect(find.byIcon(Icons.settings), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('fractional rate stays accurate in the common toolbar', (
    tester,
  ) async {
    await tester.pumpWidget(player());
    await controller.setRate(1.25);
    await tester.pump();
    expect(find.text('1.25x'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('external controller changes update desktop controls', (
    tester,
  ) async {
    await tester.pumpWidget(player());
    await controller.setMute(true);
    await tester.pump();
    expect(find.byIcon(Icons.volume_off), findsOneWidget);
    await controller.setVolume(0.5);
    await tester.pump();
    expect(find.byIcon(Icons.volume_up), findsOneWidget);
    await controller.setUiConfig(
      const KineticUiConfig(enableNativeControls: false),
    );
    await tester.pump();
    expect(find.byIcon(Icons.settings), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'keyboard seeks are clamped and disabled when native controls are hidden',
    (tester) async {
      controller.duration.value = const Duration(seconds: 100);
      controller.position.value = const Duration(seconds: 98);
      await tester.pumpWidget(player());
      await tester.tapAt(tester.getCenter(find.byType(MpvChromeOverlay)));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(calls.last.method, 'seekTo');
      expect(calls.last.arguments, {'position': 100000});
      await controller.setUiConfig(
        const KineticUiConfig(enableNativeControls: false),
      );
      await tester.pump();
      final before = calls.length;
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(calls.length, before);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'slider commits one seek and full screen button exits correctly',
    (tester) async {
      controller.duration.value = const Duration(seconds: 100);
      await tester.pumpWidget(player());
      final slider = tester.widget<Slider>(find.byType(Slider).first);
      slider.onChangeStart?.call(0);
      slider.onChanged?.call(1000);
      slider.onChanged?.call(2000);
      expect(calls.where((c) => c.method == 'seekTo'), isEmpty);
      slider.onChangeEnd?.call(3000);
      await tester.pump();
      expect(calls.where((c) => c.method == 'seekTo').length, 1);
      await tester.tap(find.byIcon(Icons.fullscreen));
      await tester.pumpAndSettle();
      expect(fullscreen, true);
      await tester.tap(find.byIcon(Icons.fullscreen_exit));
      await tester.pumpAndSettle();
      expect(fullscreen, false);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
