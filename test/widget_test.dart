import 'package:flutter_test/flutter_test.dart';

import 'package:birthday_app/main.dart';

void main() {
  testWidgets('Happaroo shows its loading state', (WidgetTester tester) async {
    await tester.pumpWidget(const HapparooApp());

    expect(find.text('Loading events...'), findsOneWidget);
  });
}
