import '../../theme/gabay_typography.dart';
import '../shared/gabay_accent_icon.dart';
import '../shared/gabay_card.dart';
import '../shared/gabay_dashboard_backdrop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/breadcrumb_trip.dart';
import '../../services/app_session_service.dart';
import '../../services/breadcrumb_service.dart';

import '../../theme/gabay_theme.dart';

class ActivityCard extends StatelessWidget {
  final Color color;

  final IconData icon;

  final String title;

  final String time;

  final bool showDivider;

  const ActivityCard({
    super.key,

    required this.color,

    required this.icon,

    required this.title,

    required this.time,

    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),

          child: Row(
            children: [
              Container(
                width: 34,

                height: 34,

                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),

                  borderRadius: BorderRadius.circular(11),
                ),

                child: GabayAccentIcon(icon, color: color, size: 21),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,

                      style: TextStyle(
                        fontWeight: GabayTypography.medium,

                        fontSize: GabayTypography.supporting,

                        color: g.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      time,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,

                      style: TextStyle(
                        color: g.textSecondary,

                        fontSize: GabayTypography.supporting,

                        fontWeight: GabayTypography.medium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (showDivider) Divider(height: 1, color: g.border),
      ],
    );
  }
}

class RecentActivityList extends StatelessWidget {
  const RecentActivityList({
    super.key,
    this.caregiver = false,
    this.ownerId,
    this.navigatorName,
  });
  final bool caregiver;
  final String? ownerId, navigatorName;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: AppSessionService.instance,
    builder: (context, _) {
      if (!AppSessionService.instance.isLoggedIn) {
        return const _ActivityMessage('Sign in to load recent activity.');
      }
      return StreamBuilder<User?>(
        key: ValueKey(AppSessionService.instance.identityRevision),
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, auth) {
          final uid = auth.data?.uid;
          if (uid == null) {
            return const _ActivityMessage('Waiting for authenticated account.');
          }
          final owner = caregiver ? ownerId : uid;
          if (owner == null) {
            return const _ActivityMessage(
              'Select a linked navigator to view recent activity.',
            );
          }
          return _OwnerActivity(
            key: ValueKey('$uid:$owner'),
            ownerId: owner,
            navigatorName: caregiver ? navigatorName : null,
          );
        },
      );
    },
  );
}

class _OwnerActivity extends StatefulWidget {
  const _OwnerActivity({super.key, required this.ownerId, this.navigatorName});
  final String ownerId;
  final String? navigatorName;
  @override
  State<_OwnerActivity> createState() => _OwnerActivityState();
}

class _OwnerActivityState extends State<_OwnerActivity> {
  late final Stream<List<BreadcrumbTrip>> _trips;
  @override
  void initState() {
    super.initState();
    _trips = BreadcrumbService.instance.repository.watchTrips(widget.ownerId);
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<BreadcrumbTrip>>(
    stream: _trips,
    builder: (context, snapshot) => RecentActivityContent(
      trips:
          snapshot.hasError ||
              snapshot.connectionState == ConnectionState.waiting
          ? null
          : snapshot.data
                ?.where((trip) => trip.ownerId == widget.ownerId)
                .toList(),
      navigatorName: widget.navigatorName,
      message: snapshot.hasError
          ? 'Activity feed unavailable. View recorded trips in Reports.'
          : 'Loading recent activity…',
    ),
  );
}

class RecentActivityContent extends StatelessWidget {
  const RecentActivityContent({
    super.key,
    required this.trips,
    this.navigatorName,
    this.message = 'Activity feed unavailable. View recorded trips in Reports.',
    this.now,
  });
  final List<BreadcrumbTrip>? trips;
  final String? navigatorName;
  final String message;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    if (trips == null) return _ActivityMessage(message);
    if (trips!.isEmpty) {
      return const _ActivityMessage('No recorded activity yet.');
    }
    final recent = trips!.toList()
      ..sort((a, b) => _eventTime(b).compareTo(_eventTime(a)));
    final entries = recent;
    Widget activity(int i) => ActivityCard(
      color: context.gabay.accent,
      icon: switch (entries[i].status) {
        'completed' => Icons.check_circle_outline,
        'recording' => Icons.directions_walk_rounded,
        _ => Icons.pause_circle_outline,
      },
      title: _title(entries[i]),
      time: _details(entries[i], now ?? DateTime.now()),
      showDivider: i < entries.length - 1,
    );
    final rowHeight =
        80.0 *
        (MediaQuery.textScalerOf(context).scale(13) / 13).clamp(
          1.0,
          double.infinity,
        );
    return GabayCard(
      padding: const EdgeInsets.all(16),
      child: entries.length > 5
          ? SizedBox(
              height: rowHeight * 5,
              child: ListView.builder(
                key: const ValueKey('recent-activity-scroll'),
                primary: false,
                padding: EdgeInsets.zero,
                itemExtent: rowHeight,
                itemCount: entries.length,
                scrollCacheExtent: const ScrollCacheExtent.pixels(0),
                itemBuilder: (_, i) => activity(i),
              ),
            )
          : Column(
              children: [for (var i = 0; i < entries.length; i++) activity(i)],
            ),
    );
  }

  static DateTime _eventTime(BreadcrumbTrip trip) =>
      trip.isRecording ? trip.startedAt : trip.endedAt ?? trip.startedAt;

  String _title(BreadcrumbTrip trip) {
    final status = switch (trip.status) {
      'completed' => 'Walk recorded',
      'recording' => 'Walk recording started',
      _ => 'Walk recording interrupted',
    };
    final name = navigatorName?.trim();
    return name == null || name.isEmpty ? status : '$name · $status';
  }

  String _details(BreadcrumbTrip trip, DateTime now) {
    final time = _eventTime(trip).toLocal();
    final today = DateUtils.dateOnly(now.toLocal());
    final day = DateUtils.dateOnly(time);
    final date = day == today
        ? 'Today'
        : day == DateTime(today.year, today.month, today.day - 1)
        ? 'Yesterday'
        : '${time.month}/${time.day}/${time.year}';
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final clock =
        '$hour:${time.minute.toString().padLeft(2, '0')} ${time.hour < 12 ? 'AM' : 'PM'}';
    final parts = <String>[];
    if (!trip.isRecording) {
      if (trip.hasRecordedDistance) {
        parts.add('${(trip.distanceMeters / 1000).toStringAsFixed(2)} km');
      }
      final duration = trip.walkingDuration;
      if (duration != null) {
        parts.add(
          duration.inHours > 0
              ? '${duration.inHours} hr ${duration.inMinutes.remainder(60)} min'
              : duration.inMinutes > 0
              ? '${duration.inMinutes} min'
              : '${duration.inSeconds} sec',
        );
      }
    }
    return [...parts, '$date • $clock'].join(' · ');
  }
}

class _ActivityMessage extends StatelessWidget {
  const _ActivityMessage(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => GabayCard(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.gabay.accentTint,
            borderRadius: BorderRadius.circular(11),
          ),
          child: GabayAccentIcon(
            Icons.info_outline,
            color: context.gabay.accent,
            size: 21,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              fontSize: GabayTypography.supporting,
              color: GabayDashboardBackdrop.active(context)
                  ? GabayDashboardBackdrop.secondaryColor(context)
                  : context.gabay.textSecondary,
            ),
          ),
        ),
      ],
    ),
  );
}
