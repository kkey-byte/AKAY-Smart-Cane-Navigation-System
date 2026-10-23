# Backend migration impact and approval plan

**Prepared only. No migration, role/grant change, credential change, table merge, row repair or deletion was applied to the configured database.** Source fixes may be copied with backups; this is not database deployment. The isolated test cluster is separate and contains synthetic records only.

## Verified current state

[Catalog inspection](C:/Users/Asus/app_mobile/docs/backend_schema_metadata.json) found 14 legacy tables, no `akay_*` tables, both case variants of patient profiles, and a superuser service connection. Row contents/provenance were deliberately not inspected. This target may be development; its production equivalence is not established.

## Proposed sequence and effects

1. **Resolve patient storage before restarting revised server.** Compare the two patient datasets in an authorized environment, including `patientmedication` relationships and timestamps, without exposing patient details in logs. Choose `AKAY_PATIENT_TABLE=patientprofiles` or `AKAY_PATIENT_TABLE=PatientProfiles` explicitly. Neither table is merged/dropped by the prepared migrations. Normal startup now validates rather than changing schema. `AKAY_ALLOW_SCHEMA_BOOTSTRAP=yes` is development-only and production startup rejects it.
2. **001_pairing.sql:** creates new v2 pairing/device/telemetry/audit/reconciliation tables and constraints; reuses valid existing UID uniqueness. Preserves legacy device UUID/serial identity, leaves ownership/credentials unverified, and records reconciliation needs for old pairings/sessions. It does not grant old pairings access or invent physical ownership. Duplicate identities or conflicting legacy serial/UUID mappings abort; no automatic repair. Ordinary index creation/legacy reconciliation scans can lock or scan existing tables.
3. **002_integrity.sql:** adds attribution FKs, indexes, supported-role/consent/timestamp/sequence checks, identity/role and custody write guards, duplicate-alert protection and wall-clock defaults for new events. Existing inconsistent rows abort and roll back the migration. It does not delete, merge, reassign or convert timestamps. Established role/Firebase UID edits become prohibited; correction requires a separate approved reconciliation plan. Additional indexes consume storage/write work. A 5s lock timeout and 60s statement timeout bound this script; large targets may require separately reviewed concurrent-index/staged-validation deployment instead.
4. **003_runtime_role.sql:** creates/reuses a safe `akay_runtime` NOLOGIN privilege group, grants connection/schema access and only the table/column permissions used by HTTP handlers. No passwords/login are created; current superuser privileges are not changed. Its grants do not provide end-user RLS. Existing unexpected privileged group configuration aborts instead of being silently overwritten.
5. **Credential cutover (separate operator action):** create a dedicated non-owner LOGIN using the secret-management process, grant only membership in the reviewed runtime group, and audit effective privileges/PUBLIC grants. Configure backend DB credentials through secure configuration; never place values in code/reports. Keep the migration/provisioning operator credential separate. Validate login/profile/pairing/navigation/telemetry using synthetic staging accounts before production restart/cutover. Only after successful validation should the old backend credential be rotated/revoked under separate approval; do not demote a shared administrator automatically.
6. **Deploy reviewed RTDB rules** only after coordinated backend/client/ADC configuration, then verify owner writes and consent-checked caregiver reads using dedicated test accounts. Rules updates can reject old malformed timestamp/extra-field writes and disable legacy channels. Existing data is not rewritten by the rules deployment.

## Review/apply mechanism

[migratePairing.js](C:/Users/Asus/app_mobile/backend_patch/scripts/migratePairing.js) defaults to printing a selected SQL script, using fixed migration-name and table-name allowlists. Selections: `--migration=001_pairing`, `--migration=002_integrity`, `--migration=003_runtime_role`. Review requires metadata connectivity;003 additionally requires explicit patient-table selection if ambiguous. SQL execution requires **both** `--apply` and `AKAY_MIGRATION_APPROVED=yes`. No apply command was run against the configured target. Server startup never runs these migrations.

Obtain target/environment confirmation, maintenance window, recoverable backup and migration-specific approval before live application. The backup must cover SQL and Firebase state where applicable and remain access-controlled. Do not export real patient/location data into this repository.

## Rollback and unresolved data work

Each migration is transactional; a detected inconsistency leaves its target transaction unchanged, as tested with synthetic corrupted attribution.001/002/003 are separate transactions: failure in002 does not undo a previously completed001. Existing records require reviewed reconciliation; do not delete conflicts just to make a migration pass. No destructive down-migration is provided, because dropping new tables after device use would erase custody, consent and telemetry history. Revert source/configuration only under a coordinated plan and preserve newly written data. Credential cutover can be reverted using the secured previous configuration while access is investigated, subject to operator approval.

Historical seeded places, two patient datasets, naive legacy timestamps, orphan Firebase/SQL identities, retention/erasure and account deletion remain separate data-review decisions. There is no safe basis to delete or merge those records from metadata alone.

