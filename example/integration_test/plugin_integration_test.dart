import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kinetic_player/kinetic_player.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('plugin exports core types', (tester) async {
    expect(CommonPlayerState.values.length, 7);
    expect(CommonScaleMode.values.length, 3);
  });
}
