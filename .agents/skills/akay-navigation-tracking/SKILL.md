---
name: akay-navigation-tracking
description: Implement or debug Akay destination search, route planning, GPS sessions, and caregiver live tracking. Use when changing map behavior or navigation persistence across the Flutter app, HTTP API, and Firebase Realtime Database.
---

# Akay navigation and tracking

Treat route display, local navigation state, backend sessions, and caregiver location streams as separate pieces that must agree. Paths below are relative to the repository root. Read only the pieces involved in the requested change, and verify current contracts in code.

## Trace the relevant flow

- Screens: `lib/pages/visually_impaired/visually_impaired_track.dart`, `lib/pages/caregiver/caregiver_track.dart`, and `lib/pages/screens/route_planner_page.dart`.
- Map controls and panels: `lib/widgets/track/`. Rendering helpers and style: `lib/utils/gabay_map_rendering.dart` and `lib/theme/gabay_map_style.dart`.
- Destinations and routes: `lib/services/destination_search_service.dart`, `lib/services/map_place_service.dart`, `lib/models/search_destination.dart`, and `lib/models/route_plan.dart`.
- GPS ownership: `lib/services/navigator_location_service.dart`. Dashboard/track navigation state: `lib/services/vi_navigation_session.dart`.
- Persistence: `lib/services/navigation_persistence_service.dart` and `lib/services/live_location_service.dart`. Timeline state: `lib/services/route_timeline_tracker.dart`.
- Provider and API configuration: `lib/config/maps_config.dart` and `lib/config/api_config.dart`. Inspect these without copying credentials into output or new files.

## Preserve cross-service contracts

Navigation sessions use the PostgreSQL-backed HTTP API; caregiver live GPS uses Firebase Realtime Database at `live_location/{deviceID}`. The device ID must match `navigationsessions.deviceid`. Reuse `LiveLocationService.ensureDeviceId()` and the existing `akay_navigation_device_id` preference rather than generating a new ID per page or update.

The live record includes latitude, longitude, speed, heading, accuracy, and timestamp. Firebase timestamps are milliseconds since epoch. Preserve nullable or malformed-record handling in `watch`, and distinguish missing or stale updates from a valid fresh location. A caregiver subscription reads the selected device; it must not seed or overwrite that device's location.

Read the existing start, update, and end session methods before changing lifecycle behavior. Keep HTTP session state, live GPS publication, and `ViNavigationSession` consistent through failures and repeated taps. Preserve throttling and cleanup of timers, listeners, and position subscriptions. Do not infer that changing tabs should terminate an ongoing trip; inspect the current ownership first.

Both Google Maps and flutter_map dependencies exist. Check the rendering path being modified and convert coordinate types deliberately at boundaries. Preserve latitude/longitude order and units for distance, speed, and timestamps.

`RouteTimelineTracker` currently has persistence TODOs. Do not describe its timeline as uploaded or durable unless the corresponding implementation exists. Likewise, local route display alone does not prove a backend navigation session was created.

## Validate the changed behavior

Use focused tests with fake location updates and mocked service boundaries for changed logic. Relevant scenarios include denied location permission, disabled GPS, malformed or missing live data, failed session creation, repeated start/end requests, and subscription cleanup. Select scenarios affected by the change rather than expanding every task into a full audit.

Format changed Dart files, run `flutter analyze`, and run relevant tests when the SDK is available. Device GPS and caregiver synchronization need device/emulator verification; clearly distinguish those results from mocked tests. Use an emulator or explicitly authorized test environment for writes rather than testing against a real person's live location. Report unavailable services or unverified backend behavior without claiming success.
