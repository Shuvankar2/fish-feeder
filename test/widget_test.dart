import 'package:flutter_test/flutter_test.dart';

import 'package:aquaglass/main.dart';

void main() {
  testWidgets('Sanity check and login UI check', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const AquaGlassApp());

    // Verify that the login screen title or developer credit exists.
    expect(find.text("AquaGlass IoT"), findsWidgets);
    expect(find.text("Shuvankar Debnath"), findsWidgets);
  });
}
