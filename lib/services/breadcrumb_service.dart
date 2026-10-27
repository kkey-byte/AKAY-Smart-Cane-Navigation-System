import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/breadcrumb_trip.dart';
import '../models/user_role.dart';
import 'app_session_service.dart';
import 'breadcrumb_recorder.dart';
import 'breadcrumb_repository.dart';
import 'continuous_breadcrumb_tracker.dart';
import 'navigator_location_service.dart';
import 'live_location_service.dart';

/// App/session-owned recording, independent of navigation and screen lifetimes.
class BreadcrumbService extends ChangeNotifier with WidgetsBindingObserver {
  BreadcrumbService._();
  static final instance = BreadcrumbService._();
  final repository = FirebaseBreadcrumbRepository();
  BreadcrumbRecorder? recorder;
  ContinuousBreadcrumbTracker? _tracker;
  Future<void>? _initializing;
  bool connected = false;
  bool _reconcileScheduled = false;
  String? _lastOwner;
  int? _lastRevision;
  bool _permissionAttempted = false;
  bool get isRecording => recorder?.active != null;
  bool get trackingRequested => _tracker?.requested ?? false;
  String? get error =>
      recorder?.storageError ?? _tracker?.error ?? recorder?.syncError;
  List<BreadcrumbTrip> get trips => recorder?.trips ?? [];
  List<BreadcrumbPoint> get points => recorder?.active?.points ?? [];

  String? _eligibleOwner() {
    final session = AppSessionService.instance;
    final user = FirebaseAuth.instance.currentUser;
    if (!session.isLoggedIn ||
        session.role != UserRole.navigator ||
        user == null ||
        user.email?.toLowerCase() != session.email?.toLowerCase()) {
      return null;
    }
    return user.uid;
  }

  BreadcrumbPoint? _currentPoint() {
    final fix = NavigatorLocationService.instance.lastPosition;
    return fix == null
        ? null
        : BreadcrumbPoint(
            fix.latitude,
            fix.longitude,
            fix.timestamp,
            fix.accuracy,
          );
  }

  Future<void> initialize() => _initializing ??= _initialize();
  Future<void> _initialize() async {
    final location = NavigatorLocationService.instance;
    recorder = BreadcrumbRecorder(
      repository,
      await SharedPreferences.getInstance(),
    );
    recorder!.addListener(notifyListeners);
    _tracker = ContinuousBreadcrumbTracker(
      recorder: recorder!,
      eligibleOwner: _eligibleOwner,
      startLocation: () async {
        final requestPermission = !_permissionAttempted;
        _permissionAttempted = true;
        await location.startTracking(requestPermission: requestPermission);
        if (location.permissionDenied) {
          throw StateError('Location access is required for recording.');
        }
      },
      backgroundRecording: (enabled) async {
        if (!enabled) LiveLocationService.instance.sharingEnabled = false;
        if (!enabled && FirebaseAuth.instance.currentUser != null) {
          await LiveLocationService.instance.clear();
        }
        await location.setBackgroundRecording(enabled);
        LiveLocationService.instance.sharingEnabled = enabled;
      },
      publishLocation: (point) => LiveLocationService.instance.publish(
        latitude: point.latitude,
        longitude: point.longitude,
        accuracy: point.accuracy,
        sampledAt: point.time,
        heading: location.headingDegrees,
        speed: location.speedMetersPerSecond,
      ),
      currentPoint: _currentPoint,
    )..addListener(notifyListeners);
    repository.watchConnection().listen(
      (value) {
        connected = value;
        notifyListeners();
        if (value) unawaited(recorder!.sync());
      },
      onError: (Object _) {
        connected = false;
        notifyListeners();
      },
    );
    location.addListener(_onLocation);
    AppSessionService.instance.addListener(_onSession);
    FirebaseAuth.instance.authStateChanges().listen((_) => _onSession());
    WidgetsBinding.instance.addObserver(this);
    Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(recorder!.sync()),
    );
    Timer.periodic(const Duration(seconds: 30), (_) {
      _scheduleReconcile();
      final fix = location.lastPosition;
      if (trackingRequested &&
          isRecording &&
          !location.isLoading &&
          !location.permissionDenied &&
          fix != null &&
          DateTime.now().difference(fix.timestamp) >=
              const Duration(seconds: 25)) {
        unawaited(location.refreshCurrentLocation(requestPermission: false));
      }
    });
    _onSession();
  }

  void _onSession() {
    final owner = _eligibleOwner();
    final revision = AppSessionService.instance.identityRevision;
    if (_lastOwner == owner && _lastRevision == revision) return;
    if (_lastOwner != owner) _permissionAttempted = false;
    _lastOwner = owner;
    _lastRevision = revision;
    if (owner == null) {
      unawaited(_tracker!.reconcile());
    } else {
      _scheduleReconcile();
    }
  }

  void _scheduleReconcile() {
    if (_reconcileScheduled) return;
    final state = WidgetsBinding.instance.lifecycleState;
    if (state != null && state != AppLifecycleState.resumed) return;
    _reconcileScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reconcileScheduled = false;
      unawaited(_tracker!.reconcile());
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _scheduleReconcile();
    if (state == AppLifecycleState.paused) unawaited(recorder!.sync());
  }

  void _onLocation() => unawaited(_tracker?.onLocation() ?? Future.value());

  // Kept for existing My tracks controls. Route names do not own recording.
  Future<void> start({String? destination}) async {
    await initialize();
    if (_eligibleOwner() == null) {
      throw StateError('Sign in as a navigator to record a track.');
    }
    _permissionAttempted = false;
    await _tracker!.resume();
    if (error != null) throw StateError(error!);
    unawaited(recorder!.sync());
  }

  Future<void> stop() async {
    LiveLocationService.instance.sharingEnabled = false;
    await _tracker?.pause();
    unawaited(recorder?.sync() ?? Future.value());
  }
}
