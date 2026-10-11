import 'package:flutter_test/flutter_test.dart';
import 'package:Punchhh/main.dart';

void main() {
  testWidgets('App smokes cleanly', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(true, isTrue);
  });
}
