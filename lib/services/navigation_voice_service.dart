import 'dart:async';
import '../models/route_plan.dart';
import 'gabay_tts_service.dart';
import 'navigation_voice_guidance.dart';
import 'navigator_location_service.dart';
import 'route_timeline_tracker.dart';
import 'vi_navigation_session.dart';

/// Session-owned speech, independent of the currently visible screen/tab.
class NavigationVoiceService {
  NavigationVoiceService._();
  static final instance = NavigationVoiceService._();
  final _gps = NavigatorLocationService.instance;
  final _timeline = RouteTimelineTracker.instance;
  final _session = ViNavigationSession.instance;
  final _tts = GabayTtsService.instance;
  late final _guidance = NavigationVoiceGuidance(
    speak: _tts.speakGuidance,
    stopSpeech: _tts.stop,
  );
  RoutePlanResult? _route;
  bool _finishing = false;
  bool get ownsSpeech => _route != null || _finishing;
  bool get enabled => _guidance.enabled;
  set enabled(bool value) {
    _guidance.enabled = value;
    if (!value) unawaited(_tts.stop());
    if (value) _onLocation();
  }

  void start(RoutePlanResult route, {required bool enabled}) {
    _detach();
    unawaited(_tts.stop());
    _finishing = false;
    _route = route;
    _guidance.enabled = enabled;
    _guidance.start(route);
    _gps.addListener(_onLocation);
    _timeline.addListener(_onTimeline);
    _session.addListener(_onSession);
    _onLocation();
  }

  void _onLocation() {
    final fix = _gps.lastPosition;
    final position = _gps.livePosition;
    if (_route == null || fix == null || position == null) return;
    _guidance.update(
      position: position,
      time: fix.timestamp,
      accuracy: fix.accuracy,
      now: DateTime.now(),
    );
  }

  bool get _hasArrived =>
      _route != null &&
      _timeline.activeDestination?.latLng == _route!.destination.latLng &&
      !_timeline.isTracking &&
      _timeline.entries.lastOrNull?.isArrived == true;

  void _onTimeline() {
    if (!_hasArrived) return;
    _detach();
    _finishing = true;
    _route = null;
    unawaited(_guidance.arrived().whenComplete(() => _finishing = false));
  }

  void _onSession() {
    if (_session.isNavigating) return;
    if (_hasArrived) {
      _onTimeline();
    } else {
      _detach();
      _route = null;
      _finishing = false;
      unawaited(_guidance.stop());
    }
  }

  void _detach() {
    _gps.removeListener(_onLocation);
    _timeline.removeListener(_onTimeline);
    _session.removeListener(_onSession);
  }
}
