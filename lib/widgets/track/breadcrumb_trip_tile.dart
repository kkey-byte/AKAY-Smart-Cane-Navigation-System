import 'package:flutter/material.dart';
import '../../models/breadcrumb_trip.dart';

String breadcrumbStatus(
  BreadcrumbTrip trip,
  DateTime now, {
  bool connected = true,
}) => trip.isRecording
    ? !connected
          ? 'Offline · Last known track'
          : trip.isFresh(now)
          ? 'Live · Recording'
          : 'No recent GPS update'
    : trip.status == 'completed'
    ? 'Saved'
    : 'Interrupted · Saved points retained';

class BreadcrumbTripTile extends StatelessWidget {
  const BreadcrumbTripTile({
    super.key,
    required this.trip,
    required this.now,
    required this.connected,
    required this.onTap,
  });
  final BreadcrumbTrip trip;
  final DateTime now;
  final bool connected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(
        connected && trip.isFresh(now) ? Icons.location_on : Icons.route,
      ),
      title: Text(trip.name),
      subtitle: Text(
        '${trip.startedAt.toLocal().toString().substring(0, 16)}\n'
        '${breadcrumbStatus(trip, now, connected: connected)} · ${trip.points.length} points',
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}
