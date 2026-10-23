import 'package:app_mobile/models/breadcrumb_trip.dart';
import 'package:app_mobile/services/breadcrumb_repository.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeTrackReference extends Fake implements DatabaseReference {
  bool offline = false;
  String? lastPath;
  final writes = <Map<String, Object?>>[];
  @override
  DatabaseReference child(String path) {
    lastPath = path;
    return this;
  }

  @override
  Future<void> update(Map<String, Object?> value) async {
    if (offline) throw StateError('Synthetic offline failure');
    writes.add(Map.of(value));
  }
}

void main() {
  test(
    'history writes keep existing database schema and only acknowledge uploaded points',
    () async {
      final root = FakeTrackReference();
      final repository = FirebaseBreadcrumbRepository(root: root);
      final time = DateTime(2026, 10, 22, 12);
      final first = BreadcrumbTrip(
        id: 'synthetic-trip',
        ownerId: 'synthetic-owner',
        name: 'Daily track',
        startedAt: time,
        points: [BreadcrumbPoint(7.3, 125.68, time, 8)],
      );
      root.offline = true;
      await expectLater(repository.save(first), throwsStateError);
      root.offline = false;
      await repository.save(first);
      expect(root.lastPath, 'breadcrumb_trips/synthetic-owner/synthetic-trip');
      expect(
        root.writes.single['points/00000000'],
        first.points.first.toJson(),
      );
      expect(root.writes.single['ownerId'], 'synthetic-owner');
      final updated = first.copyWith(
        points: [
          ...first.points,
          BreadcrumbPoint(
            7.301,
            125.68,
            time.add(const Duration(seconds: 5)),
            8,
          ),
        ],
      );
      await repository.save(updated);
      expect(root.writes.last.containsKey('points/00000000'), isFalse);
      expect(root.writes.last['points/00000001'], updated.points.last.toJson());
      await repository.save(
        updated.copyWith(
          status: 'completed',
          endedAt: time.add(const Duration(minutes: 1)),
        ),
      );
      expect(root.writes.last['status'], 'completed');
      expect(
        root.writes.last.keys.where((key) => key.startsWith('points/')),
        isEmpty,
      );
      // After restart, deterministic point keys safely overwrite rather than duplicate.
      await FirebaseBreadcrumbRepository(root: root).save(updated);
      expect(
        root.writes.last.keys.where((key) => key.startsWith('points/')),
        hasLength(2),
      );
    },
  );
}
