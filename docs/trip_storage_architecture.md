# AKAY location storage and rollout

The Flutter UI, role routing and source-selection controls are unchanged. The
existing breadcrumb repository now sends phone history to the authenticated
backend. Firestore is the history authority; RTDB stores latest samples only.
PostgreSQL remains the authority for accounts, consent, device custody,
assignments, raw telemetry and alerts. `app_mobile_backend` is the running API
source; `backend_patch` is an older patch bundle and is not the deployment target.

## Storage and recovery

History documents use `navigators/{firebaseUid}/trips/{stableTripId}` and separate
`points/{zeroPaddedSequence}` documents. Trip summaries include start/end,
status, origin/destination, distance in meters, duration in seconds, source,
physical device/assignment when applicable, point count, last capture and server
sync time. Destination is the recorded endpoint, not a fabricated planned place.
All Firestore timestamps use Timestamp values. API responses adapt timestamps
to the existing millisecond-based Flutter model.

The account-scoped existing local outbox is persisted before cloud upload. Phone
snapshots are uploaded in requests of at most 40 points; the existing recorder
rolls bounded segments at 500 points, hourly, at midnight and after GPS outages.
Sequence IDs are stable across retries and app restarts. A lost acknowledgement
can replay the complete snapshot. The server rejects missing sequences during
summary finalization; the client clears pending state only after confirmation.
An interrupted recording is restored as interrupted with its original captures.
Cloud writes wait for acknowledged local persistence. Existing local storage
failures surface through the recorder rather than discarding pending data.

`sampledAt` remains capture time; `receivedAt` and `syncedAt` are server timestamps.
RTDB phone writes use the authenticated backend and monotonic server transactions.
Latest position
remains `phone_location/{firebaseUid}`, with the capture timestamp, so delayed
delivery cannot refresh an old fix. Freshness is derived from capture age.
History is never used as the live phone-location source. Phone identifiers are
never registered physical device IDs.

Recent-trip queries read summaries, order by startedAt and document ID descending,
and return an opaque cursor. The existing load-more interface obtains bounded
100-document pages. Detail reads page points by sequence; the current interface
receives the assembled route. Dashboard route previews request the selected
source's history, preserving phone priority and filtering device/assignment for
cane GPS. The supplied composite indexes support these filtered queries. The
collection-group endedAt index supports retention. No ever-growing route array
is stored on a trip document.

Operational `navigationsessions` relationships and route status remain intact.
Legacy distance/duration/speed fields are frozen: `/navigation/live` and `/end`
ignore client metric edits. They are not a second editable history authority.

## Independent cane GPS protocol

The existing `/api/v2/telemetry` endpoint and PostgreSQL reading/alert behavior
remain unchanged. The additive `POST /api/v2/gps` endpoint uses the existing
`Authorization: Device <registered-uuid>.<machine-secret>` protocol. These are
device credentials, not Firebase service credentials. TLS is required in
production. Provision and rotate machine credentials through the existing
trusted device administration process.

GPS requests contain `assignmentId`, a durable `sessionId`, `event` (`start`,
`point`, `end`), `sequence`, latitude, longitude, optional accuracyMeters and
`sampledAt` as UTC epoch milliseconds. Every event contains a captured fix.
Start is sequence 0; each next event increments by one. The end event contains
the final fix. Retry the exact event after an uncertain response. Reusing an
event with different coordinates or capture time fails. Missing starts, sequence
gaps and points following an end fail. A session ID must never be reused within
an assignment. Assignment changes require a new explicit session.

There is no automatic cane trip creation from telemetry, inactivity timers or
individual coordinates. Firmware/gateway must persist a user-initiated start,
event sequence and end. A deterministic hash of device, assignment and session
identifies the cane trip. Phone and cane sessions remain explicitly separate
sources and are not merged by geographic proximity. A gateway must not mirror a
phone session into a second cane session; simultaneous source recording must be
an explicit operational choice. Existing phone segment policy is preserved.

