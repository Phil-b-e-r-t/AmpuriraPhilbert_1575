import 'package:flutter_test/flutter_test.dart';

import 'package:working_screen/main.dart';

void main() {
  testWidgets('shows the splash screen before navigating to login', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TerraMoistApp());

    expect(find.text('Smart Farming, Powered by Intelligence'), findsOneWidget);
    expect(find.text('Loading...'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('Welcome Back!'), findsOneWidget);
  });
}
