# Device_Location cane signals

The backend reads `Device_Location/{registered cane serial}` using the existing
Firebase Admin instance, database URL and credentials. Flutter continues using
its existing authenticated APIs. This feature does not change Firebase rules,
connection settings, GPS routing, or write to the firmware record.

Confirmed firmware fields:

| Field | Meaning |
| --- | --- |
| `unsafe` | Boolean SOS; true creates an immediate incident |
| `fallAlert` | Boolean fall signal; true starts a three-second cancellation window |
| `batteryLevel` | Numeric fraction (0–1) or percentage (above 1–100); `0.50391` displays as 50%, `81.07422` as 81% |
| `latitude`, `longitude` | Optional coordinates attached to the incident |

The device child key must match an existing registered cane serial, with current
ownership and an active navigator assignment. Unregistered records are not
assigned to an arbitrary navigator. Normal movement is not inferred from a false
fall flag. Missing/invalid data stays unavailable.

Dashboard and device-detail battery values are read directly from
`Device_Location/{serial}/batteryLevel` on each API refresh using the existing
Firebase Admin connection. They do not fall back to saved PostgreSQL battery
readings. The dashboard refreshes every two seconds; read failures, timeouts or
invalid/missing values produce an unavailable battery. Battery parsing is
independent of SOS/fall fields. The latest active cane assignment is the
dashboard's default battery source; device details read each assigned cane.

Read-only source verification:

```powershell
cd app_mobile_backend
node scripts/checkCaneBatteryReadOnly.js 00001
```

A live read on 16 November 2026 returned `81.07422` from the existing configured
Firebase database, converted to 81%. This is a point-in-time read, not proof of
physical battery calibration or continuous firmware transmission. No Firebase
values or connection settings were changed. Restart/deploy the backend to use
the direct battery reads; no new migration is needed for this battery fix.

Battery-fix verification: 22 focused backend tests and 14 Flutter dashboard
tests passed. Backend tests confirm that current Firebase values override saved
SQL values, subsequent reads reflect changes, and failures do not reuse an old
percentage. Real Firebase access was verified read-only for the battery field;
the deployed app screen and physical battery calibration were not verified.

## Current SOS and fall status

The dashboard also reads `Device_Location/{serial}/unsafe` and `fallAlert`
directly on each refresh using the same assigned-cane mapping and existing
Firebase connection. It does not obtain current SOS/fall flags from saved SQL
telemetry. A missing, invalid or failed field read produces an unknown flag,
not a reused false/true value from a previous read. Signal reads are independent
and do not synthesize fall detection from ordinary GPS movement.

Current status and incident history are separate: the running backend's existing
Firebase value listener generates immediate SOS incidents and delayed fall
incidents, and PostgreSQL retains notifications after the flags clear. The
three-second physical-reset cancellation window, repeat-event latching and
personal caregiver deletion remain in place. Reading a current flag via the
dashboard does not itself insert alerts or bypass that window.

Read-only diagnostics (neither command sends notifications):

```powershell
node scripts/checkCaneSignalsReadOnly.js 00001
node scripts/checkCaneAlertReadinessReadOnly.js 00001
```

On 16 November 2026, live Firebase reads confirmed both fields exist as Boolean
values and both were false at the time of the check. Read-only backend checks
also confirmed the active assignment and required incident/state tables. No
production flags were changed, no real alert was triggered, and physical cane
reset/push delivery is not established by these read-only checks. Restart/deploy
the backend for the current-status change; no new migration is required when
the existing emergency and device-location migrations are already applied.

Current-status verification passed 23 focused backend tests, five disposable
PostgreSQL emergency integration tests, and 14 Flutter dashboard/notification
tests. Synthetic true/false transitions covered immediate SOS, fall reset before
three seconds, sustained fall escalation, repeated-signal deduplication, restart
latching and caregiver-specific notification persistence/deletion. Push delivery
in integration tests used a fake provider rather than real caregivers.

## Alert lifecycle

1. A false-to-true SOS signal creates one persisted SOS incident immediately.
2. A true fall signal starts a three-second backend observation window. A
   physical reset must clear `fallAlert` to false to cancel the pending alert.
