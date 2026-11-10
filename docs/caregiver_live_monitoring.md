# Caregiver live location and recorded routes

This change connects data to the existing caregiver dashboard, tracking map and
recorded-route modal. No widget layout, color, typography, card, control or
navigation design changes are made. Authentication, profiles, pairing decisions,
raw sensor telemetry and alerts retain their existing responsibilities.

## Live phone publication

Flutter now uses authenticated
`PUT /api/v2/navigators/{firebaseUid}/phone-location`. Its payload retains the
original timestamp, coordinates, phone source and optional speed/heading/accuracy.
The request UID must match the verified Firebase token. The backend rechecks the
PostgreSQL navigator profile under a shared row lock, rejects deleted accounts
and invalid/stale samples, and transactionally writes the unchanged
`phone_location/{uid}` RTDB path. Server receipt time is separate from capture.

This removes the dependency on deployed client-write rules without opening any
Firebase rules. Service credentials remain private backend configuration. The
server service account must have RTDB write access. An older running backend
must be restarted/deployed to expose the new endpoint.

The client retains only the newest pending live fix during slow requests. The
durable breadcrumb outbox is independent and never discarded by live coalescing.
Pausing calls DELETE on the same endpoint with the original `stoppedAt` time.
A coordinate-free timestamp watermark prevents delayed fixes from reviving a
paused source and delayed stops from clearing a newer resumed sample. Account
location removal takes matching exclusive profile/device locks before clearing
Firebase so in-flight live writes cannot resurrect removed locations.

## Caregiver read policy

- Preserve fresh phone GPS as the first choice.
- Otherwise use the freshest valid cane GPS from a current assignment and current
  navigator ownership. Device, assignment and capture time must match.
- Otherwise show a valid source as last known. History-only coordinates are
  explicitly non-live, even when their capture timestamp is recent.
- Use the existing 45-second capture freshness and 30-second future-skew bounds.
  Cane end/disconnected events are not advertised as live tracking. Fresh cane
  updates do not depend on active phone-app presence.
- Query recorded geometry for the selected source; cane queries also filter by
  physical device and assignment. Never splice phone and cane route points.
- Do not reuse an old completed trip as a new live route, or an active history
  segment more than the existing 90-second gap threshold behind the live fix.
- Monitoring reads have deadlines and preview at most the latest 500 points.
  Full recorded-trip review remains available in the existing route modal.
  Missing or slow history must not hide a working live marker.

Active PostgreSQL consent is checked before and after monitoring/history reads.
The existing two-second dashboard polling, shared subscriptions and error states
remain. Errors/revocation invalidate displayed remote data through existing
handlers. Source, assignment and recorded-trip metadata travel through the
existing DashboardSnapshot; mismatched response UIDs/history owners fail closed.
There is no new direct caregiver Firebase listener or editable consent mirror.

## Rollout and panel test

1. Restart/deploy the updated `app_mobile_backend` and hot-restart Flutter using
   the same working authenticated API address.
2. Deploy the added cane-history composite index in
   `firebase/firestore.indexes.json` through the existing reviewed configuration
   and wait until ready. This index is only needed for cane history filtering.
3. Use synthetic navigator/caregiver accounts with accepted active consent.
   Obtain a valid location on the navigator phone and record without a destination.
4. Confirm RTDB `phone_location/{uid}` receives capture and server receipt times.
   The caregiver's existing marker should follow that navigator; recorded and
   planned lines remain their existing separate map layers.
5. Disconnect/reconnect networking. Confirm last-known status after freshness
   expires and recovery to a new capture without a backlog of old live updates.
6. Pause/resume; verify late writes/stops cannot reverse the current sharing state.
   Verify completed history remains readable through the existing modal.
7. Switch between linked navigators. Verify each marker, trail and history belongs
   to the selected UID. Revoke consent while viewing: future reads must fail and
   remote data must disappear. An unrelated caregiver must be denied.
8. For cane validation, use the existing independently authenticated `/api/v2/gps`
   session protocol. When phone GPS is stale, verify current-assignment cane GPS
   and its own recorded path. Delayed old-assignment readings must not become a
   new owner's live marker. Physical hardware/gateway networking is still needed.

## Evidence boundaries and affected code

Tests cover publication, reversed delivery, stop/resume ordering, slow networks,
source/assignment matching, bounded reads, identity switches, consent revocation,
caregiver map bindings and the existing recorded-route modal. The added RTDB
integration test uses the real Admin SDK against a demo emulator with synthetic
coordinates and a simulated PostgreSQL guard. Other service tests use synthetic
storage/HTTP boundaries. Production IAM, deployed PostgreSQL locking, Firestore
index readiness, physical GPS, caregiver devices and firmware remain unverified.

Primary code: `lib/services/live_location_service.dart`, `dashboard_service.dart`,
`breadcrumb_repository.dart`, `lib/models/dashboard_snapshot.dart`; backend
`services/phoneLocation.js`, `monitoringService.js`, `dashboardService.js`,
`tripStore.js`, `locationRemoval.js`, `routes/pairing.js`; Firestore index config.
No UI widgets or page layouts were modified for this task.
