import 'package:app_mobile/models/linked_navigator.dart';
import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:app_mobile/widgets/track/route_search_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('route search stays readable and searchable dark=$dark', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = TextEditingController();
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      var searches = 0;
      const navigator = LinkedNavigator(
        id: 'synthetic',
        name: 'Navigator',
        address: 'Synthetic Street',
        location: LatLng(0, 0),
        status: 'Online',
        batteryPercent: 50,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? GabayTheme.darkTheme : GabayTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: RouteSearchCard(
                navigators: const [navigator],
                selectedNavigator: navigator,
                onNavigatorChanged: (_) {},
                destinationController: controller,
                destinationFocusNode: focus,
                onSwap: () {},
                suggestions: const [],
                onSuggestionSelected: (_) {},
                showNavigatorPicker: false,
                originAddress: 'Synthetic Street',
                onSearch: () => searches++,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Synthetic Street'), findsOneWidget);
      expect(find.text('Destination'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Search destinations'));
      await tester.tap(find.byTooltip('Search destinations'));
      expect(searches, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
