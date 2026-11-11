# PostgreSQL permanent storage and RTDB live state

This replaces the earlier Firestore-history architecture. Normal collection,
history reads, reports, deletion and retention no longer access Firestore.
Firebase Authentication and the existing UI/API models are unchanged.

## Data ownership

| Data | Storage |
| --- | --- |
| GPS trip summaries and recorded GPS points | PostgreSQL `akay_persistent_records` |
| History/account deletion tombstones and retired pairing archives | PostgreSQL `akay_persistent_records` |
| Users, profiles, health information, current pairing/consent, devices, assignments | Existing PostgreSQL tables |
| Sensor readings, permanent alerts, audit logs, notification delivery jobs, navigation sessions | Existing PostgreSQL tables |
| Latest phone GPS | RTDB `phone_location/{uid}` |
| Latest cane GPS | RTDB `cane_location/{uid}/{assignmentId}` |
| Latest cane battery/status | RTDB `cane_status/{uid}/{assignmentId}` |
| Current urgent SOS/motion signal | RTDB `urgent_signals/{uid}` |
| Pending caregiver destination | RTDB `destination_assignments/{uid}` |
| Immediate sharing-disable flag | RTDB `deleted_location_accounts/{uid}`; durable tombstone is PostgreSQL |

RTDB holds replaceable live state, not an accumulating history. Urgent signals
reference a PostgreSQL alert ID and its active/resolved state; permanent alert
records and push delivery remain PostgreSQL. The signal is a hint to refresh the
existing consent-checked alert API, not a replacement for the permanent feed.

The existing backend worker now also projects committed cane status and SOS/motion
signals into RTDB every three seconds. Unchanged revisions are not rewritten;
publication failures retry on the next pass without rejecting committed readings
or blocking the existing push dispatcher. This does not change the current app's
alert polling/UI or claim subsecond end-to-end notification delivery. No direct
caregiver Firebase permissions are added: protected APIs retain consent checks.
Old status records from ended assignments must not be treated as current; current
assignment IDs and capture age remain required when consuming live status.

## PostgreSQL representation

Migration `007_postgres_history.sql` adds a JSONB-backed record table. Account,
trip, point and archive records have distinct collection paths. Each GPS point
is its own row, preserving the existing stable sequence and trip IDs. Rows store
owner UID, parent path, data and update time. Indexes support parent lookup,
time/cursor pagination, ordered points, owner lookup and retention.

The private `postgresRecordStore` adapter preserves the existing repository
operations while executing parameterized SQL. Transactions serialize writes by
owner with a PostgreSQL advisory lock. The existing trip service retains capture
validation, explicit cane start/point/end ordering, deterministic source identity,
upload retries, server summaries, tombstones and retention. It uses an explicit
injected store in tests and PostgreSQL by default. No automatic Firestore fallback
or dual write is enabled, so Firestore quota exhaustion cannot interrupt normal
history persistence after cutover.

## Deployment and existing data

No production SQL, Firebase data migration or deployment was performed during
implementation. The repository migration runner is review-only by default.
Run from `app_mobile_backend` using the approved target environment:

```text
node scripts/migratePairing.js --migration=007_postgres_history
```

After reviewing the printed SQL, set `AKAY_MIGRATION_APPROVED=yes` in the operator
environment and apply it:

```text
node scripts/migratePairing.js --migration=007_postgres_history --apply
```

The new table grants DML to `akay_runtime` if that existing privilege group is
present. Verify the deployed API role has access. Do not enable schema bootstrap
or use an administrator credential as the API runtime account.

For data already stored in Firestore:

```text
node scripts/importFirestoreHistory.js USER_UID
node scripts/importFirestoreHistory.js USER_UID --apply
```

Dry run validates without SQL writes. Apply copies summaries, every ordered point,
deletion tombstones and retired grant archives into PostgreSQL. Firestore Timestamp
values become the existing UTC millisecond API values. Each trip imports in one
SQL transaction. Fingerprints make identical retries safe and conflicting IDs fail
closed; capture and ownership validation precede writes. Source Firestore records
are retained, and aggregate logs contain no account IDs or GPS coordinates.
The importer still needs source Firestore read quota: if reads are exhausted,
wait for quota availability before importing. Normal runtime does not need it.

For older RTDB history and retired links/grants:

```text
node scripts/migrateFirebaseStorage.js USER_UID
node scripts/migrateFirebaseStorage.js USER_UID --apply
node scripts/migrateFirebaseStorage.js USER_UID --apply --cleanup
```

The destination is now **PostgreSQL**, including metadata archives. Cleanup is
optional and must follow verified cutover; it checks every capture and removes
only an unchanged legacy source using an RTDB transaction. Active legacy
recordings are skipped, never silently completed or deleted. Retired grant
archives are not active consent. Unknown RTDB nodes require reconciliation.

Back up both sources before migration. Stop the old Firestore history writer and
drain/reconcile its pending snapshots before the final import, then deploy the
PostgreSQL-backed backend. Device outboxes keep their existing IDs and can replay
through the unchanged API after cutover. Validate navigator, caregiver and revoked
caregiver history against synthetic staging accounts before enabling the rollout.
There is no claim of a zero-downtime cutover between concurrently writable stores.

Deploy `firebase/deploy.compat.json` while old RTDB-only clients still need owner
history reads. Deploy final `firebase/deploy.json` only after retiring those
readers. Final RTDB rules reject legacy history writes/reads; new status/signals
are server-only, as are Firestore archives/history. Firestore remains an optional
legacy **source** for the operator import tool. It is not needed for new history.

After parity and rollback backups are confirmed, retire old Firestore writers and
retain/delete source backups under your approved policy. The import command never
deletes Firestore records. Do not revert to an old Firestore-backed backend after
collecting new PostgreSQL history without reconciling those newer records.

## Verification

Tests use only synthetic data. Real PostgreSQL tests use an isolated localhost
cluster on port 55449 with user `akay_test`, database `postgres`, no application
credentials, and a unique temporary schema. Start a disposable cluster with those
settings, then run:

```text
node --test app_mobile_backend/test/postgres_history.test.js
```

`npm test` in `firebase` additionally requires that isolated cluster and starts
demo RTDB/Firestore emulators. It validates RTDB-to-PostgreSQL verified cleanup,
Firestore Timestamp import into PostgreSQL, retained source data, live GPS
publication and denied direct client history access. Production data movement,
device GPS, hardware connectivity and notification latency remain separate
deployment/device checks.

Validated for this change: 55 backend tests (including six real PostgreSQL
tests), 12 combined Firebase/PostgreSQL emulator tests and 10 Flutter history/live
transport contract tests passed. JavaScript syntax checks and `git diff --check`
passed. No Dart implementation changed, so full Flutter analysis was not rerun
for this backend-only change. No production database or live device was used.
