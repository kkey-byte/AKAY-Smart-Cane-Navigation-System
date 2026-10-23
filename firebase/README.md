# Current consent/security rules (prepared, not deployed)

`database.rules.json` now denies direct caregiver access and legacy sharing writes.
Caregiver reads use the verified, consent-checked HTTP API. Run `npm test` for the
current rules; the old test filename forwards to the same suite.

See [pairing and device rollout](../docs/pairing_and_devices.md) before deploying.
The SQL migration, backend credentials, rules and mobile app require coordinated
rollout. Historical deployments and old grant instructions below do not describe
the prepared v2 policy. No new rules were deployed during this change.

## Historical breadcrumb implementation (superseded sharing instructions)

# AKAY breadcrumb tracking

Implementation validation (2026-09-29): nine focused Flutter tests and two Firebase
emulator tests passed. Full Flutter analysis found no errors or warnings; 16 existing
informational lints remain outside this change. The additive database rules were
successfully deployed to `gabay-application-db-default-rtdb`. Real two-device GPS and
background behavior have not yet been verified.

## Use the feature

1. Sign in as caregiver and open **Track → Breadcrumb tracks** or
   **Reports → Breadcrumb tracks**. Copy the account code. The Track tab keeps its
   original map, patient selector, and route controls; shared patients and their
   latest breadcrumbs appear directly on that map.
2. Sign in as navigator and open **Reports → Breadcrumb tracks → Share with caregiver**.
   Enter that code and a caregiver label, then grant access. This shares both
   current and previous tracks. **Manage access** removes a caregiver's access.
   Both report pages retain their original cards and sections; breadcrumb controls
   are an additional card with a separate detail screen and back navigation.
3. Start a navigation route, or select **Start recording** in My tracks. Location
   permission and a fresh GPS fix with accuracy of 50 metres or better are required.
4. The caregiver selects the patient and opens a track. The map draws the actual
   recorded path and latest location, with controls to follow or fit the whole trip.
5. Arrival, cancelling navigation, or **Stop and save track** finishes the recording.
   Both accounts can reopen saved tracks. Load older tracks in batches of 100.

## Storage and lifecycle

- Firebase Auth UID identifies the navigator; device IDs and mock `nav_1` IDs are
  not used for the breadcrumb feature. Existing PostgreSQL navigation summary
  requests remain independent and do not block breadcrumb recording.
- `breadcrumb_trips/{navigatorUid}/{tripId}` contains trip metadata and timestamped
  latitude/longitude/accuracy points. Firebase updates append only new points.
- `breadcrumb_shares/{navigatorUid}/{caregiverUid}` grants read access.
  `breadcrumb_links/{caregiverUid}/{navigatorUid}` supplies the caregiver's patient list.
  The navigator writes/removes both entries atomically; caregivers cannot grant
  themselves access or modify a navigator's recording.
- Each accepted fix is queued in account-scoped local preferences before cloud sync.
  Uploads retry every 10 seconds and on reconnection. An upload acknowledgment cannot
  discard GPS fixes recorded during that upload. Revoked caregivers lose subsequent
  database access; previously viewed information cannot be retroactively erased.
- Jitter under 5 metres is suppressed, with stationary samples every 20 seconds
  when the platform supplies fresh fixes. Records older than 45 seconds show a
  stale state. Offline screens explicitly identify the last known data.
- Recording belongs to the service, not the map widget, and continues across tabs.
  Android uses a foreground location notification and wake lock during recording.
  iOS declares the location background mode. Physical-device permission, lock-screen,
  battery restriction, and OS suspension behavior still require device verification.
  Browsers may suspend background tabs. Force-killing the app ends GPS collection;
  on next launch the locally saved trip is marked interrupted rather than pretending
  that missing locations were recorded.
- Logout stops recording. Account caches are isolated. No public location lookup
  or production test-patient writes are used.

## Database rules

`current-database.rules.json` is the original rules snapshot downloaded on
2026-09-29. It permits the pre-existing `navigation_live` path only.
`breadcrumbs.rules.json` is the new rules fragment. `database.rules.json` is the
complete additive merge used by both emulator tests and `deploy.json`, preserving
the existing path. Before any later deployment, re-fetch current rules and reconcile
concurrent changes. Never replace a live project's rules with the fragment alone.

From this directory, after reviewing the merged file:

```powershell
node node_modules/firebase-tools/lib/bin/firebase.js deploy --only database --project gabay-application-db --config deploy.json
```

No backend migration or new Flutter dependency is needed. Firebase must be configured
for the same project as `lib/firebase_options.dart`.

## Verification

From the repository root:

```powershell
flutter test --no-pub test/breadcrumb_recorder_test.dart test/breadcrumb_ui_test.dart test/tracking_ui_test.dart test/device_location_test.dart
flutter analyze --no-pub
```

From this directory (Node and Java 21+ required):

```powershell
npm ci
npm test
```

The emulator uses only `demo-akay-breadcrumbs`. Tests cover cross-client track
updates, authorized reads, denied stranger/anonymous reads, denied caregiver writes,
revocation, and malformed location rejection. Flutter tests cover local recording,
offline/restart recovery, account isolation, concurrent GPS/upload handling,
freshness, and large-text track cards in both themes.

Final device acceptance: two separate signed-in devices, grant access, walk a short
route, switch tabs and lock the navigator phone, disconnect/reconnect its network,
stop the trip, reopen it on both accounts, revoke access, and verify that the caregiver
can no longer fetch it. This is distinct from the automated emulator tests.
