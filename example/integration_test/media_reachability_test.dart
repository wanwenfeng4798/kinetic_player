import 'dart:io';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:kinetic_player/kinetic_player.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('media URL reachability on device', (tester) async {
    final urls = <String>[
      'https://raw.githubusercontent.com/wanwenfeng4798/SGPlayer/v2.0.0/tests/fixtures/orientation.mp4',
      'https://raw.githubusercontent.com/wanwenfeng4798/SGPlayer/v2.0.0/demo/demo-assset/i-see-fire.mp4',
      'https://raw.githubusercontent.com/wanwenfeng4798/SGPlayer/v2.0.0/demo/demo-assset/google-help-vr.mp4',
      'https://www.apple.com/library/test/success.html',
      'https://www.baidu.com/',
    ];
    CommonVideoController? player;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 320,
          height: 180,
          child: CommonVideoPlayerViewBuilder(
            builder: (value) => player = value,
          ),
        ),
      ),
    );
    for (var i = 0; i < 50 && player == null; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    if (player is SGVideoControllerImpl) {
      debugPrint(
        'KINETIC_NETWORK_PATH ${await (player as SGVideoControllerImpl).getNetworkDiagnostics()}',
      );
    }
    var reachable = 0;
    for (var offset = 0; offset < urls.length; offset += 4) {
      await Future.wait(
        urls.skip(offset).take(4).map((url) async {
          final client = HttpClient();
          try {
            final request = await client
                .getUrl(Uri.parse(url))
                .timeout(const Duration(seconds: 8));
            request.headers.set('Range', 'bytes=0-1023');
            final response = await request.close().timeout(
              const Duration(seconds: 8),
            );
            final first = await response.first.timeout(
              const Duration(seconds: 8),
            );
            if ((response.statusCode == 200 || response.statusCode == 206) &&
                url.endsWith('.mp4')) {
              reachable++;
            }
            debugPrint(
              'KINETIC_PROBE ${jsonEncode({'url': url, 'status': response.statusCode, 'mime': response.headers.contentType.toString(), 'prefix': first.take(12).toList()})}',
            );
          } catch (error) {
            debugPrint(
              'KINETIC_PROBE ${jsonEncode({'url': url, 'error': error.toString()})}',
            );
          } finally {
            client.close(force: true);
          }
        }),
      );
    }
    expect(
      reachable,
      greaterThan(0),
      reason: 'No SGPlayer media endpoints reachable from this app',
    );
  }, skip: !const bool.fromEnvironment('KINETIC_TEST_NETWORK_PROBE'));
}
