import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kinetic_player/kinetic_player.dart';
import 'package:kinetic_player/src/mpv/mpv_chrome.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kinetic_player_example/main.dart' as demo;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('real demo rotation buttons, reset and desktop actions', (tester) async {
    if (!Platform.isLinux && !Platform.isWindows) return;
    await tester.pumpWidget(const demo.KineticPlayerExampleApp());
    for (var i = 0; i < 200 && find.byType(MpvChromeOverlay).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final p = tester.widget<MpvChromeOverlay>(find.byType(MpvChromeOverlay)).controller;
    for (var i = 0; i < 200 && p.duration.value.inSeconds == 0; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(p.duration.value.inSeconds, greaterThan(0));
    await p.pause();
    Future<void> tapText(String label) async {
      final target = find.text(label).first;
      await tester.ensureVisible(target);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(target);
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.takeException(), isNull, reason: label);
    }
    final base = await p.captureFrame();
    expect(base, isNotEmpty);
    for (var i = 0; i < 4; i++) {
      await tapText('右转 90°');
    }
    expect(listEquals(base, await p.captureFrame()), true, reason: 'four turns restore pixels');
    await tapText('左转 90°');
    expect(listEquals(base, await p.captureFrame()), false);
    await tapText('复位 0°');
    expect(listEquals(base, await p.captureFrame()), true, reason: 'reset calls native controller');
    debugPrint('DEMO PASS left/right rotations and real reset pixels');
    for (final label in ['设置 UA / headers', '清除 HTTP 选项', '截图 captureFrame', '网速']) {
      await tapText(label);
    }
    for (var i = 0; i < 2; i++) {
      await tapText(p.watermarkUrl.value == null ? '水印: 关' : '水印: 开');
      await tapText(p.purePlayMode.value ? '纯播放: 开' : '纯播放: 关');
      await tapText(p.subtitleEnabled.value ? '字幕: 开' : '字幕: 关');
    }
    await tapText('播放下一首');
    for (var i = 0; i < 2; i++) {
      await tapText(p.coverUrl.value == null ? '封面: 关' : '封面: 开');
      await tapText(p.keepLastFrame.value ? '保留最后一帧: 开' : '保留最后一帧: 关');
    }
    await p.play();
    await tester.pump(const Duration(seconds: 1));
    expect(p.playerState.value, CommonPlayerState.playing);
    await p.pause();
    await tester.pump(const Duration(milliseconds: 400));
    expect(p.playerState.value, CommonPlayerState.paused);
    debugPrint('DEMO PASS HTTP/screenshot/network/watermark/pure/subtitle/next/cover/last-frame/play/pause');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
