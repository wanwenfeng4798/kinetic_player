import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Only start native media after an actual request succeeds. The first request
/// may trigger iOS network authorization; failure must not fall through to play.
Future<void> waitForMediaAccess(WidgetTester tester, String url) async {
  await tester.pumpWidget(
    const Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: Color(0xff000000),
        child: Center(
          child: Text(
            '请允许系统网络访问，授权完成后才会开始媒体测试。',
            style: TextStyle(color: Color(0xffffffff), fontSize: 20),
          ),
        ),
      ),
    ),
  );
  await tester.runAsync(() async {
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    Object? lastError;
    while (DateTime.now().isBefore(deadline)) {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8);
      try {
        final request = await client
            .getUrl(Uri.parse(url))
            .timeout(const Duration(seconds: 8));
        request.headers.set('Range', 'bytes=0-1023');
        final response = await request.close().timeout(
          const Duration(seconds: 8),
        );
        if (response.statusCode != 200 && response.statusCode != 206) {
          throw HttpException(
            'HTTP ${response.statusCode}',
            uri: Uri.parse(url),
          );
        }
        await response.first.timeout(const Duration(seconds: 8));
        debugPrint('KINETIC_HTTP ready status=${response.statusCode}');
        return;
      } catch (error) {
        lastError = error;
      } finally {
        client.close(force: true);
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    fail(
      'Network authorization/connectivity not ready; native media was not loaded: $lastError',
    );
  });
}
