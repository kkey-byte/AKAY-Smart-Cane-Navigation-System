import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:app_mobile/widgets/shared/gabay_top_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'messages appear at the bottom, replace older messages, and preserve actions',
    (tester) async {
      var actions = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: GabayTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  TextButton(
                    onPressed: () => showGabayTopMessage(
                      context,
                      const SnackBar(content: Text('First notice')),
                    ),
                    child: const Text('First'),
                  ),
                  TextButton(
                    onPressed: () => showGabayTopMessage(
                      context,
                      SnackBar(
                        content: const Text('Second notice'),
                        action: SnackBarAction(
                          label: 'Retry',
                          onPressed: () => actions++,
                        ),
                      ),
                    ),
                    child: const Text('Second'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('First'));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('First notice')).dy, greaterThan(400));
      await tester.tap(find.text('Second'));
      await tester.pumpAndSettle();
      expect(find.text('First notice'), findsNothing);
      expect(find.text('Second notice'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(actions, 1);
      expect(find.text('Second notice'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('bottom message expires and cleans up when the app view closes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showGabayTopMessage(
                context,
                const SnackBar(
                  content: Text('Temporary notice'),
                  duration: Duration(seconds: 1),
                ),
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Temporary notice'), findsNothing);
    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
}
