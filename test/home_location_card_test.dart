import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:app_mobile/widgets/dashboard_widgets/location_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Home switches active map and restores unavailable location', (
    tester,
  ) async {
    var starts = 0;
    var views = 0;
    Widget page(bool navigating) => MaterialApp(
      theme: GabayTheme.lightTheme,
      home: Scaffold(
        body: LocationCard(
          isNavigating: navigating,
          activeMap: const ColoredBox(
            key: ValueKey('active-map'),
            color: Colors.blue,
          ),
          onStartNavigationPressed: () => starts++,
          onViewMapPressed: () => views++,
        ),
      ),
    );
    await tester.pumpWidget(page(false));
    expect(find.byKey(const ValueKey('active-map')), findsNothing);
    expect(find.byType(Image), findsNothing);
    expect(find.text('Location unavailable'), findsWidgets);
    await tester.tap(find.text('Start Navigation'));
    expect(starts, 1);
    await tester.pumpWidget(page(true));
    expect(find.byKey(const ValueKey('active-map')), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    await tester.tap(find.text('View Map'));
    expect(views, 1);
    await tester.pumpWidget(page(false));
    expect(find.byKey(const ValueKey('active-map')), findsNothing);
    expect(find.byType(Image), findsNothing);
    expect(find.text('Location unavailable'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
