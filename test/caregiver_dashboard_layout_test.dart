import 'dart:convert';
import 'dart:io';
import 'package:app_mobile/models/dashboard_snapshot.dart';
import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:app_mobile/widgets/dashboard_widgets/caregiver_navigation_overview.dart';
import 'package:app_mobile/widgets/shared/gabay_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  testWidgets('live refresh keeps the navigator photo visible', (tester) async {
    final photo =
        'data:image/png;base64,${base64Encode(File('assets/branding/akay_logo.png').readAsBytesSync())}';
    Widget dashboard(String uid, String? picture, DateTime now) => MaterialApp(
      theme: GabayTheme.lightTheme,
      home: Scaffold(
        body: SingleChildScrollView(
          child: CaregiverNavigationOverview(
            data: DashboardSnapshot(uid: uid, name: 'Synthetic navigator'),
            now: now,
            picture: picture,
          ),
        ),
      ),
    );
    final now = DateTime.now();
    await tester.pumpWidget(dashboard('one', photo, now));
    final image = tester.widget<Image>(find.byType(Image));
    await tester.runAsync(
      () => precacheImage(image.image, tester.element(find.byType(Image))),
    );
    await tester.pump();
    final rendered = tester.widget<RawImage>(find.byType(RawImage)).image;
    expect(rendered, isNotNull);

    await tester.pumpWidget(
      dashboard('one', photo, now.add(const Duration(seconds: 2))),
    );
    // A live update must not introduce even one empty image frame.
    expect(
      tester.widget<RawImage>(find.byType(RawImage)).image,
      same(rendered),
    );

    await tester.pumpWidget(dashboard('two', null, now));
    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
    await tester.pumpWidget(
      dashboard('two', 'data:image/png;base64,invalid!', now),
    );
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final scenario in [
    (large: false, navigator: false),
    (large: true, navigator: false),
    (large: false, navigator: true),
    (large: true, navigator: true),
  ]) {
    final large = scenario.large, navigator = scenario.navigator;
    testWidgets(
      '${navigator ? "Navigator" : "Caregiver"} dashboard layout at ${large ? "large" : "normal"} text',
      (tester) async {
        tester.view.physicalSize = const Size(390, 950);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
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
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: CaregiverNavigationOverview(
                    showNavigatorSelector: !navigator,
                    showProfileSummary: !navigator,
                    statusHeading: navigator
                        ? 'Your current status'
                        : 'Navigator’s current status',
                    data: DashboardSnapshot(
                      uid: 'synthetic',
                      name: 'Test Navigator',
                      position: const LatLng(7, 125),
                      locationTime: DateTime.now(),
                      destination:
                          'Long synthetic destination name for layout checking',
                    ),
                    now: DateTime.now(),
                    mapBuilder: (_, peers, route) =>
                        const SizedBox(key: ValueKey('preview-map')),
                    onViewMap: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Waiting for GPS location'), findsNothing);
        expect(find.text('Navigator map'), findsOneWidget);
        expect(find.text('View map'), findsOneWidget);
        final viewButton = tester.widget<FilledButton>(
          find.ancestor(
            of: find.text('View map'),
            matching: find.byType(FilledButton),
          ),
        );
        expect(
          viewButton.style?.backgroundColor?.resolve({}),
          (large ? GabayThemeExtension.dark : GabayThemeExtension.light).accent,
        );
        expect(
          tester
              .widgetList<Text>(find.text('Unavailable'))
              .every((text) => text.maxLines == 1 && text.softWrap == false),
          isTrue,
        );
        expect(
          find.byTooltip('Select navigator'),
          navigator ? findsNothing : findsOneWidget,
        );
        if (!navigator) {
          expect(
            tester
                .widget<Text>(find.text('Test Navigator').first)
                .style
                ?.fontWeight,
            FontWeight.w400,
          );
        }
        expect(find.textContaining('Last saved destination'), findsNothing);
        expect(find.byType(DropdownButtonFormField<String>), findsNothing);
        final mapY = tester
            .getTopLeft(find.byKey(const ValueKey('preview-map')))
            .dy;
        expect(
          tester.getTopLeft(find.text('Total Distance')).dy,
          lessThan(mapY),
        );
        expect(mapY, lessThan(tester.getTopLeft(find.text('Destination')).dy));
        expect(find.text('Current heading'), findsNothing);
        expect(find.byTooltip('Expand destination'), findsOneWidget);
        await tester.ensureVisible(find.text('Destination'));
        await tester.ensureVisible(find.byTooltip('Expand destination'));
        await tester.pumpAndSettle();
        final destinationCard = find
            .ancestor(
              of: find.text('Destination'),
              matching: find.byType(GabayCard),
            )
            .first;
        final collapsedHeight = tester.getSize(destinationCard).height;
        await tester.tap(find.byTooltip('Expand destination'));
        await tester.pumpAndSettle();
        expect(
          tester.getSize(destinationCard).height,
          greaterThanOrEqualTo(collapsedHeight),
        );
        await tester.ensureVisible(find.byTooltip('Collapse destination'));
        await tester.tap(find.byTooltip('Collapse destination'));
        await tester.pumpAndSettle();
        expect(tester.getSize(destinationCard).height, collapsedHeight);
      },
    );
  }
}
