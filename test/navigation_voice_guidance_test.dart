import 'dart:async';
import 'dart:convert';
import 'package:app_mobile/models/linked_navigator.dart';
import 'package:app_mobile/models/route_plan.dart';
import 'package:app_mobile/services/map_place_service.dart';
import 'package:app_mobile/services/navigation_voice_guidance.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

RoutePlanResult voiceRoute() {
  final steps = [
    const RouteTurnInstruction(
      instruction: 'Head east',
      maneuverType: 'depart',
    ),
    const RouteTurnInstruction(instruction: 'Turn right', modifier: 'right'),
    const RouteTurnInstruction(instruction: 'Turn left', modifier: 'left'),
    const RouteTurnInstruction(
      instruction: 'You have arrived',
      maneuverType: 'arrive',
    ),
  ];
  for (var i = 0; i < steps.length; i++) {
    NavigationVoiceGuidance.attachLocation(steps[i], LatLng(0, i * .001));
  }
  return RoutePlanResult(
    navigator: const LinkedNavigator(
      id: 'synthetic',
      name: 'Navigator',
      address: '',
      location: LatLng(0, 0),
      status: '',
      batteryPercent: -1,
    ),
    destination: const MapPlace(
      id: '',
      name: 'Destination',
      address: '',
      latitude: 0,
      longitude: .003,
    ),
    estimatedTime: '',
    estimatedDistance: '',
    currentSpeed: '',
    navigationStatus: 'Navigating',
    polylinePoints: const [
      LatLng(0, 0),
      LatLng(0, .001),
      LatLng(0, .002),
      LatLng(0, .003),
    ],
    tripStartedAt: DateTime(2026, 11, 7),
    turnInstructions: steps,
  );
}

void main() {
  final now = DateTime(2026, 11, 7, 12);
  late NavigationVoiceGuidance guide;
  late List<String> spoken;
  setUp(() {
    spoken = [];
    guide = NavigationVoiceGuidance(
      speak: (text) async {
        spoken.add(text);
        return true;
      },
      stopSpeech: () async {},
    )..start(voiceRoute());
  });
  Future<void> update(
    double longitude, {
    double latitude = 0,
    double accuracy = 5,
    DateTime? time,
  }) async {
    guide.update(
      position: LatLng(latitude, longitude),
      time: time ?? now,
      accuracy: accuracy,
      now: now,
    );
    await Future<void>.delayed(Duration.zero);
  }

  test(
    'approach and turn thresholds speak once and arrival uses existing event',
    () async {
      await update(0);
      expect(spoken, ['Head east']);
      await update(.0006);
      expect(spoken.last, 'In 40 meters, Turn right');
      await update(.0006);
      expect(spoken.length, 2);
      await update(.0009);
      expect(spoken.last, 'Turn right');
      await update(.001);
      expect(spoken.length, 3);
      await update(.0016);
      expect(spoken.last, 'In 40 meters, Turn left');
      await update(.0019);
      expect(spoken.last, 'Turn left');
      await update(.003);
      expect(spoken.any((text) => text.contains('arrived')), isFalse);
      await guide.arrived();
      await guide.arrived();
      expect(
        spoken.where((text) => text == 'Arrived at destination'),
        hasLength(1),
      );
    },
  );

  test(
    'poor, stale, off-route and backward fixes do not repeat directions',
    () async {
      await update(.0009, accuracy: 90);
      await update(.0009, time: now.subtract(const Duration(minutes: 2)));
      await update(.0009, latitude: 1);
      expect(spoken, isEmpty);
      await update(.0009);
      expect(spoken, ['Turn right']);
      await update(.0006);
      await update(.0009);
      expect(spoken, ['Turn right']);
    },
  );

  test(
    'mute suppresses speech, resume uses current progress, cancel clears route',
    () async {
      guide.enabled = false;
      await update(.0006);
      expect(spoken, isEmpty);
      guide.enabled = true;
      await update(.0009);
      expect(spoken, ['Turn right']);
      await guide.stop();
      await update(.0019);
      await guide.arrived();
      expect(spoken, ['Turn right']);
    },
  );

  test(
    'pending cues deduplicate and failed playback can retry on next fix',
    () async {
      final completion = Completer<bool>();
      guide = NavigationVoiceGuidance(
        speak: (text) {
          spoken.add(text);
          return completion.future;
        },
        stopSpeech: () async {},
      )..start(voiceRoute());
      await update(.0009);
      await update(.0009);
      expect(spoken, ['Turn right']);
      completion.complete(false);
      await Future<void>.delayed(Duration.zero);
      await update(.0009);
      expect(spoken, ['Turn right', 'Turn right']);
    },
  );

  test(
    'arrival retries a transient playback failure without changing completion',
    () async {
      var attempts = 0;
      guide = NavigationVoiceGuidance(
        speak: (text) async {
          spoken.add(text);
          return ++attempts > 1;
        },
        stopSpeech: () async {},
      )..start(voiceRoute());
      await guide.arrived();
      await guide.arrived();
      expect(spoken, ['Arrived at destination', 'Arrived at destination']);
    },
  );

  test(
    'OSRM maneuver locations survive first-step copy without route model changes',
    () async {
      final fixture = voiceRoute();
      final service = MapPlaceService(
        apiBaseUrl: 'https://example.test/api',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'code': 'Ok',
              'routes': [
                {
                  'distance': 333,
                  'duration': 250,
                  'geometry': {
                    'coordinates': [
                      [0, 0],
                      [.001, 0],
                      [.002, 0],
                      [.003, 0],
                    ],
                  },
                  'legs': [
                    {
                      'steps': [
                        {
                          'distance': 111,
                          'maneuver': {
                            'type': 'depart',
                            'location': [0, 0],
                          },
                        },
                        {
                          'distance': 111,
                          'maneuver': {
                            'type': 'turn',
                            'modifier': 'right',
                            'location': [.001, 0],
                          },
                        },
                        {
                          'distance': 111,
                          'maneuver': {
                            'type': 'turn',
                            'modifier': 'left',
                            'location': [2, 91],
                          },
                        },
                      ],
                    },
                  ],
                },
              ],
            }),
            200,
          ),
        ),
      );
      final result = await service.buildRoutePlan(
        navigator: fixture.navigator,
        destination: fixture.destination,
      );
      expect(result.turnInstructions.first.isNext, isTrue);
      expect(
        NavigationVoiceGuidance.locationOf(result.turnInstructions.first),
        const LatLng(0, 0),
      );
      expect(
        NavigationVoiceGuidance.locationOf(result.turnInstructions[1]),
        const LatLng(0, .001),
      );
      expect(
        NavigationVoiceGuidance.locationOf(result.turnInstructions[2]),
        isNull,
      );
      expect(result.polylinePoints, fixture.polylinePoints);
    },
  );
}
