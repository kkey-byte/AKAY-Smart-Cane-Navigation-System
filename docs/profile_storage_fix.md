# Profile storage configuration fix

The original configuration issue was that the database had both `patientprofiles`
and `"PatientProfiles"`. The previous resolver rejected the ambiguous selection
and gated GET and PUT `/api/profile` with `503 storage_not_ready`.

The backend now maps profile storage strictly to lowercase `patientprofiles`.
Startup validation, development bootstrap, migration table resolution and the SQL
creation script all use this same physical table. No PascalCase fallback remains.
The old table can be removed manually without changing the profile queries.
JavaScript helper names and the `patientProfile` API field are unchanged.

Read-only inspection confirmed that `patientprofiles` contains the existing
profiles and `"PatientProfiles"` is empty. The lowercase table has a unique
`user_id` and a foreign key to `"Users"(user_id)`.

The separate backend's `.env` now explicitly selects the existing table:

```dotenv
AKAY_PATIENT_TABLE=patientprofiles
```

The setting is optional now that only one table name is supported; if supplied,
it must be exactly `patientprofiles`. Restart the backend after applying changes.
The existing startup
checks validate the selected schema; no schema migration, record merge or
controller change is needed. Keep this setting in the deployment environment as
well. An environment variable supplied by a process manager takes precedence over
`.env` and must select the same table.

The profile controller already uses the authenticated owner's user ID, maps
account fields to Users and health fields to patientprofiles, and saves both in
one transaction. Existing model/request aliases match the settings form.

Verification:

- Actual backend startup schema checks passed against the configured database
  using read-only catalog queries after setting the table name.
- Six focused backend tests passed, including strict lowercase selection before
  and after retired-table deletion, migration grant rendering and persistence.
- The persistence test uses only synthetic records in a generated schema on the
  dedicated PostgreSQL test cluster at localhost port 55439. It checks full
  save/fetch, aliases, partial updates, validation, owner isolation and rollback.
- No application profile records were modified. A live authenticated settings
  save and device UI verification were not performed.

Run the focused tests with the disposable test cluster running:

```powershell
node --test backend_patch/test/profile_persistence.test.js backend_patch/test/profile_table_selection.test.js backend_patch/test/profile_migration_mapping.test.js backend_patch/test/schema_startup.test.js
```
