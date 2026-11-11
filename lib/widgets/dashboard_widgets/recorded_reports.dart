import '../../theme/gabay_typography.dart';
import '../shared/gabay_accent_icon.dart';
import 'dart:convert';
import 'dart:async';
import '../../models/pairing.dart';
import '../../services/pairing_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/breadcrumb_trip.dart';
import '../../services/app_session_service.dart';
import '../../services/breadcrumb_service.dart';
import '../../theme/gabay_theme.dart';
import '../shared/gabay_card.dart';
import 'report_details_view.dart';
import '../shared/navigator_selection_modal.dart';

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

class _ReportAvatar extends StatelessWidget {
  const _ReportAvatar({this.picture});
  final String? picture;
  @override
  Widget build(BuildContext context) {
    final g = context.gabay;
    final fallback = ColoredBox(
      color: g.accentTint,
      child: Center(
        child: Icon(Icons.person_outline_rounded, color: g.accent, size: 24),
      ),
    );
    Widget photo = fallback;
    try {
      if (picture?.startsWith('data:image/') == true) {
        photo = Image.memory(
          base64Decode(picture!.split(',').last),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
        );
      } else if (Uri.tryParse(picture ?? '')?.scheme == 'https') {
        photo = Image.network(
          picture!,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
        );
      }
    } catch (_) {
      photo = fallback;
    }
    return ClipOval(child: SizedBox.square(dimension: 44, child: photo));
  }
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
  late final Stream<List<PairingConnection>>? _photos;
  String? _owner;
  @override
  void initState() {
    super.initState();
    _links = BreadcrumbService.instance.repository.watchLinks(widget.uid);
    _photos = widget.caregiver
        ? PairingService.instance.watchConnections()
        : null;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.caregiver) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.compact) ...[
            GabayCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _ReportAvatar(
                    picture: AppSessionService.instance.profilePicture,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppSessionService.instance.displayName ?? 'Navigator',
                      style: TextStyle(
                        color: context.gabay.textPrimary,
                        fontSize: GabayTypography.cardBody,
                        fontWeight: GabayTypography.medium,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          _OwnerReports(
            key: ValueKey(widget.uid),
            uid: widget.uid,
            compact: widget.compact,
            localOwner: true,
          ),
        ],
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
            message: 'No shared navigators. Manage connections in Profile.',
          );
        }
        final owner = users.containsKey(_owner) ? _owner! : users.keys.first;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GabayCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              onTap: () async {
                final selected = await showNavigatorSelectionModal(
                  context,
                  navigatorOptions: [
                    for (final user in users.entries)
                      (
                        uid: user.key,
                        name: user.value.trim().isEmpty
                            ? 'Name unavailable'
                            : user.value,
                      ),
                  ],
                  selectedUid: owner,
                );
                if (selected != null && mounted) {
                  setState(() => _owner = selected);
                }
              },
              semanticLabel: 'Select navigator for reports',
              child: Row(
                children: [
                  StreamBuilder<List<PairingConnection>>(
                    stream: _photos,
                    builder: (context, snapshot) {
                      final matches =
                          (snapshot.data ?? const <PairingConnection>[]).where(
                            (row) =>
                                row.navigatorUid == owner &&
                                row.status == 'active',
                          );
                      return _ReportAvatar(
                        picture: matches.firstOrNull?.navigatorPicture,
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          users[owner]?.trim().isNotEmpty == true
                              ? users[owner]!
                              : 'Name unavailable',
                          style: TextStyle(
                            color: context.gabay.textPrimary,
                            fontSize: GabayTypography.cardBody,
                            fontWeight: GabayTypography.regular,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Navigator',
                          style: TextStyle(
                            color: context.gabay.textSecondary,
                            fontSize: GabayTypography.caption,
                            fontWeight: GabayTypography.regular,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GabayAccentIcon(
                    Icons.keyboard_arrow_down_rounded,
                    color: context.gabay.textSecondary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
  const _OwnerReports({
    super.key,
    required this.uid,
    required this.compact,
    this.localOwner = false,
  });
  final String uid;
  final bool compact;
  final bool localOwner;
  @override
  State<_OwnerReports> createState() => _OwnerReportsState();
}

class _OwnerReportsState extends State<_OwnerReports> {
  late Stream<List<BreadcrumbTrip>> _trips;
  int _limit = 100;
  @override
  void initState() {
    super.initState();
    if (widget.localOwner) {
      BreadcrumbService.instance.addListener(_localTracksChanged);
    }
    _reload();
  }

  void _localTracksChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    if (widget.localOwner) {
      BreadcrumbService.instance.removeListener(_localTracksChanged);
    }
    super.dispose();
  }

  void _reload() {
    _trips = BreadcrumbService.instance.repository.watchTrips(
      widget.uid,
      limit: _limit,
    );
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<BreadcrumbTrip>>(
    stream: _trips,
    builder: (context, snapshot) {
      final remote =
          snapshot.hasError ||
              snapshot.connectionState == ConnectionState.waiting
          ? null
          : snapshot.data;
      final breadcrumbs = BreadcrumbService.instance;
      final records = widget.localOwner
          ? mergeNavigatorReportTrips(
              ownerId: widget.uid,
              remote: remote,
              local: breadcrumbs.recorder?.ownerId == widget.uid
                  ? breadcrumbs.trips
                  : const [],
            )
          : remote;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (snapshot.connectionState == ConnectionState.waiting)
            const LinearProgressIndicator(
              semanticsLabel: 'Loading recorded trips',
            ),
          RecordedReportContent(
            compact: widget.compact,
            localOwner: widget.localOwner,
            trips: remote,
            recentTrips: widget.localOwner ? records : null,
            message: snapshot.hasError
                ? null
                : snapshot.connectionState == ConnectionState.waiting
                ? 'Loading trip history…'
                : null,
          ),
          if (!widget.compact && (snapshot.data?.length ?? 0) >= _limit)
            TextButton(
              onPressed: () => setState(() {
                _limit += 100;
                _reload();
              }),
              child: const Text('Load older tracks'),
            ),
        ],
      );
    },
  );
}

/// Same owner-local overlay used by breadcrumb history, including unsynced tracks.
List<BreadcrumbTrip>? mergeNavigatorReportTrips({
  required String ownerId,
  required List<BreadcrumbTrip>? remote,
  required List<BreadcrumbTrip> local,
}) {
  final records = <String, BreadcrumbTrip>{
    for (final trip in remote ?? <BreadcrumbTrip>[])
      if (trip.ownerId == ownerId) trip.id: trip,
  };
  for (final trip in local) {
    if (trip.ownerId == ownerId) records[trip.id] = trip;
  }
  if (remote == null && records.isEmpty) return null;
  return records.values.toList()
    ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
}

class RecordedReportContent extends StatefulWidget {
  const RecordedReportContent({
    super.key,
    this.trips,
    this.recentTrips,
    this.message,
    this.compact = false,
    this.localOwner = false,
    this.clock,
  });
  final List<BreadcrumbTrip>? trips;
  final List<BreadcrumbTrip>? recentTrips;
  final String? message;
  final bool compact;
  final bool localOwner;
  final DateTime Function()? clock;
  @override
  State<RecordedReportContent> createState() => _RecordedReportContentState();
}

class _RecordedReportContentState extends State<RecordedReportContent>
    with WidgetsBindingObserver {
  Timer? _dayRollover;
  DateTime get _now => (widget.clock ?? DateTime.now)().toLocal();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleRollover();
  }

  void _scheduleRollover() {
    _dayRollover?.cancel();
    final now = _now;
    final midnight = DateTime(now.year, now.month, now.day + 1);
    _dayRollover = Timer(midnight.difference(now), () {
      if (!mounted) return;
      setState(() {});
      _scheduleRollover();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
      _scheduleRollover();
    }
  }

  @override
  void dispose() {
    _dayRollover?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final records = widget.trips;
    final recentTrips = widget.recentTrips;
    final message = widget.message;
    final compact = widget.compact;
    final localOwner = widget.localOwner;
    final now = _now;
    final today = DateUtils.dateOnly(now);
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    final dailyTrips = records?.where((trip) {
      final start = trip.startedAt.toLocal();
      return !start.isBefore(today) &&
          start.isBefore(tomorrow) &&
          !start.isAfter(now);
    }).toList();
    final week = today.subtract(Duration(days: today.weekday - 1));
    double meters = 0;
    Duration? walkingDuration;
    for (final trip in records ?? <BreadcrumbTrip>[]) {
      meters += trip.distanceMeters;
    }
    for (final trip in dailyTrips ?? <BreadcrumbTrip>[]) {
      final duration = trip.walkingDuration;
      if (duration != null) {
        walkingDuration = (walkingDuration ?? Duration.zero) + duration;
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
          records == null || !records.any((t) => t.hasRecordedDistance)
          ? 'Unavailable'
          : '${(meters / 1000).toStringAsFixed(2)} km recorded',
      'Total Route': records == null
          ? 'Unavailable'
          : '${records.length} recorded trips',
      'Walking Duration':
          dailyTrips == null ||
              (dailyTrips.isNotEmpty && walkingDuration == null)
          ? 'Unavailable'
          : _formatWalkingDuration(walkingDuration ?? Duration.zero),
    };
    if (!compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message != null) ...[Text(message), const SizedBox(height: 12)],
          ReportDetailsView(
            values: values,
            trips: records,
            recentTrips: recentTrips,
            localOwner: localOwner,
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
                              child: GabayAccentIcon(
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
                                fontSize: GabayTypography.pageTitle,
                                fontWeight: GabayTypography.medium,
                                color: context.gabay.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              field.key,
                              style: TextStyle(
                                fontSize: GabayTypography.chartLabel,
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
                        fontSize: GabayTypography.caption,
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

String _formatWalkingDuration(Duration duration) {
  if (duration.inHours > 0) {
    return '${duration.inHours} hr ${duration.inMinutes.remainder(60)} min';
  }
  if (duration.inMinutes > 0) return '${duration.inMinutes} min';
  return '${duration.inSeconds} sec';
}
