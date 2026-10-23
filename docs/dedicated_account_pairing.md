# Accessible dashboard pairing

Both home dashboards now include a pairing card immediately below the header.
Navigators select **Alphanumeric code** or **QR code**, authorize access with the
labelled consent control, and request their code. Codes are large, high contrast,
copyable and available through the existing Gabay read-aloud service. Caregivers
choose **Add / Pair New Navigator** and enter the code or use the in-app camera.
Each paired Navigator has a named status card; existing access management remains
available from the same dashboard card.

## New automatic flow

1. `POST /api/v2/pairings/codes` requires a verified Navigator profile,
   `authorize_pairing: true` and `pairing_method: alphanumeric | qr_code`.
2. The backend registers an account-owned app-instance UUID when none is supplied.
   The mobile client stores that returned UUID per Firebase account for reuse.
   This identifier does not claim ownership of a physical smart cane.
3. A cryptographically random six-character code uses
   `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`. A unique database key and bounded collision
   retries prevent duplicate codes. Generation allows ten requests per hour per
   Navigator. Codes expire after ten minutes and are usable once. Regenerating
   for the same app instance closes that instance's earlier pending code.
4. QR payloads use `akay://pair?code=ABC234`. The caregiver scans them with
   **Scan Navigator QR** in AKAY. Code entry and camera capture submit the same
   token with their actual method to `POST /api/v2/pairings/redeem`.
5. Redemption is transactional: it assigns the authenticated caregiver, activates
   the pairing and existing monitoring connection, and records `paired_at`.
   The Navigator authorized that access before generating the code, so this new
   flow does not require another acceptance step. Attempts are limited to five
   per account and thirty per IP per minute. Invalid, expired, replaced and used
   codes cannot grant access; concurrent redemption has a single winner.
6. The caregiver sees the result immediately after the mutation. The other
   dashboard updates through the existing five-second connection subscription,
   without manual refresh. Screen-reader live regions and text status badges
   accompany confirmation messages. This is polling, not a websocket push.
7. Existing revocation updates the new record to `unpaired` and records
   `unpaired_at` through a pairing-specific database trigger. History remains.

Previously issued invitations retain their existing manual-consent behavior.
Authentication, profile editing and background tracking services are unchanged.

## Database mapping

The configured database already had an empty `pairings` table with these nine
columns. Its old NOT NULL caregiver rule and physical-cane foreign key prevented
creation of a pending app invitation. Migration 005 adapts only pairing storage:

| Field | Meaning |
| --- | --- |
| `pairing_id` | UUID primary key |
| `device_id` | Registered app-instance UUID |
| `vi_user_id` | Navigator's `Users.user_id` |
| `caregiver_id` | Caregiver's `Users.user_id`; null before redemption |
| `pairing_code` | Unique six-character generated invitation |
| `pairing_method` | `qr_code` or `alphanumeric`, updated from the actual redemption method |
| `status` | `pending`, `active`, or `unpaired` for the new flow |
| `paired_at` | Set only when access is established |
| `unpaired_at` | Set when access/code is terminated; otherwise null |

`pairing_app_instances` holds the app registration and enforces a composite
device/owner foreign key. `patientprofiles` remains linked through its existing
`user_id`; no profile field, table or patient relationship is rewritten.
Legacy uppercase pairing methods/statuses are normalized within `pairings`;
legacy NFC/Bluetooth and expired values remain representable. Existing timestamp
types are preserved. No personal records existed in the target pairings table
when its migration was applied.

Migration 004 installs only the four missing support tables used by the existing
connection/consent backend: invitations, connections, rate limits and audit
events. The broad physical-device migration is not applied. Migration 005 adds
the dedicated pairing logic and revocation bridge. Both are included in the
existing reviewed migration runner and patch manifest and have been applied to
the configured backend database. The AKAY backend has been restarted.

`GET /api/v2/pairings` returns only the caller's pairing metadata and excludes
codes. Codes are returned only to the generating Navigator; no new logs contain
invitation values. Status listings continue to use the existing connection API.

## Validation and device checks

Backend tests use generated schemas and synthetic users on the dedicated local
PostgreSQL test cluster. They cover fresh setup, adaptation of the original
physical-device schema, reapplication, app ownership, code replacement/expiry,
single use/concurrency, immediate activation, method tracking, multiple Navigators,
patient linkage, revocation timestamps and legacy invitation compatibility.
Existing authorization, device and profile regression tests also pass.

Flutter tests cover manual/QR parsing, explicit generation authorization, large
text in both themes, copy controls, scanner results, immediate status and
multiple Navigator cards. Physical camera capture and signed-in two-phone pairing
have not been exercised. Rebuild the app to include the new camera plugin and
permission declarations. Manual entry remains available when a camera is denied
or unsupported. No authenticated writes to real user pairing records were made
during verification.

Final checks: 37 focused Flutter tests and 25 PostgreSQL/backend tests passed.
Flutter analysis reports only the three existing unrelated informational findings.
The Android debug build was attempted but failed at manifest merging: the existing
debug manifest declares `usesCleartextTraffic=true`, while the existing main
manifest declares it `false`. That unrelated network configuration was preserved
under the requested scope restriction. A native APK and physical-camera behavior
are therefore not verified by this change.

QR implementation references: [QR.Flutter](https://pub.dev/packages/qr_flutter)
and [Mobile Scanner](https://pub.dev/packages/mobile_scanner).
