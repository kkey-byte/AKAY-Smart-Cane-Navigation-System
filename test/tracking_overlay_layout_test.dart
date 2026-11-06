import 'package:app_mobile/models/linked_navigator.dart';
import 'package:app_mobile/models/route_plan.dart';
import 'package:app_mobile/models/route_timeline_entry.dart';
import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:app_mobile/widgets/dashboard_widgets/bottom_nav.dart';
import 'package:app_mobile/widgets/shared/floating_bottom_nav_shell.dart';
import 'package:app_mobile/widgets/track/eta_card.dart';
import 'package:app_mobile/widgets/track/floating_route_button.dart';
import 'package:app_mobile/widgets/track/map_zoom_controls.dart';
import 'package:app_mobile/widgets/track/navigator_destination_panel.dart';
import 'package:app_mobile/widgets/track/navigator_track_controls.dart';
import 'package:app_mobile/widgets/track/tracking_overlay_layout.dart';
import 'package:app_mobile/widgets/track/turn_by_turn_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  testWidgets('Collapsed panel space still lets the map receive taps', (
    tester,
  ) async {
    var mapTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: GabayTheme.lightTheme,
        home: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => mapTaps++,
                child: const ColoredBox(color: Colors.white),
              ),
              TrackingOverlayLayout(
                header: const SizedBox(height: 60),
                panel: TrackingPanel.none,
                onPanelChanged: (_) {},
                details: const SizedBox(
                  height: 200,
                  child: Text('Hidden details'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(180, 400));
    expect(mapTaps, 1);
    expect(find.text('Hidden details'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  final route = RoutePlanResult(
    navigator: const LinkedNavigator(
      id: 'synthetic',
      name: 'Test Navigator',
      address: 'Test origin',
      location: LatLng(1, 2),
      status: '',
      batteryPercent: -1,
    ),
    destination: const MapPlace(
      id: 'test',
      name: 'Test destination',
      address: 'Test destination street',
      latitude: 1.001,
      longitude: 2.001,
    ),
    estimatedTime: '20 min',
    estimatedDistance: '1.5 km',
    currentSpeed: '',
    navigationStatus: 'Navigating',
    polylinePoints: const [],
    tripStartedAt: DateTime(2026),
  );
  for (final caregiver in [false, true]) {
    for (final large in [false, true]) {
      testWidgets(
        '${caregiver ? "Caregiver" : "Navigator"} panels stay separate and fit phone large=$large',
        (tester) async {
          tester.view.physicalSize = Size(large ? 320 : 390, large ? 640 : 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final panel = ValueNotifier(
            caregiver ? TrackingPanel.details : TrackingPanel.directions,
          );
          final controller = TextEditingController();
          final focus = FocusNode();
          addTearDown(panel.dispose);
          addTearDown(controller.dispose);
          addTearDown(focus.dispose);
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
                body: FloatingBottomNavLayout(
                  navigation: BottomNav(
                    currentIndex: 1,
                    onIndexChanged: (_) {},
                  ),
                  body: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                    child: ValueListenableBuilder<TrackingPanel>(
                      valueListenable: panel,
                      builder: (context, value, _) => TrackingOverlayLayout(
                        header: NavigatorDestinationPanel(
                          controller: controller,
                          focusNode: focus,
                          suggestions: const [],
                          isNavigating: true,
                          isSearching: false,
                          activeDestinationName: 'Test destination',
                          onChanged: (_) {},
                          onSubmitted: (_) {},
                          onSearchTap: () {},
                          onSuggestionTap: (_) {},
                          onClear: () {},
                          categories: const [],
                          onCategorySelected: (_) {},
                          recentQueries: const [],
                          onRecentSelected: (_) {},
                          onSpeakPlace: (_) {},
                          onNavigatePlace: (_) {},
                          onCancelNavigation: () {},
                        ),
                        panel: value,
                        onPanelChanged: (next) => panel.value = next,
                        leadingControl: caregiver
                            ? null
                            : VoiceGuidanceButton(
                                enabled: true,
                                onPressed: () {},
                              ),
                        directions: caregiver
                            ? null
                            : TurnByTurnPanel(
                                steps: List.generate(
                                  20,
                                  (i) => TurnStep(
                                    instruction: 'Instruction $i',
                                    detail: 'Continue safely on the route.',
                                  ),
                                ),
                                onClose: () => panel.value = TrackingPanel.none,
                              ),
                        details: EtaCard(
                          route: route,
                          timelineEntries: [
                            RouteTimelineEntry(
                              address: 'Visited street',
                              timestamp: DateTime(2026),
                            ),
                          ],
                          currentLocationAddress: 'Test origin street',
                          onDragDismiss: () => panel.value = TrackingPanel.none,
                          onCancelDestination: () {},
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          void checkBounds() {
            final header = tester.getRect(
              find.byKey(const ValueKey('tracking-overlay-header')),
            );
            final toolbar = tester.getRect(
              find.byKey(const ValueKey('tracking-overlay-toolbar')),
            );
            final area = tester.getRect(
              find.byKey(const ValueKey('tracking-panel-area')),
            );
            final nav = tester.getRect(find.byType(BottomNav));
            expect(header.bottom, lessThanOrEqualTo(toolbar.top));
            expect(toolbar.bottom, lessThanOrEqualTo(area.top));
            expect(area.bottom, lessThan(nav.top));
            expect(tester.takeException(), isNull);
          }

          checkBounds();
          if (!caregiver) {
            expect(find.byType(TurnByTurnPanel), findsOneWidget);
            expect(find.byType(EtaCard), findsNothing);
            await tester.ensureVisible(find.text('Instruction 19'));
            await tester.pumpAndSettle();
            expect(find.text('Instruction 19').hitTestable(), findsOneWidget);
            await tester.tap(find.byTooltip('Show navigation details'));
            await tester.pumpAndSettle();
          }
          expect(find.byType(EtaCard), findsOneWidget);
          expect(find.byType(TurnByTurnPanel), findsNothing);
          await tester.tap(find.text('Route Timeline'));
          await tester.pumpAndSettle();
          if (!caregiver) {
            await tester.tap(find.byTooltip('Show Turn-by-Turn'));
            await tester.pumpAndSettle();
            expect(find.byType(EtaCard), findsNothing);
            await tester.tap(find.byTooltip('Show navigation details'));
            await tester.pumpAndSettle();
            expect(find.text('Visited street'), findsOneWidget);
          }
          checkBounds();
          await tester.tap(find.byTooltip('Hide navigation details'));
          await tester.pumpAndSettle();
          expect(find.byType(EtaCard), findsNothing);
          expect(find.byType(TurnByTurnPanel), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('Map buttons are compact and retain their callbacks', (
    tester,
  ) async {
    var zoomIn = 0, zoomOut = 0, planner = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: GabayTheme.lightTheme,
        home: Scaffold(
          body: Column(
            children: [
              MapZoomControls(
                onZoomIn: () => zoomIn++,
                onZoomOut: () => zoomOut++,
              ),
              FloatingRouteButton(onPressed: () => planner++),
            ],
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(MapZoomControls)), const Size(48, 96));
    expect(
      tester.getSize(find.byType(FloatingRouteButton)),
      const Size(48, 48),
    );
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.tap(find.byIcon(Icons.remove_rounded));
    await tester.tap(find.byTooltip('Route planner'));
    await tester.pumpAndSettle();
    expect([zoomIn, zoomOut, planner], [1, 1, 1]);
    expect(tester.takeException(), isNull);
  });
}
