# Continuous navigator breadcrumbs

Breadcrumb recording now belongs to the signed-in navigator session, rather than
the navigation page. Firebase authentication and the local navigator role must
agree before recording starts. Login/session restore schedules GPS startup after
the UI is visible. Caregiver sessions do not record their own location.
Navigator Reports keeps compact trip cards directly under Recent Trips. Each
card includes a source icon, recorded distance, date and status. Two cards fit
side by side where space/text scaling permit; narrow or large-text layouts use
one column. Selecting View route opens a scrollable modal with the recorded map,
start/end times, distance, duration, point count, source and status. Closing the
modal ends its detail subscription; Reports stays underneath without inserting
details below the grid. Navigator-only Recording options expand within
Reports for pause/resume and sync; caregiver reports remain read-only.

Arriving at a destination, cancelling navigation and closing the map do not stop
recording. Reports offers explicit pause/resume; an account-scoped pause now
survives app restart and login until explicitly resumed. Pausing is available
even while waiting for the first valid fix. Logout stops recording and clears
active GPS state. A restarted app marks a previous unfinished segment interrupted,
retains its outbox and starts a new segment only when that account is not paused.
Logout cleanup stops the session without creating a new permanent user pause;
an already explicitly paused account remains paused when reopened.
This does not imply GPS capture while the process is terminated.

## Location and battery policy

- Android all-day updates request high accuracy, a two-second interval and a
  one-metre distance filter while recording. Active navigation uses its existing
  navigation accuracy settings. Apple recording streams use a one-metre filter and retain
  the existing location background mode and visible background indicator.
- The recorder retains the conservative displacement and confirmation filter
  described in `gps_drift_filter.md`. Stationary freshness is saved separately
  from unchanged original route points, at most every thirty seconds. Fixes with accuracy worse than
  fifty metres, invalid coordinates and stale timestamps are rejected.
- A thirty-second recovery timer checks tracking while foregrounded. While an
  active recording has stopped receiving fixes, it requests a fresh fix without
  prompting for permissions in the background. Automatic retries do not repeatedly
  prompt after permission denial; explicit Resume can request access again.
- Tracks roll over after an hour, at local midnight or at 500 accepted points.
  GPS outages longer than ninety seconds also create separate segments, ending
  the previous segment at its last accepted sample instead of spanning the outage.
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
Firebase reconnection. One upload remains in flight until the backend acknowledges
it, avoiding repeated offline writes. New fixes arriving during an upload remain
pending. Switching accounts invalidates old acknowledgments and isolates queues.
Storage failures are surfaced in Recording options; failed disk writes are retried before
cloud uploads, and unreadable caches are protected against overwrite. Cloud
failures do not remove pending tracks. Recording, waiting for a valid location,
paused, pending upload, uploading and acknowledged updates have distinct textual
status feedback using the existing screen/theme. Device preferences are still the local store and grow with history;
neither storage capacity nor physical-device crash durability has been measured.

Firestore is the history authority at
`navigators/{firebaseUid}/trips/{segmentId}/points/{sequence}`. Uploads use bounded
HTTP batches and stable IDs. The final summary acknowledgement clears pending
state; a lost acknowledgement is retryable after restart. `lastSampledAt` is
sent separately so stationary freshness never rewrites a point's capture time.
Deploy the updated backend alongside the app to preserve this field. Recent-trip
lists load summaries; details read back the complete cloud route when available,
with an explicit device-copy fallback for the owner. Pending local changes still
take precedence. Details display start/end timestamps and approximate distance.
Caregivers remain behind the existing consent-checked HTTP endpoints. No new
PostgreSQL navigation session is created merely because recording is active.
See `trip_storage_architecture.md` for migration, retention and deletion.

## Verification

Focused tests cover route-independent startup, arrival/cancellation independence,
hourly/midnight/point-limit rollover, manual pause/resume, logout during GPS
startup, account isolation, poor-fix recovery, offline recovery, upload races and
HTTP payload compatibility. The synthetic acceptance test exercises no-destination
recording, offline walking, explicit pause, app restart, a lost final acknowledgement,
deduplicated replay and route read-back. Other tests cover persisted pauses,
capture-time preservation, storage failures, large text and both themes.
Navigation, session/auth and breadcrumb display regression tests remain included.

Physical-device validation is still required: login without opening a map; walk
with the screen locked; reach/cancel a destination and keep walking; disconnect
and reconnect networking; reopen the app; pause/resume; deny/re-enable location;
and verify an authorized caregiver receives history while an unlinked account
cannot. No live personal location data was written during automated tests, and
background GPS, battery consumption and live caregiver delivery are unverified.

## Panel acceptance run (manual evidence still required)

Restart the updated `app_mobile_backend` and hot-restart the app. Use synthetic
test accounts. In Chrome retain the same origin and browser storage: changing
ports, clearing site data or using another browser profile does not carry the
old origin's pending queue into the new session. Prefer a physical phone for
walking/location-accuracy tests; retain the 50-metre accuracy filter.

| Step | Action | Expected evidence |
|---|---|---|
| 1 | Navigator opens Reports, then Recording options. Do not choose a destination. | Recording starts on an acceptable fresh fix, or explicitly waits for one. The waiting state can be paused. |
| 2 | Walk with valid locations. | The current track accumulates confirmed movement; timestamps stay ordered. A stationary wait does not create a drifting path. |
| 3 | Disconnect networking and continue walking with location available. | Recording continues locally; pending updates are shown. Cloud acknowledgement is not claimed. |
| 4 | Pause and restart the app without clearing storage. | The finished track remains, pending updates survive, and recording stays paused. |
| 5 | Restore connectivity or use Sync now. | Pending updates clear only after all point uploads and final summary acknowledgement succeed. |
| 6 | Select View route on a completed trip card after its next history refresh. | The modal reports cloud history, start/end times, approximate distance, duration, source, point count and the recorded path. Closing it ends its subscription. Firestore has one stable trip ID with separate point documents, not duplicate retry trips. |
| 7 | Resume without a destination, then reach/cancel a separately planned route. | Breadcrumb recording remains independent of navigation arrival/cancellation. |
| 8 | Deny location or interrupt valid fixes for more than 90 seconds, then recover. | No invented coordinates are saved. Recovery starts a separate segment rather than drawing through the gap. |

An unexpected process interruption is different from explicit Pause: the old
segment is marked interrupted at its last accepted sample and remains retryable;
an unpaused navigator session may start a new segment after restart. This is
recovery of saved data, not proof of location capture while the process was dead.
Screen-lock/background behavior must be recorded separately on the supported
mobile devices. Live sharing now uses authenticated backend publication; see
`caregiver_live_monitoring.md` for implementation and deployment validation.
