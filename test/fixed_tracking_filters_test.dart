import 'package:app_mobile/models/route_plan.dart';
import 'package:app_mobile/models/search_destination.dart';
import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:app_mobile/widgets/track/navigator_destination_panel.dart';
import 'package:app_mobile/widgets/track/tracking_overlay_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final large in [false, true]) {
    testWidgets(
      'Result list scrolls while search and filters stay fixed large=$large',
      (tester) async {
        tester.view.physicalSize = Size(large ? 320 : 390, large ? 640 : 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = TextEditingController(), focus = FocusNode();
        String? selected;
        final places = List.generate(
          8,
          (i) => MapPlace(
            id: '$i',
            name: 'Test place $i',
            address: 'Test street',
            latitude: 1,
            longitude: 2,
            category: 'Restaurant',
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: large ? GabayTheme.darkTheme : GabayTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(large ? 2 : 1)),
              child: child!,
            ),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                child: TrackingOverlayLayout(
                  headerScrollable: false,
                  reservedBottomHeight: 168,
                  header: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        fit: FlexFit.loose,
                        child: NavigatorDestinationPanel(
                          controller: controller,
                          focusNode: focus,
                          suggestions: places,
                          isNavigating: false,
                          isSearching: false,
                          constrainResults: true,
                          onChanged: (_) {},
                          onSubmitted: (_) {},
                          onSearchTap: () {},
                          onSuggestionTap: (place) => selected = place.id,
                          onClear: () {},
                          categories: SearchCategory.all,
                          onCategorySelected: (_) {},
                          recentQueries: const [],
                          onRecentSelected: (_) {},
                          onSpeakPlace: (_) {},
                          onNavigatePlace: (_) {},
                        ),
                      ),
                      const SizedBox(height: 48),
                    ],
                  ),
                  panel: TrackingPanel.none,
                  onPanelChanged: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final filterPosition = tester.getTopLeft(find.text('Hospital'));
        final searchPosition = tester.getTopLeft(find.byType(TextField));
        final list = find.byWidgetPredicate(
          (widget) =>
              widget is ListView && widget.scrollDirection == Axis.vertical,
        );
        await tester.drag(list, const Offset(0, -350));
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(find.text('Hospital')), filterPosition);
        expect(tester.getTopLeft(find.byType(TextField)), searchPosition);
        await tester.scrollUntilVisible(
          find.text('Test place 7'),
          180,
          scrollable: find
              .descendant(of: list, matching: find.byType(Scrollable))
              .first,
        );
        await tester.tap(find.text('Test place 7'));
        expect(selected, '7');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
        focus.dispose();
      },
    );
  }
}
