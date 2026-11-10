# Caregiver cane alerts and emergency response

## Implemented scope

The existing Notifications cards and badge now use a permission-checked backend
feed across all currently linked navigators. SOS and motion incidents identify
the navigator by the registered display name, with a linked-navigator fallback.
Motion is labelled **possible fall or impact**, never a confirmed accident.
The new response dialog uses the existing app theme; unrelated page designs,
navigation, breadcrumb recording, profiles and raw obstacle/battery alerts are
not redesigned. The navigator's existing phone SOS control is not changed.

Read status is personal to the caregiver. Acknowledge and Resolve/False alarm
are persistent incident states visible to all authorized caregivers. Opening,
swiping or clearing notifications cannot resolve an incident. Unresolved cane
incidents cannot be dismissed. Resolution records a server timestamp and actor,
and an audit event. The first resolution is preserved on repeated requests.
This does **not** silence the physical cane: no unverified hardware command is
sent. A separate firmware command/acknowledgement protocol would be required.

The dialog displays detection/receipt times and the optional event coordinates
with their capture time. Missing coordinates are stated explicitly. These are
the location attached to the incident, not an assertion of current position.

## Deployment required before app/device acceptance

1. Review `app_mobile_backend/database/migrations/006_emergency_workflow.sql`.
   Apply through the existing migration mechanism to the intended database,
   after the existing pairing/integrity migrations and runtime-role setup.
   From `app_mobile_backend`, review the script output first:

   ```powershell
   node scripts/migratePairing.js --migration=006_emergency_workflow
   # After reviewing the target and SQL:
   $env:AKAY_MIGRATION_APPROVED = 'yes'
   node scripts/migratePairing.js --migration=006_emergency_workflow --apply
   Remove-Item Env:AKAY_MIGRATION_APPROVED
   ```

   This task has NOT applied migrations to the application/production database.
   Run migrations using the migration identity, not a restricted runtime user.
   If the runtime role is created later, reapply 006 to grant its new privileges.
2. Restart/deploy the backend. Its three-second worker derives durable delivery
   jobs from committed SOS/motion alerts. Missing migration/configuration emits
   a fixed, throttled warning rather than exposing raw errors or credentials.
3. Enable the Firebase Cloud Messaging HTTP v1 API and give the private backend
   service account permission to send messages for the same Firebase project.
   Existing private Admin SDK credential configuration is reused; never put it
   in Flutter, browser files, or cane firmware.
4. Run `flutter pub get` and fully rebuild/restart the app for Firebase Messaging.
   On the caregiver Notifications page, use **Notification actions → Enable
   push notifications**. Permission denial does not disable the in-app feed.
   Android uses the high-importance `akay_emergencies` notification channel;
   device settings may silence or block it.
5. For Chrome, use localhost for development or HTTPS for deployment. Set the
   project's **public Web Push certificate/VAPID key** (Firebase project settings
   → Cloud Messaging → Web configuration):

   ```powershell
   flutter run -d chrome --dart-define=FCM_WEB_VAPID_KEY=YOUR_PUBLIC_VAPID_KEY
   ```

   `web/firebase-messaging-sw.js` uses the existing public Firebase web app
   configuration and SDK 12.18.0, matching the installed Firebase Core Web SDK.
   Include the service worker in web deployments. If changing Firebase projects,
   update both `firebase_options.dart` and this worker's public configuration.
6. iOS additionally requires an Apple provisioning profile with Push Notifications
   capability and an APNs key/certificate uploaded to Firebase. The repository
   includes the entitlement and remote-notification background mode; signing,
   release provisioning and delivery must be verified on a Mac/physical iPhone.

