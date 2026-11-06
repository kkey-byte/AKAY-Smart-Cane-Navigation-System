import 'package:app_mobile/pages/shared/terms_conditions_page.dart';
import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:app_mobile/widgets/shared/gabay_page_header.dart';
import 'package:app_mobile/widgets/track/navigator_destination_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Content title is centered and scrolls away with the page', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: GabayTheme.lightTheme,
        home: const TermsConditionsPage(),
      ),
    );
    await tester.pumpAndSettle();
    final title = find.text('Terms & Conditions');
    expect(tester.widget<Text>(title).style?.fontSize, 18);
    expect(tester.widget<Text>(title).style?.fontWeight, FontWeight.w600);
    expect(
      tester.getCenter(title).dx,
      closeTo(tester.getSize(find.byType(Scaffold)).width / 2, 1),
    );
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).appBar, isNull);
    expect(find.byType(GabayPageHeader), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(title.hitTestable(), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Tracking hides recent searches and preserves search input callbacks',
    (tester) async {
      final controller = TextEditingController();
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      var query = '';
      await tester.pumpWidget(
        MaterialApp(
          theme: GabayTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: NavigatorDestinationPanel(
                controller: controller,
                focusNode: focus,
                suggestions: const [],
                isNavigating: false,
                isSearching: false,
                onChanged: (value) => query = value,
                onSubmitted: (_) {},
                onSearchTap: () {},
                onSuggestionTap: (_) {},
                onClear: () {},
                categories: const [],
                onCategorySelected: (_) {},
                recentQueries: const ['Synthetic saved query'],
                onRecentSelected: (_) {},
                onSpeakPlace: (_) {},
                onNavigatePlace: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Recent searches'), findsNothing);
      expect(find.text('Synthetic saved query'), findsNothing);
      await tester.enterText(find.byType(TextField).first, 'Park');
      await tester.pump();
      expect(query, 'Park');
      expect(tester.takeException(), isNull);
    },
  );
}
