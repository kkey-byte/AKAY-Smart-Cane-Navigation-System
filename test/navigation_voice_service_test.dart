import 'package:app_mobile/models/route_plan.dart';
import 'package:app_mobile/services/gabay_tts_service.dart';
import 'package:app_mobile/services/navigation_voice_guidance.dart';
import 'package:app_mobile/services/navigation_voice_service.dart';
import 'package:app_mobile/services/navigator_location_service.dart';
import 'package:app_mobile/services/route_timeline_tracker.dart';
import 'package:app_mobile/services/vi_navigation_session.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'caregiver_track_binding_test.dart' show LocalGps, fix;
import 'navigation_voice_guidance_test.dart' show voiceRoute;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final gps = NavigatorLocationService.instance;
  final timeline = RouteTimelineTracker.instance;
  final session = ViNavigationSession.instance;
  late LocalGps platform;
  late GeolocatorPlatform previous;
  late List<String> spoken;
  late RoutePlanResult route;
  setUp(() {
    previous = GeolocatorPlatform.instance;
    platform = LocalGps();
    GeolocatorPlatform.instance = platform;
    spoken = [];
    final fixture = voiceRoute();
    for (var i = 0; i < fixture.turnInstructions.length; i++) {
      NavigationVoiceGuidance.attachLocation(
        fixture.turnInstructions[i],
        LatLng(1, 2 + i * .001),
      );
    }
    route = RoutePlanResult(
      navigator: fixture.navigator,
      destination: fixture.destination.copyWith(latitude: 1, longitude: 2.003),
      estimatedTime: '',
      estimatedDistance: '',
      currentSpeed: '',
      navigationStatus: 'Navigating',
      polylinePoints: const [
        LatLng(1, 2),
        LatLng(1, 2.001),
        LatLng(1, 2.002),
        LatLng(1, 2.003),
      ],
      tripStartedAt: fixture.tripStartedAt,
      turnInstructions: fixture.turnInstructions,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (
          call,
        ) async {
          if (call.method == 'isLanguageAvailable') return true;
          if (call.method == 'speak') {
            final text = call.arguments is Map
                ? (call.arguments as Map)['text']
                : call.arguments;
            spoken.add(text as String);
          }
          return 1;
        });
  });
  tearDown(() async {
    session.setNavigating(false);
    await GabayTtsService.instance.stop();
    timeline.reset();
    gps.stopTracking(clearLocation: true);
    GeolocatorPlatform.instance = previous;
    await platform.updates.close();
  });

  Future<void> start(WidgetTester tester) async {
    await gps.startTracking();
    session.setNavigating(true);
    timeline.startTracking(route.destination);
    NavigationVoiceService.instance.start(route, enabled: true);
    await tester.pump();
    await tester.pump();
  }

  testWidgets(
    'GPS-driven speech continues while backgrounded and arrives once in either listener order',
    (tester) async {
      // The screen currently handles arrival before the voice listener; preserve
      // that ordering to reproduce the session-false/arrival race.
      void screenArrival() {
        if (!timeline.isTracking &&
            timeline.entries.lastOrNull?.isArrived == true) {
          session.setNavigating(false);
        }
      }

      timeline.addListener(screenArrival);
      addTearDown(() => timeline.removeListener(screenArrival));
      await start(tester);
      expect(spoken, ['Head east']);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      platform.updates.add(fix(1, 2.0006));
      await tester.pump();
      await tester.pump();
      expect(spoken.last, 'In 40 meters, Turn right');
      platform.updates.add(fix(1, 2.0009));
      await tester.pump();
      await tester.pump();
      expect(spoken.last, 'Turn right');
      timeline.markDestinationArrived();
      await tester.pump();
      await tester.pump();
      expect(
        spoken.where((text) => text == 'Arrived at destination'),
        hasLength(1),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    },
  );

  testWidgets(
    'existing mute and cancellation stop navigation speech without changing routing',
    (tester) async {
      await start(tester);
      final voice = NavigationVoiceService.instance;
      voice.enabled = false;
      platform.updates.add(fix(1, 2.0006));
      await tester.pump();
      await tester.pump();
      expect(spoken, ['Head east']);
      expect(session.isNavigating, isTrue);
      expect(timeline.isTracking, isTrue);
      voice.enabled = true;
      await tester.pump();
      await tester.pump();
      expect(spoken.last, 'In 40 meters, Turn right');
      session.setNavigating(false);
      final count = spoken.length;
      platform.updates.add(fix(1, 2.0019));
      await tester.pump();
      await tester.pump();
      expect(spoken, hasLength(count));
      expect(voice.ownsSpeech, isFalse);
    },
  );
}