See [Firebase's Flutter delivery setup and lifecycle documentation](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages).
OS permission, connectivity, platform restrictions and provider availability
affect delivery; an FCM acceptance receipt is not caregiver acknowledgement.

## Cane/gateway contract

Use the existing authenticated `POST /api/v2/telemetry` with the provisioned
`Authorization: Device <device UUID>.<machine secret>` header. Never use a mobile
user token or embed backend service credentials. Resolve the current assignment
through the existing hardware protocol before transmitting.

Example synthetic body (replace assignment and capture time with actual values):

```json
{
  "assignmentId": "00000000-0000-4000-8000-000000000001",
  "sequence": 17,
  "sampledAt": "2026-11-10T05:00:00Z",
  "alert": "motion",
  "eventId": "boot-7-impact-3"
}
```

Use `alert: "sos"` for the manual button and `alert: "motion"` for a possible
fall/impact. `eventId` must remain stable for every transmission of the SAME
incident, including retries using a new transport sequence. Allocate a NEW ID
for a genuinely new incident. IDs allow 1–128 ASCII letters/digits/underscores/
hyphens and are scoped to the device and assignment. Legacy packets without
eventId are accepted for compatibility but cannot deduplicate different sequence
numbers representing the same physical incident. Exact sequence replays retain
the existing rejection behavior and never insert a second alert.

Coordinates and battery are optional. Existing timestamp/assignment/sequence
checks remain: capture must belong to the current assignment, be no more than
five minutes old and at most 30 seconds in the future. Firmware needs a reliable
clock. The app does not implement accelerometer classification or assume a cane
can communicate without a network/gateway path.

## Persistence, access and retry behavior

- `GET /api/v2/alerts` is caregiver-only, checks current active consent in SQL,
  and returns up to 200 alerts with unresolved incidents first. No feed is cached
  across accounts. The open app refreshes every three seconds; read failures clear
  remote data and show an explicit retry state.
- `POST /api/v2/alerts/{id}/respond` accepts `read`, `dismiss`, `acknowledge`,
  `resolve` and `false_alarm`. Consent is locked through each response transaction.
- `PUT`/`DELETE /api/v2/push-token` binds/removes only the authenticated caregiver's
  device registration. Token rotation/rebinding is supported. Account changes
  clear the app feed, discard in-flight responses and delete the FCM registration.
  Authorized registrations retry when initial network setup fails.
- Durable jobs select only current authorized caregivers, unresolved incidents
  from the last 24 hours, and tokens still owned by that caregiver. Independent
  devices each receive a job. Retries back off, with at most 12 attempts per job;
  provider-invalid tokens are removed. Provider receipt waits are bounded.
- Push is at least once: a crash/timeout after provider acceptance but before the
  database receipt may cause another push. A stable notification tag collapses
  duplicates where supported; it never creates another database incident.
  Provider-side pending notifications expire after five minutes; the persisted
  in-app incident is the authority for its current response status.
- The feed persists beyond the push retry window. A caregiver opening the app
  can still see unresolved incidents even if no push receipt was obtained.
- Read/dismiss states are personal; acknowledge/resolve states are shared. Audit
  records and original cane/navigator/assignment attribution are preserved.

## Panel/device acceptance steps

1. Link a caregiver to two synthetic navigator accounts with active consent and
   assign different authenticated canes. Register the caregiver notification token.
2. Send an SOS from the first cane and motion from the second. Verify each card
   and push identifies the correct navigator and incident type; motion must say
   **possible** fall/impact. Ordinary movement should not be transmitted as an
   incident: threshold/debounce classification belongs to the firmware.
3. Repeat each incident using its original eventId and a fresh sequence. Confirm
   one database incident and one delivery job per token, not additional cards.
4. Open/read/clear the notification list. Confirm the incident remains unresolved.
   Acknowledge it, restart the app and verify the acknowledged state persists.
   Resolve or mark false alarm; verify all linked caregivers see the shared state.
5. Revoke consent and verify future reads/responses/push job selection are denied.
   Switch accounts on the same device: the previous account's feed must disappear.
6. Test a minimized/locked caregiver device, notification permission denial,
   provider failure/retry, backend restart and temporary network loss. A provider
   send receipt must not be displayed as proof that a caregiver responded.
7. Confirm resolving the app incident does not claim to silence the physical cane.

## Local evidence

Verification completed for this change: 62 backend regression tests passed;
the subsequent focused emergency/runtime-role checks also passed. All 28 focused
Flutter notification, session and caregiver tracking tests passed. Flutter
analysis reports only the two existing notices in `blob_painter.dart` and
`gabay_page_route.dart`; changed Dart files were formatted.
The standard JavaScript web build succeeded. Its optional Wasm dry run reported
existing `flutter_tts` interop warnings; no unrelated TTS code was changed.

Synthetic PostgreSQL tests cover event attribution/deduplication, role/consent
checks, durable response/read state, dismissal restrictions, provider retry,
invalid token cleanup and revoked-recipient exclusion. Push sends in these tests
use a fake provider; they do not contact real caregivers. Flutter tests cover
two navigator identities, account-reset races, unconfirmed responses and the
existing card/dialog interaction at enlarged text size.

Real firmware sensor thresholds, machine-secret provisioning, deployed migration,
FCM/APNs credentials and physical-device delivery remain deployment/device checks.
