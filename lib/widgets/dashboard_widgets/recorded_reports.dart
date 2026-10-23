import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/breadcrumb_trip.dart';
import '../../services/app_session_service.dart';
import '../../services/breadcrumb_service.dart';
import '../../theme/gabay_theme.dart';
import '../shared/gabay_card.dart';
import 'report_details_view.dart';

/// A bounded view of recorded trips, not a claim about all lifetime activity.
class RecordedReports extends StatelessWidget {
  const RecordedReports({
    super.key,
    required this.caregiver,
    this.compact = false,
  });
  final bool caregiver;
  final bool compact;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: AppSessionService.instance,
    builder: (context, _) {
      if (!AppSessionService.instance.isLoggedIn) {
        return RecordedReportContent(
          compact: compact,
          message: 'Sign in to load recorded trips.',
        );
      }
      return StreamBuilder<User?>(
        key: ValueKey(AppSessionService.instance.identityRevision),
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, auth) {
          final uid = auth.data?.uid;
          if (uid == null) {
            return RecordedReportContent(
              compact: compact,
              message: 'Waiting for authenticated account.',
            );
          }
          return _AccountReports(
            key: ValueKey('$uid:$caregiver'),
            uid: uid,
            caregiver: caregiver,
            compact: compact,
          );
        },
      );
    },
  );
}

class _AccountReports extends StatefulWidget {
  const _AccountReports({
    super.key,
    required this.uid,
    required this.caregiver,
    required this.compact,
  });
  final String uid;
  final bool caregiver, compact;
  @override
  State<_AccountReports> createState() => _AccountReportsState();
}

class _AccountReportsState extends State<_AccountReports> {
  late final Stream<Map<String, String>> _links;
  String? _owner;
  @override
  void initState() {
    super.initState();
    _links = BreadcrumbService.instance.repository.watchLinks(widget.uid);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.caregiver) {
      return _OwnerReports(
        key: ValueKey(widget.uid),
        uid: widget.uid,
        compact: widget.compact,
      );
    }
    return StreamBuilder<Map<String, String>>(
      stream: _links,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return RecordedReportContent(
            compact: widget.compact,
            message:
                'Unable to load sharing access. Reopen this page to retry.',
          );
        }
        if (!snapshot.hasData) {
          return RecordedReportContent(
            compact: widget.compact,
            message: 'Loading shared navigators...',
          );
        }
        final users = snapshot.data!;
        if (users.isEmpty) {
          return RecordedReportContent(
            compact: widget.compact,
            message:
                'No shared navigators. Manage access in Breadcrumb tracks.',
          );
        }
        final owner = users.containsKey(_owner) ? _owner! : users.keys.first;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButton<String>(
              value: owner,
              isExpanded: true,
              items: [
                for (final user in users.entries)
                  DropdownMenuItem(
                    value: user.key,
                    child: Text(
                      user.value.trim().isEmpty
                          ? 'Name unavailable'
                          : user.value,
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _owner = value),
            ),
            _OwnerReports(
              key: ValueKey(owner),
              uid: owner,
              compact: widget.compact,
            ),
          ],
        );
      },
    );
  }
}

class _OwnerReports extends StatefulWidget {
  const _OwnerReports({super.key, required this.uid, required this.compact});
  final String uid;
  final bool compact;
  @override
  State<_OwnerReports> createState() => _OwnerReportsState();
}

class _OwnerReportsState extends State<_OwnerReports> {
  late Stream<List<BreadcrumbTrip>> _trips;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _trips = BreadcrumbService.instance.repository.watchTrips(widget.uid);
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<BreadcrumbTrip>>(
    stream: _trips,
    builder: (context, snapshot) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (snapshot.connectionState == ConnectionState.waiting)
          const LinearProgressIndicator(
            semanticsLabel: 'Loading recorded trips',
          ),
        RecordedReportContent(
          compact: widget.compact,
          trips:
              snapshot.hasError ||
                  snapshot.connectionState == ConnectionState.waiting
              ? null
              : snapshot.data,
          message: snapshot.hasError
              ? 'Recorded trips unavailable. Check connection or sharing access.'
              : snapshot.connectionState == ConnectionState.waiting
              ? 'Loading recorded trips...'
              : null,
        ),
        if (snapshot.hasError)
          TextButton(
            onPressed: () => setState(_reload),
            child: const Text('Retry'),
          ),
      ],
    ),
  );
}

class RecordedReportContent extends StatelessWidget {
  const RecordedReportContent({
    super.key,
    this.trips,
    this.message,
    this.compact = false,
  });
  final List<BreadcrumbTrip>? trips;
  final String? message;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final records = trips;
    final today = DateUtils.dateOnly(DateTime.now());
    final week = today.subtract(Duration(days: today.weekday - 1));
    double meters = 0;
    for (final trip in records ?? <BreadcrumbTrip>[]) {
      for (var i = 1; i < trip.points.length; i++) {
        final a = trip.points[i - 1], b = trip.points[i];
        meters += Geolocator.distanceBetween(
          a.latitude,
          a.longitude,
          b.latitude,
          b.longitude,
        );
      }
    }
    final values = <String, String>{
      'Trips Today': records == null
          ? 'Unavailable'
          : records
                .where((t) => !t.startedAt.isBefore(today))
                .length
                .toString(),
      'This Week': records == null
          ? 'Unavailable'
          : records.where((t) => !t.startedAt.isBefore(week)).length.toString(),
      'Total Distance':
          records == null || !records.any((t) => t.points.isNotEmpty)
          ? 'Unavailable'
          : '${(meters / 1000).toStringAsFixed(2)} km recorded',
      'Total Route': records == null
          ? 'Unavailable'
          : '${records.length} recorded trips',
    };
    if (!compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message != null) ...[Text(message!), const SizedBox(height: 12)],
          ReportDetailsView(values: values, trips: records),
          const SizedBox(height: 12),
          Text(
            'Latest 100 recorded trips. GPS distance is approximate.',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message ??
              (records?.isEmpty == true
                  ? 'No recorded trips yet.'
                  : 'Latest 100 recorded trips. GPS distance is approximate.'),
        ),
        const SizedBox(height: 12),
        if (compact)
          LayoutBuilder(
            builder: (context, constraints) {
              final two =
                  constraints.maxWidth >= 300 &&
                  MediaQuery.textScalerOf(context).scale(16) <= 22;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final field in [
                    values.entries.elementAt(2),
                    values.entries.elementAt(3),
                  ])
                    SizedBox(
                      width: two
                          ? (constraints.maxWidth - 12) / 2
                          : constraints.maxWidth,
                      child: GabayCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: context.gabay.accentTint,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Icon(
                                field.key == 'Total Distance'
                                    ? Icons.location_on_outlined
                                    : Icons.route_outlined,
                                size: 20,
                                color: context.gabay.accent,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              field.value,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: context.gabay.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              field.key,
                              style: TextStyle(
                                fontSize: 10,
                                color: context.gabay.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  for (final field in values.entries.take(2))
                    Text(
                      '${field.key}: ${field.value}',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.gabay.textSecondary,
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}
