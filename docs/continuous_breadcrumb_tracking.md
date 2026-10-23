# Continuous navigator breadcrumbs

Breadcrumb recording now belongs to the signed-in navigator session, rather than
the navigation page. Firebase authentication and the local navigator role must
agree before recording starts. Login/session restore schedules GPS startup after
the UI is visible. Caregiver sessions do not record their own location.

Arriving at a destination, cancelling navigation and closing the map do not stop
recording. My tracks offers explicit pause/resume; pausing lasts until resumed or
the account session is reopened. Logout stops recording and clears active GPS
state. A restarted app marks a previous unfinished segment interrupted, retains
its outbox and starts a new segment for the restored navigator session.

## Location and battery policy

- Android all-day updates request high accuracy, a five-second interval and a
  five-metre distance filter. Active navigation retains its existing two-second
  navigation accuracy settings. Apple streams use a five-metre filter and retain
  the existing location background mode and visible background indicator.
- The recorder accepts movement of at least five metres after five seconds, or a
  fresh stationary sample after thirty seconds. Fixes with accuracy worse than
  fifty metres, invalid coordinates and stale timestamps are rejected.
- A thirty-second recovery timer checks tracking while foregrounded. While an
  active recording has stopped receiving fixes, it requests a fresh fix without
  prompting for permissions in the background. Automatic retries do not repeatedly
  prompt after permission denial; explicit Resume can request access again.
- Tracks roll over after an hour, at local midnight or at 500 accepted points.
  Recording continues across segments. This bounds individual uploads and
  caregiver snapshot payloads; historical segments remain available.
- Android uses a visible location foreground-service notification. Background
  location permission is declared and iOS usage descriptions explain daily
  recording. On Android 11+, users grant all-the-time permission in system
  settings when needed. OS suspension, force-stop, denied permissions, disabled
  GPS and browser background throttling can interrupt delivery. This is not a
  boot-start or force-stop recovery service.

Platform reference: [Android background location permissions](https://developer.android.com/develop/sensors-and-location/location/permissions/background)
and the [Geolocator platform setup](https://pub.dev/packages/geolocator).

## Storage and caregiver contract

Accepted fixes persist through the existing account-scoped SharedPreferences
outbox. A fifteen-second timer uploads pending data, with an immediate retry on
Firebase reconnection. One upload remains in flight until Firebase acknowledges
it, avoiding repeated offline writes. New fixes arriving during an upload remain
pending. Switching accounts invalidates old acknowledgments and isolates queues.
Storage failures are surfaced in My tracks; cloud failures do not remove pending
tracks. Device preferences are still the local store and grow with history;
neither storage capacity nor physical-device crash durability has been measured.

The existing Firebase Realtime Database structure is unchanged:
`breadcrumb_trips/{firebaseUid}/{segmentId}`, with existing metadata and indexed
points. Caregivers use existing consent-checked `/api/v2/navigators/:uid/snapshot`
and `/trips` endpoints. No new PostgreSQL navigation sessions are created merely
because all-day recording is active, and no SQL/Firebase schema migration is
required. Existing route navigation persistence and account/profile APIs remain
separate. Firebase rules and backend access checks are unchanged.

## Verification

Focused tests cover route-independent startup, arrival/cancellation independence,
hourly/midnight/point-limit rollover, manual pause/resume, logout during GPS
startup, account isolation, poor-fix recovery, offline recovery, upload races and
Firebase incremental payload compatibility. Navigation, session/auth and
breadcrumb display regression tests are also included. Flutter analysis reports
only the three existing unrelated informational findings.

Physical-device validation is still required: login without opening a map; walk
with the screen locked; reach/cancel a destination and keep walking; disconnect
and reconnect networking; reopen the app; pause/resume; deny/re-enable location;
and verify an authorized caregiver receives history while an unlinked account
cannot. No live personal location data was written during automated tests, and
background GPS, battery consumption and live caregiver delivery are unverified.
