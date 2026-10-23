# Reviewed backend patch

Profile SQL maps exclusively to lowercase `patientprofiles`, including startup
validation, development schema setup and the runtime-role migration runner.
`AKAY_PATIENT_TABLE`, if supplied, must be `patientprofiles`. PascalCase patient
tables are never selected; removing one does not require changing API fields.

This directory retains the security change alongside the Flutter repository because the configured backend is a separate, non-Git folder. It is a patch set, not a standalone server distribution: unchanged search services and other backend modules remain in `C:/Users/Asus/app_mobile_backend`.

`Apply-BackendPatch.ps1` copies only its explicit manifest into that backend and backs up pre-existing files under ignored `original_backup/`. It does not apply SQL, restart a server, or deploy Firebase rules. Dependencies have been installed in the target backend. Do not run the migration against a live database without the documented review and rollout.

See [the audit, model, firmware contract and migration plan](../docs/pairing_and_devices.md). `node --test test/security.test.js` uses only a separately started disposable PostgreSQL test server on localhost port 55439, never application credentials.
