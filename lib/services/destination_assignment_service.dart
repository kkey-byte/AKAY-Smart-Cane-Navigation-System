import '../models/route_plan.dart';
import 'secure_api.dart';
import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_session_service.dart';

class DestinationAssignmentService {
  DestinationAssignmentService({
    SecureApi? api,
    String? Function()? currentUid,
    int Function()? revision,
    Future<SharedPreferences> Function()? preferences,
  }) : api = api ?? SecureApi.instance,
       _currentUid =
           currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid),
       _revision =
           revision ?? (() => AppSessionService.instance.identityRevision),
       _preferences = preferences ?? SharedPreferences.getInstance;
  static final instance = DestinationAssignmentService();
  final SecureApi api;
  final String? Function() _currentUid;
  final int Function() _revision;
  final Future<SharedPreferences> Function() _preferences;
  Future<void> _disk = Future.value();
  final Map<String, Future<void>> _flushes = {};

  String _key(String uid) => 'akay_cancelled_destinations_$uid';
  Map<String, dynamic> _decode(String? raw) {
    if (raw == null) {
      return {'cancelled': <dynamic>[], 'pending': <String, dynamic>{}};
    }
    final value = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    if (value['cancelled'] is! List || value['pending'] is! Map) {
      throw StateError('Saved cancellation data could not be read.');
    }
    return value;
  }

  Future<Map<String, dynamic>> _read(String uid) async {
    await _disk;
    return _decode((await _preferences()).getString(_key(uid)));
  }

  Future<void> _update(String uid, void Function(Map<String, dynamic>) change) {
    final write = _disk.then((_) async {
      final preferences = await _preferences();
      final state = _decode(preferences.getString(_key(uid)));
      change(state);
      if (!await preferences.setString(_key(uid), jsonEncode(state))) {
        throw StateError(
          'Cancellation could not be saved on this device. Please retry.',
        );
      }
    });
    _disk = write.catchError((Object _) {});
    return write;
  }

  Future<bool> isCancelled(String id) async {
    final uid = _currentUid();
    if (uid == null) return false;
    final revision = _revision();
    final state = await _read(uid);
    return uid == _currentUid() &&
        revision == _revision() &&
        (state['cancelled'] as List).contains(id);
  }

  Future<void> flushCancellations() {
    final uid = _currentUid();
    if (uid == null) return Future.value();
    final active = _flushes[uid];
    if (active != null) return active;
    final revision = _revision();
    late Future<void> operation;
    operation = _flush(uid, revision).whenComplete(() {
      if (identical(_flushes[uid], operation)) _flushes.remove(uid);
    });
    _flushes[uid] = operation;
    return operation;
  }

  Future<void> _flush(String uid, int revision) async {
    final state = await _read(uid);
    final pending = Map<String, dynamic>.from(state['pending'] as Map);
    bool valid() => uid == _currentUid() && revision == _revision();
    for (final entry in pending.entries) {
      final job = Map<String, dynamic>.from(entry.value as Map);
      if (!valid()) return;
      if (job['assigned'] == true) {
        try {
          final result = await api.request(
            'POST',
            '/v2/destination/${Uri.encodeComponent(entry.key)}/cancel',
          );
          if (!valid()) return;
          if (result['accepted'] == true || result['closed'] == true) {
            await _update(uid, (latest) {
              final current = (latest['pending'] as Map)[entry.key] as Map?;
              if (current != null) current['assigned'] = false;
            });
          }
        } catch (_) {
          /* Retain the pending cancellation for retry. */
        }
      }
      for (final session
          in (job['sessions'] as List? ?? const []).whereType<String>()) {
        if (!valid()) return;
        var finished = false;
        try {
          await api.request('POST', '/navigation/end', {
            'sessionId': session,
            'status': 'Cancelled',
          });
          finished = true;
        } on SecureApiException catch (error) {
          // Missing or already-finished sessions cannot restore an active trip.
          finished = error.status == 404 || error.status == 409;
        } catch (_) {
          /* Retry uncertain network outcomes. */
        }
        if (!valid()) return;
        if (finished) {
          await _update(uid, (latest) {
            final current = (latest['pending'] as Map)[entry.key] as Map?;
            (current?['sessions'] as List?)?.remove(session);
          });
        }
      }
      await _update(uid, (latest) {
        final current = (latest['pending'] as Map)[entry.key] as Map?;
        if (current != null &&
            current['assigned'] != true &&
            (current['sessions'] as List).isEmpty) {
          (latest['pending'] as Map).remove(entry.key);
        }
      });
    }
  }

  Future<void> send(String navigatorUid, MapPlace destination) async {
    await api.request(
      'POST',
      '/v2/navigators/${Uri.encodeComponent(navigatorUid)}/destination',
      {
        'navigator_id': navigatorUid,
        'destination': {
          'name': destination.name,
          'address': destination.address,
          'latitude': destination.latitude,
          'longitude': destination.longitude,
        },
      },
    );
  }

  Stream<Map<String, dynamic>> watch() => api.poll(() async {
    final owner = _currentUid(), revision = _revision();
    unawaited(flushCancellations().catchError((Object _) {}));
    final data = await api.request('GET', '/v2/destination');
    if (owner != _currentUid() || revision != _revision()) {
      throw const SecureApiException('Account changed.', status: 401);
    }
    final id = (data['assignment'] as Map?)?['id'];
    if (id is String && await isCancelled(id)) {
      return {...data, 'assignment': null};
    }
    return data;
  });

  Future<void> cancel(
    String id, {
    bool assigned = true,
    String? sessionId,
  }) async {
    final uid = _currentUid();
    if (uid == null) throw StateError('Sign in to cancel navigation.');
    final revision = _revision();
    await _update(uid, (state) {
      final cancelled = state['cancelled'] as List;
      if (!cancelled.contains(id)) cancelled.add(id);
      final jobs = state['pending'] as Map;
      final job = Map<String, dynamic>.from(
        jobs[id] as Map? ?? {'assigned': false, 'sessions': <String>[]},
      );
      job['assigned'] = job['assigned'] == true || assigned;
      final sessions = List<dynamic>.from(job['sessions'] as List);
      if (sessionId != null && !sessions.contains(sessionId)) {
        sessions.add(sessionId);
      }
      job['sessions'] = sessions;
      jobs[id] = job;
    });
    if (uid == _currentUid() && revision == _revision()) {
      unawaited(flushCancellations().catchError((Object _) {}));
    }
  }

  Future<void> acknowledge(String id) async {
    await api.request(
      'POST',
      '/v2/destination/${Uri.encodeComponent(id)}/acknowledge',
    );
  }
}
