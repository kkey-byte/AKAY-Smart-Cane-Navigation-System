import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:app_mobile/widgets/shared/gabay_selection_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'field opens centered dialog, highlights selection and updates once',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? selected = 'A';
      var changes = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: GabayTheme.lightTheme,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: GabayDropdownFormField<String>(
                  key: const ValueKey('field'),
                  initialValue: selected,
                  decoration: const InputDecoration(labelText: 'Blood Type'),
                  items: const [
                    DropdownMenuItem(value: 'A', child: Text('Alpha')),
                    DropdownMenuItem(value: 'B', child: Text('Beta')),
                  ],
                  onChanged: (value) {
                    selected = value;
                    changes++;
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('field')));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      final material = find
          .descendant(of: find.byType(Dialog), matching: find.byType(Material))
          .first;
      expect(tester.getCenter(material).dy, closeTo(422, 2));
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      await tester.tap(find.text('Beta'));
      await tester.pumpAndSettle();
      expect(selected, 'B');
      expect(changes, 1);
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Beta'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('field')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close Blood Type'));
      await tester.pumpAndSettle();
      expect(selected, 'B');
      expect(changes, 1);
    },
  );

  testWidgets('centered field preserves form validation and saved values', (
    tester,
  ) async {
    final form = GlobalKey<FormState>();
    String? saved;
    await tester.pumpWidget(
      MaterialApp(
        theme: GabayTheme.lightTheme,
        home: Scaffold(
          body: Form(
            key: form,
            child: GabayDropdownFormField<String>(
              dialogTitle: 'Gender',
              items: const [
                DropdownMenuItem(value: 'Option', child: Text('Option')),
              ],
              onChanged: (_) {},
              validator: (value) => value == null ? 'Choose a value' : null,
              onSaved: (value) => saved = value,
            ),
          ),
        ),
      ),
    );
    expect(form.currentState!.validate(), isFalse);
    await tester.pumpAndSettle();
    expect(find.text('Choose a value'), findsOneWidget);
    await tester.tap(find.byType(GabayDropdownFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Option'));
    await tester.pumpAndSettle();
    expect(form.currentState!.validate(), isTrue);
    form.currentState!.save();
    expect(saved, 'Option');
  });

  testWidgets(
    'long searchable lists fit a small phone at large text in dark mode',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      int? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: GabayTheme.darkTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  selected = await showGabaySelectionDialog<int>(
                    context,
                    title: 'City',
                    searchable: true,
                    options: [
                      for (var i = 0; i < 100; i++)
                        GabaySelectionOption(
                          value: i,
                          child: Text('Choice $i'),
                          searchText: 'Choice $i',
                        ),
                    ],
                  );
                },
                child: const Text('Choose'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Choose'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Choice 99');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choice 99').last);
      await tester.pumpAndSettle();
      expect(selected, 99);
      expect(tester.takeException(), isNull);
    },
  );
}
