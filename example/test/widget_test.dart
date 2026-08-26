import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_player_example/main.dart';

void main() {
  testWidgets('demo app renders', (WidgetTester tester) async {
    await tester.pumpWidget(const KineticPlayerExampleApp());
    expect(find.text('Kinetic Player Demo'), findsOneWidget);
  });
}
