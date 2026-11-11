import 'package:app_mobile/models/breadcrumb_trip.dart';
import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:app_mobile/widgets/dashboard_widgets/activity_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime(2026, 11, 11, 10);
BreadcrumbTrip trip(int day, {String status = 'completed'}) => BreadcrumbTrip(
  id: '$day',
  ownerId: 'navigator',
  name: 'Recorded walk',
  startedAt: DateTime(2026, 11, day, 9),
  endedAt: status == 'recording' ? null : DateTime(2026, 11, day, 9, 12),
  status: status,
  points: const [],
  recordedDistanceMeters: 850,
  recordedDurationSeconds: 720,
);

Future<void> showActivity(WidgetTester tester, RecentActivityContent content) =>
    tester.pumpWidget(
      MaterialApp(
        theme: GabayTheme.lightTheme,
        home: Scaffold(body: SingleChildScrollView(child: content)),
      ),
    );

void main() {
  testWidgets(
    'five activities are visible and older activities scroll inside the card',
    (tester) async {
      await showActivity(
        tester,
        RecentActivityContent(
          now: now,
          trips: [for (var day = 5; day <= 11; day++) trip(day)],
        ),
      );
      final cards = tester
          .widgetList<ActivityCard>(find.byType(ActivityCard))
          .toList();
      expect(cards, hasLength(5));
      expect(cards.first.title, 'Walk recorded');
      expect(cards.first.time, '0.85 km · 12 min · Today • 9:12 AM');
      expect(cards[1].time, contains('Yesterday • 9:12 AM'));
      expect(cards.last.time, contains('11/7/2026'));
      expect(cards.last.showDivider, isTrue);
      final activityScroll = find.byKey(
        const ValueKey('recent-activity-scroll'),
      );
      expect(activityScroll, findsOneWidget);
      await tester.drag(activityScroll, const Offset(0, -240));
      await tester.pumpAndSettle();
      final older = tester.widgetList<ActivityCard>(find.byType(ActivityCard));
      expect(older.last.time, contains('11/5/2026'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'caregiver activity includes navigator and truthful recording states',
    (tester) async {
      await showActivity(
        tester,
        RecentActivityContent(
          now: now,
          navigatorName: 'Test Navigator',
          trips: [
            trip(10, status: 'interrupted'),
            trip(11, status: 'recording'),
          ],
        ),
      );
      final cards = tester
          .widgetList<ActivityCard>(find.byType(ActivityCard))
          .toList();
      expect(cards.first.title, 'Test Navigator · Walk recording started');
      expect(cards.first.time, 'Today • 9:00 AM');
      expect(cards.last.title, 'Test Navigator · Walk recording interrupted');
      expect(find.textContaining('arrived'), findsNothing);
    },
  );

  testWidgets(
    'missing or failed history clears previously displayed activity',
    (tester) async {
      await showActivity(tester, RecentActivityContent(trips: [trip(11)]));
      expect(find.byType(ActivityCard), findsOneWidget);
      await showActivity(tester, const RecentActivityContent(trips: null));
      expect(find.byType(ActivityCard), findsNothing);
      expect(find.textContaining('Activity feed unavailable'), findsOneWidget);
      await showActivity(tester, const RecentActivityContent(trips: []));
      expect(find.text('No recorded activity yet.'), findsOneWidget);
    },
  );
}
