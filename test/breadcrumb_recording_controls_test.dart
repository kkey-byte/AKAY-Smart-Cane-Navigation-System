import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:app_mobile/widgets/track/breadcrumb_recording_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('waiting can be paused without a route or first GPS point', (
    tester,
  ) async {
    var pauses = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: GabayTheme.lightTheme,
        home: Scaffold(
          body: BreadcrumbRecordingControls(
            requested: true,
            recording: false,
            busy: true,
            waitingReason: 'Location accuracy must be 50 metres or better.',
            pendingCount: 0,
            syncing: false,
            hasTrips: false,
            onStart: () => fail('Waiting must remain cancellable'),
            onPause: () => pauses++,
            onSync: () {},
          ),
        ),
      ),
    );
    expect(find.text('Waiting for an accurate location'), findsOneWidget);
    await tester.tap(find.text('Pause sharing and save track'));
    expect(pauses, 1);
    expect(find.text('All recorded updates uploaded'), findsNothing);
  });

  testWidgets(
    'offline pending and acknowledged states remain readable in both themes',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final theme in [GabayTheme.lightTheme, GabayTheme.darkTheme]) {
        for (final pending in [2, 0]) {
          var retries = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: Scaffold(
                  body: ListView(
                    children: [
                      BreadcrumbRecordingControls(
                        requested: false,
                        recording: false,
                        pendingCount: pending,
                        syncing: false,
                        hasTrips: true,
                        onStart: () {},
                        onPause: () {},
                        onSync: () => retries++,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull);
          expect(find.text('Recording paused'), findsOneWidget);
          if (pending > 0) {
            expect(find.text('All recorded updates uploaded'), findsNothing);
            await tester.tap(find.text('Saved on device · Sync now'));
            expect(retries, 1);
          } else {
            expect(find.text('All recorded updates uploaded'), findsOneWidget);
          }
        }
      }
    },
  );

  testWidgets('a storage failure never claims a successful upload', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: GabayTheme.lightTheme,
        home: Scaffold(
          body: BreadcrumbRecordingControls(
            requested: true,
            recording: true,
            pendingCount: 1,
            syncing: false,
            hasTrips: true,
            storageError: 'Unable to save tracks on this device.',
            onStart: () {},
            onPause: () {},
            onSync: () {},
          ),
        ),
      ),
    );
    expect(find.text('Device storage needs attention'), findsOneWidget);
    expect(
      find.text('Uploads wait until device storage recovers.'),
      findsOneWidget,
    );
    expect(find.text('All recorded updates uploaded'), findsNothing);
  });
}
