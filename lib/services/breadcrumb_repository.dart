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
  FirebaseBreadcrumbRepository({DatabaseReference? root})
    : _providedRoot = root;
  final DatabaseReference? _providedRoot;
  DatabaseReference get _root =>
      _providedRoot ?? FirebaseDatabase.instance.ref();
  final Map<String, int> _uploadedPoints = {};
  Stream<bool> watchConnection() => _root
      .child('.info/connected')
      .onValue
      .map((event) => event.snapshot.value == true);

  @override
  Future<void> save(BreadcrumbTrip trip) async {
    final path = 'breadcrumb_trips/${trip.ownerId}/${trip.id}';
    final payload = <String, Object?>{
      'ownerId': trip.ownerId,
      'name': trip.name,
      'startedAt': trip.startedAt.millisecondsSinceEpoch,
      'endedAt': trip.endedAt?.millisecondsSinceEpoch,
      'status': trip.status,
    };
    for (var i = _uploadedPoints[path] ?? 0; i < trip.points.length; i++) {
      payload['points/${i.toString().padLeft(8, '0')}'] = trip.points[i]
          .toJson();
    }
    await _root.child(path).update(payload);
    _uploadedPoints[path] = trip.points.length;
  }

  Stream<BreadcrumbTrip?> watchTrip(String ownerId, String tripId) => SecureApi
      .instance
      .watchGet(
        '/v2/navigators/${Uri.encodeComponent(ownerId)}/trips/${Uri.encodeComponent(tripId)}',
      )
      .map((data) => BreadcrumbTrip.parse(tripId, data['trip']));

  @override
  Stream<List<BreadcrumbTrip>> watchTrips(String ownerId, {int limit = 100}) =>
      SecureApi.instance
          .watchGet(
            '/v2/navigators/${Uri.encodeComponent(ownerId)}/trips?limit=$limit',
          )
          .map((data) {
            final raw = data['trips'];
            if (raw is! Map) return <BreadcrumbTrip>[];
            return raw.entries
                .map((e) => BreadcrumbTrip.parse(e.key.toString(), e.value))
                .whereType<BreadcrumbTrip>()
                .where((t) => t.ownerId == ownerId)
                .toList()
              ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
          });

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
