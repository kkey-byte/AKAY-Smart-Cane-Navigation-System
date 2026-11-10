import 'package:firebase_auth/firebase_auth.dart';
import 'secure_api.dart';
import 'pairing_service.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/breadcrumb_trip.dart';

abstract class BreadcrumbRepository {
  Future<void> save(BreadcrumbTrip trip);
  Stream<List<BreadcrumbTrip>> watchTrips(String ownerId, {int limit = 100});
}

class FirebaseBreadcrumbRepository implements BreadcrumbRepository {
  FirebaseBreadcrumbRepository({DatabaseReference? root, SecureApi? api})
    : _providedRoot = root,
      api = api ?? SecureApi.instance;
  final DatabaseReference? _providedRoot;
  final SecureApi api;
  DatabaseReference get _root =>
      _providedRoot ?? FirebaseDatabase.instance.ref();
  Stream<bool> watchConnection() => _root
      .child('.info/connected')
      .onValue
      .map((event) => event.snapshot.value == true);

  @override
  Future<void> save(BreadcrumbTrip trip) async {
    final path =
        '/v2/navigators/${Uri.encodeComponent(trip.ownerId)}/trips/${Uri.encodeComponent(trip.id)}';
    // Stable sequence IDs allow complete replay after an uncertain HTTP outcome.
    for (var start = 0; start < trip.points.length; start += 40) {
      final end = (start + 40).clamp(0, trip.points.length);
      final receipt = await api.request('PUT', '$path/points', {
        'name': trip.name,
        'startedAt': trip.startedAt.millisecondsSinceEpoch,
        'points': [
          for (var i = start; i < end; i++)
            {
              'sequence': i,
              'latitude': trip.points[i].latitude,
              'longitude': trip.points[i].longitude,
              'accuracyMeters': trip.points[i].accuracy,
              'sampledAt': trip.points[i].time.millisecondsSinceEpoch,
            },
        ],
      });
      if (receipt['accepted'] != true) {
        throw StateError('Point upload was not acknowledged.');
      }
    }
    final receipt = await api.request('PUT', '$path/summary', {
      'status': trip.status,
      'endedAt': trip.endedAt?.millisecondsSinceEpoch,
      'pointCount': trip.points.length,
      'lastSampledAt':
          (trip.lastSampledAt ?? trip.points.last.time).millisecondsSinceEpoch,
    });
    if (receipt['accepted'] != true) {
      throw StateError('Trip summary was not acknowledged.');
    }
  }

  Stream<BreadcrumbTrip?> watchTrip(String ownerId, String tripId) => api
      .watchGet(
        '/v2/navigators/${Uri.encodeComponent(ownerId)}/trips/${Uri.encodeComponent(tripId)}',
      )
      .map((data) {
        final trip = BreadcrumbTrip.parse(tripId, data['trip']);
        if (trip != null && trip.ownerId != ownerId) {
          throw const SecureApiException(
            'Trip identity could not be verified.',
            status: 403,
          );
        }
        return trip;
      });

  @override
  Stream<List<BreadcrumbTrip>> watchTrips(
    String ownerId, {
    int limit = 100,
  }) => api.poll(() async {
    final results = <BreadcrumbTrip>[];
    String? cursor;
    do {
      final size = (limit - results.length).clamp(1, 100);
      final data = await api.request(
        'GET',
        '/v2/navigators/${Uri.encodeComponent(ownerId)}/trips?limit=$size'
            '${cursor == null ? '' : '&cursor=${Uri.encodeComponent(cursor)}'}',
      );
      final raw = data['trips'];
      if (raw is Map) {
        results.addAll(
          raw.entries
              .map((e) => BreadcrumbTrip.parse(e.key.toString(), e.value))
              .whereType<BreadcrumbTrip>()
              .where((t) => t.ownerId == ownerId),
        );
      }
      final next = data['nextCursor'] as String?;
      if (next == cursor) break;
      cursor = next;
    } while (cursor != null && results.length < limit);
    return results..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  });

  Future<void> deleteTrip(String ownerId, String tripId) async {
    await api.request(
      'DELETE',
      '/v2/navigators/${Uri.encodeComponent(ownerId)}/trips/${Uri.encodeComponent(tripId)}',
    );
  }

  Stream<Map<String, String>> watchLinks(String caregiverId) =>
      PairingService.instance.watchConnections().map((rows) {
        if (FirebaseAuth.instance.currentUser?.uid != caregiverId) {
          throw StateError('Account changed.');
        }
        return {
          for (final c in rows)
            if (c.status == 'active' && c.caregiverUid == caregiverId)
              c.navigatorUid: c.navigatorName,
        };
      });
  Stream<Map<String, String>> watchShares(String ownerId) =>
      PairingService.instance.watchConnections().map((rows) {
        if (FirebaseAuth.instance.currentUser?.uid != ownerId) {
          throw StateError('Account changed.');
        }
        return {
          for (final c in rows)
            if (c.status == 'active' && c.navigatorUid == ownerId)
              c.caregiverUid: c.caregiverName,
        };
      });
  Future<void> revoke(String ownerId, String caregiverId) async {
    final rows = await PairingService.instance.connections();
    final c = rows
        .where(
          (c) => c.navigatorUid == ownerId && c.caregiverUid == caregiverId,
        )
        .firstOrNull;
    if (c == null) throw StateError('Connection unavailable.');
    await PairingService.instance.revoke(c.id);
  }
}