The backend authenticates the machine credential and resolves both historical
assignment and ownership at capture time, using PostgreSQL intervals
`started_at <= capture < ended_at`. It holds the existing device lock while
writing Firebase. Delayed events remain attributed to the old navigator and
cannot update the current owner's live record. Latest cane records are stored
at `cane_location/{navigatorUid}/{assignmentId}` and update monotonically only
for the current assignment and a fresh capture. Monitoring resolves the current
assignment before reading this path. Historical raw readings remain PostgreSQL.

No firmware or gateway implementation is present in this repository. The new
backend path does not require Flutter to be running, but delivery requires an
independent network path. A phone-only connected cane cannot deliver while that
gateway is unavailable. Firmware/gateway must durably buffer session events,
original capture times and assignment IDs, replay in order, and delete buffered
events only after acknowledgement. No terminated-app phone tracking or physical
cane/network delivery has been implemented or verified by this change.

## Authorization

History reads and caregiver monitoring remain behind Firebase-ID-token-verified
HTTP endpoints. Every read checks active PostgreSQL consent before and after
location reads. Existing polling rechecks authorization on each request; denied
polls invalidate displayed remote data. There is no direct caregiver Firebase
subscription or editable Firebase consent mirror. Firestore client access to
location history is denied; backend Admin credentials remain private deployment
configuration. RTDB legacy grants cannot authorize caregiver history or live reads.

## Controlled migration and deployment

No production records have been read or migrated during implementation. Existing
repository schemas and synthetic records were inspected. Do not switch the API
until the following controlled migration has validated the actual legacy data.
Commands run from `app_mobile_backend` with authorized server credentials; do not
paste identities, credentials or coordinate output into tickets or logs.

1. Back up RTDB legacy history securely. Deploy the reviewed RTDB rules to freeze
   `breadcrumb_trips` writes while preserving owner reads. Phone latest-location
   writes continue. Stop old backend history mutations during this window.
2. Run `node scripts/tripHistory.js inspect NAVIGATOR_UID` for each navigator
   obtained from the PostgreSQL account catalog. It validates bounded legacy
   pages and prints counts only. Investigate nonzero failure counts privately.
3. Run `node scripts/tripHistory.js migrate NAVIGATOR_UID --apply`. It retains
   original trip IDs, validates ownership/capture order, uploads separate point
   documents, finalizes server summaries and verifies the resulting point count.
   Retry safely after interruptions. Existing identity conflicts fail closed.
   Legacy recording sessions become interrupted at their last original capture.
4. Deploy Firestore rules/indexes from `firebase/deploy.json`; wait for index
   readiness. Deploy the updated backend and app together after successful
   migration. Imported open legacy trips carry a recovery marker: a newer local
   outbox may reopen that same ID and finalize its remaining original captures.
   The first normal summary confirmation closes that recovery allowance.
   Migration retries then leave the newer authoritative history intact.
5. Verify navigator and authorized/revoked caregiver reads in a synthetic staging
   environment. Keep legacy records until an operator validates migration and
   selects a deletion policy. There is no dual-write path and no automatic legacy
   deletion during migration. Retain the backup for controlled rollback.

The migration tool is a controlled migration, not an indefinite compatibility
reader. Empty/malformed legacy routes or identity conflicts require reconciliation;
they are not silently skipped as successful uploads. `inspect` and migration
without `--apply` are read-only. Firestore must already be enabled and authorized
for the server service account. Do not deploy the old `backend_patch` over this API.

## Retention and removal

No permanent retention duration is selected. Automatic cleanup is disabled.
An operator may configure `AKAY_TRIP_RETENTION_DAYS` with an approved positive
integer, then schedule `node scripts/tripHistory.js retain`. Each invocation
removes up to 100 expired completed/interrupted trips. Recording trips are excluded.
Schedule further invocations for larger backlogs; invalid configuration fails.
Set the same approved policy in Flutter with
`--dart-define=AKAY_TRIP_RETENTION_DAYS=<days>` to prune acknowledged local cache
entries during sync. Its default is disabled; pending uploads are never pruned.
`BreadcrumbRecorder.applyRetention` also provides an explicit policy hook.

