# patientmedication health-status persistence

Source implementation: `app_mobile_backend/`. No migration runs on startup.
Existing `/api/profile`, authentication, pairing, routing, and other tables are
unchanged. `backend_patch/` is a separate older deployment bundle; use the new
health files from `app_mobile_backend/` for this change.

## Migration and deployment

`database/migrations/006_patient_health_status.sql` removes `medicine_name`,
`dosage`, and `schedule`, adding nullable `height` (cm), `weight` (kg),
`medical_conditions`, `allergies`, and `emergency_contact_phone`.

Existing medication rows, IDs and patient foreign keys are preserved. Their old
values are copied into each row's `legacy_medication` JSONB column before removal.
Those historical rows have `health_status_record=false`. A partial unique index
allows one new current health row per patient without merging or deleting legacy
records. The archive is never returned by the new API.

The migration is transactional and rerunnable, with a 5-second lock timeout and
60-second statement timeout. Unexpected dependencies abort the transaction; no
CASCADE is used. Take an access-controlled recoverable backup and confirm the
intended database before application. Do not put patient-data backups in Git.

From the backend directory configured for the intended database:

```powershell
node scripts/migrateHealthStatus.js
node scripts/migrateHealthStatus.js --apply
```

The first command only prints the SQL. The second executes it using that backend's
DB_* configuration. Alternatively run the SQL in pgAdmin's Query Tool for the
intended database and refresh the table's Columns tree.

Deploy these backend files and restart/redeploy that backend:

- `models/patientHealthStatus.js`
- `controllers/patientHealthStatus.js`
- `routes/healthStatus.js`
- The single new `/api/health-status` registration in `server.js`

No replacement of other backend modules is necessary. Missing health schema
returns 503 only from this endpoint and does not prevent existing app startup.
The migration grants column-scoped permissions on this table to `akay_runtime`
only if that existing group is present. Custom runtime roles need equivalent
permissions; archived medication content is excluded from the new column grants.

## API contract

`GET /api/health-status` and `PUT /api/health-status` use existing Firebase Bearer
authentication and account middleware. The actor's user ID selects its existing
`patientprofiles` row. Caller-selected patient/user IDs are rejected; editing a
linked patient's record is not added. A missing patient profile returns 409 on
save, without modifying any other table.

GET returns `{"health_status":null}` before the first health save. PUT accepts
only the five snake_case fields above. Height and weight are JSON numbers,
positive and below 1000, with at most two decimal places. Omitted fields retain
previous values; null explicitly clears them. Text fields also support empty
strings. A patient-row lock serializes partial merges and first writes. Responses
return the committed health row under `health_status` and disable caching.

## Flutter integration

`PatientHealthStatus` and `HealthStatusService` map directly to these columns.
Information & Health Status fetches the endpoint and saves through its editor.
It retains input on failure and confirms returned values before reporting success.
Reopening fetches persisted data; account changes invalidate outstanding requests
and editors. Measurements/contact phone are not inferred from unrelated fields.

Before the first health record exists, the existing patient-profile medical
conditions/allergies initialize the editor. The first health save copies those
visible values into this table only. Later reads use the health record, including
explicit clears. The separate Edit Profile page retains its existing behavior and
does not automatically synchronize its original health fields with this table.
The caregiver name continues to come from the existing emergency-contact field.

## Verification versus deployment

Synthetic local PostgreSQL tests cover history preservation, migration reruns,
owner isolation, actual save/fetch, partial merges, clearing, concurrent writes,
and unchanged unrelated records. Existing profile/auth/routing regressions are
also run. Flutter tests cover API mapping, save/reload, failed/unconfirmed saves,
account changes and accessible layouts. No Render migration, backend redeployment,
or device-to-Render validation is established by these tests.
