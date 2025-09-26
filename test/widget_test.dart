// test/widget_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/main.dart'; // Make sure this package name matches your project

void main() {
  testWidgets('App starts smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // Note: We use InsightFolioApp instead of the old MyApp
    await tester.pumpWidget(const InsightFolioApp());

    // This is a simple test and we don't need to verify the counter.
    // We can add more specific tests later if needed.
    expect(find.text('My Portfolio'), findsNothing);
  });
}