Owner-only `DELETE /api/v2/navigators/{uid}/trips/{id}` removes all point documents
and the matching legacy record, leaving a coordinate-free tombstone to prevent
late upload or migration resurrection. Failed deletion is safe to retry.
The mobile `BreadcrumbService.deleteTrip` hook clears the matching local cache
and pending snapshot only after backend deletion succeeds. Use that hook for
mobile deletion integrations.
Account location removal uses `DELETE /api/v2/navigators/{uid}/location-history`, or the
trusted operator command `node scripts/tripHistory.js delete-account UID --apply`.
It blocks new history writes, removes trip points, summaries and legacy/latest
phone and cane locations, and blocks subsequent phone RTDB writes. This is a
permanent account-removal preparation operation, not a reset-history preference.
Call it before removing account identity; retries must complete before declaring
an account deletion finished. This repository has no existing complete account
deletion flow. The external account deletion orchestrator must also remove the
device's buffered events under the selected account-removal policy.
The mobile `deleteAccountLocationHistory` hook pauses recording,
calls this endpoint and erases the current account's local outbox after server
confirmation. The server also clears PostgreSQL reading coordinates and saved
route coordinates/addresses, ends current assignments and revokes their machine
credentials to prevent new telemetry from restoring erased GPS. Sensor values
and alerts remain intact. The external deletion orchestrator must call this hook
before signing out or removing identity, and clear any other logged-in devices.

## Verification boundaries

Synthetic Node tests cover deterministic uploads, interrupted commits, summary
completion, migration retries, deletion, session ordering, historical assignment
lookup and consent denial/revocation. Flutter tests exercise the real repository
HTTP payloads, local outbox recovery, tracking lifecycle and unchanged history
widgets. These do not establish production Firebase deployment, production-data
migration, PostgreSQL execution of the historical lookup, GPS accuracy,
terminated-app execution, gateway buffering or physical-cane behavior.

## Implementation files

- Flutter model: `lib/models/breadcrumb_trip.dart`.
- Flutter storage/lifecycle: `lib/services/breadcrumb_repository.dart`,
  `breadcrumb_recorder.dart`, `breadcrumb_service.dart`, `live_location_service.dart`.
- Existing UI data bindings only: `lib/widgets/dashboard_widgets/recorded_reports.dart`,
  `lib/widgets/track/breadcrumb_trip_tile.dart`.
- Backend routes: `app_mobile_backend/routes/pairing.js`, `routes/navigation.js`.
- Backend services: `app_mobile_backend/services/tripStore.js`, `caneGps.js`,
  `locationRemoval.js`, `dashboardService.js`, `firebaseAdmin.js`.
- Operations: `app_mobile_backend/scripts/tripHistory.js`.
- Firebase: `firebase/database.rules.json`, `breadcrumbs.rules.json`,
  `firestore.rules`, `firestore.indexes.json`, `deploy.json`.
- Tests: `test/breadcrumb_repository_test.dart`, `breadcrumb_recorder_test.dart`,
  `live_location_ownership_test.dart`; `firebase/pairing.rules.test.mjs`;
  `app_mobile_backend/test/trip_store.test.js`, `cane_gps.test.js`,
  `location_removal.test.js`, `dashboard.test.js`, `firebase_admin_config.test.js`,
  `helpers/memoryFirestore.js`.

Pre-existing session/tracking work was preserved; the UI layouts and project
skills were not redesigned or replaced.

Verification performed locally:

- Changed Dart files formatted; `flutter analyze` reports only the existing
  withOpacity deprecation and super-parameter notices in unrelated widgets.
- A 34-test Flutter storage/history/navigation regression run passed, followed
  by passing 21-test lifecycle/logout and 8-test final deletion/retention runs.
- `node --test test/trip_store.test.js test/cane_gps.test.js
  test/location_removal.test.js test/dashboard.test.js
  test/firebase_admin_config.test.js`: 21 tests passed with synthetic stores.
- `npm test` in `firebase`: 8 Realtime Database emulator rules tests passed.
  Missing locked test dependencies were installed using `npm ci --ignore-scripts`.
- JavaScript syntax checks and `git diff --check` passed.
- Production migration/deployment, Firestore emulator transactions, execution
  against PostgreSQL, physical GPS, firmware and gateway connectivity were not
  verified.