3. At the deadline, the backend reads the record again. If the fall signal still
   remains true, it creates a possible fall/impact incident. Ordinary continuing
   true updates do not produce duplicates. A later false-to-true transition arms
   a new incident.
4. State, sensor readings and incidents commit together in PostgreSQL. Restarting
   the backend does not repeat a latched incident. Pending unnotified falls get a
   fresh three-second cancellation window after restart or a failed read.
5. Existing consent-checked caregiver feeds and push delivery jobs use these
   incidents. Reading, acknowledging, resolving, and later false sensor values
   do not delete a notification. **Delete notification** or **Clear all** records
   dismissal only for that caregiver; other caregivers retain their copies.
   Deleting does not resolve the incident or silence hardware. Dismissed copies
   are excluded from subsequent push jobs/retries for that caregiver.

The feed no longer hides old cane incidents behind a 200-item cap. Transient
read failures retain previously loaded incidents with an error/retry message.
Account changes and explicit authorization denial clear protected in-memory data.

## Timestamp and offline limits

The provided firmware schema has no timestamp, sequence or event identifier.
The UI therefore labels battery and sensor flags as last reported, and incident
times/coordinates as **database observed**, not actual hardware capture time or
proof of a fresh GPS fix. A false-to-true cycle occurring entirely while the
backend is offline cannot be reconstructed from the final Boolean value. The
three seconds begin when the running backend observes the fall; physical
detection-to-push time also includes network, storage and push-worker delays.
Push receipt does not prove caregiver acknowledgement.

No code remotely resets the sensor. Physical-button behavior must be verified
on the cane. Existing caregiver location tracking remains the monitoring path;
incident coordinates are a snapshot, not guaranteed current position.

## Deployment

Review and apply `008_device_location.sql` through the existing migration script,
after the pairing/integrity and emergency migrations. Review against the intended
target before using its explicit apply gate:

```powershell
cd app_mobile_backend
node scripts/migratePairing.js --migration=008_device_location
# After approving the intended database and SQL:
$env:AKAY_MIGRATION_APPROVED = 'yes'
node scripts/migratePairing.js --migration=008_device_location --apply
Remove-Item Env:AKAY_MIGRATION_APPROVED
```

Reapply 008 after creating a runtime privilege role if necessary. The migration
adds durable RTDB signal state and distinguishes RTDB observations from existing
machine-authenticated readings; hardware ingestion still requires a credential.
Deploy/restart the backend and rebuild the app. Existing FCM permission/token,
APNs, and web-push setup remains necessary; see `caregiver_emergency_workflow.md`.
No production migration, firmware write, Firebase rule change or real caregiver
push was performed during local implementation.

## Acceptance

Use synthetic assigned canes and consenting test accounts. Check live battery
changes, immediate SOS, reset before three seconds, a sustained fall, repeated
true updates, backend restart, a second incident after reset, personal deletion
with two caregivers, revoked consent, and real device push delivery. Firmware
must publish the reset promptly. Local mocked RTDB and isolated PostgreSQL tests
do not verify physical hardware, deployed Firebase access, GPS or FCM delivery.

## Local verification

- 15 focused Flutter notification/dashboard tests passed, including changing
  battery/sensor values, personal deletion, transient outage retention, account
  reset races, both themes, and enlarged text in the navigation status view.
- 19 focused backend parsing/dashboard/monitoring tests passed. Five affected
  PostgreSQL integration tests passed, including stream ingestion, three-second
  fall cancellation/escalation, restart latching, consent, and runtime permissions.
- `flutter analyze` reported only the existing informational notices in
  `blob_painter.dart` and `gabay_page_route.dart`. Changed Dart files were formatted.
- The broader backend suite passed 26 of 27 tests; its existing HTTP history
  fixture returns 503 where it expects 200. The original test reproduces this
  failure. The broader layout run also reproduces existing two-pixel and
  27-pixel statistic-card overflows at 2× text scale with the original dashboard
  file. These unrelated implementations were left unchanged.

Tests use synthetic RTDB callbacks, a disposable localhost PostgreSQL cluster
and fake push delivery. They do not contact the production Firebase database or
real caregivers. Deployment and physical cane acceptance remain outstanding.
