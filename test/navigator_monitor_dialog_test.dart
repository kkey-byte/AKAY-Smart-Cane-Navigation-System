import 'package:app_mobile/models/linked_navigator.dart';
import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:app_mobile/widgets/track/navigator_monitor_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'Centered monitor preserves selection and map toggle dark=$dark',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        String? selected;
        var showAll = false;
        const navigator = LinkedNavigator(
          id: 'test',
          name: 'Test Navigator',
          address: 'Location unavailable',
          location: LatLng(0, 0),
          status: 'Offline',
          batteryPercent: -1,
          isOnline: false,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? GabayTheme.darkTheme : GabayTheme.lightTheme,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => NavigatorMonitorSheet.show(
                    context,
                    navigators: const [navigator],
                    selectedId: 'test',
                    showAllOnMap: false,
                    onNavigatorSelected: (value) => selected = value.id,
                    onShowAllChanged: (value) => showAll = value,
                  ),
                  child: const Text('Choose'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Choose'));
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsOneWidget);
        final rect = tester.getRect(find.byType(NavigatorMonitorSheet));
        expect(rect.center.dy, closeTo(422, 2));
        expect(rect.left, greaterThan(0));
        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();
        expect(showAll, isTrue);
        expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
        await tester.tap(find.text('Test Navigator'));
        await tester.pumpAndSettle();
        expect(selected, 'test');
        expect(find.byType(Dialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
