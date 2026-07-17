import 'package:flutter_test/flutter_test.dart';
import 'package:makanspot/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: MakanSpotApp(),
      ),
    );

    // Verify that the app title is present
    expect(find.text('MakanSpot'), findsWidgets);
  });
}
