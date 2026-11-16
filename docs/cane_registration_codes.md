# Manual server-code cane registration

Profile → Connections & Devices → Register Smart Cane → Register Cane uses the
existing registration modal and styling. No dashboard panel,
layout or caregiver invitation behavior is changed.

1. Tap Register Cane on Connections & Devices or Register cane on Smart Cane.
   The existing modal opens and immediately requests
   `POST /api/v2/devices/registration-code` with an empty body. There are no
   Device ID or private claim-code inputs in this flow.
2. The server selects the next unowned cane explicitly authorized for the
   authenticated navigator by the operator, then returns
   `registrationId`, a six-character `code`, and `expires_at` (five minutes).
   Ownership has not yet changed.
3. The same modal displays the server code and expiry above a Registration code
   input, with the Register button directly underneath. Enter the code and tap
   Register. Incorrect codes stay in this modal for correction.
4. The app sends `registrationId` and the entered `code` to
   `POST /api/v2/devices/registration-code/confirm`. The server checks the
   requesting navigator, expiry, code digest, unused state and unchanged cane
   provisioning state and authorization. Only successful validation commits ownership and consumes the
   code. The device list refreshes from the server.

Codes are account- and device-bound, single-use, rate-limited, and stored only as
digests. A fresh request for the same account/cane replaces its previous pending
code. Simultaneous confirmations cannot create duplicate custody. Closing a
dialog, entering a wrong/expired code, or switching accounts before confirmation does not register
the device. A server-issued code displayed and re-entered on the same device is
a confirmation step, not a second authentication factor. An operator must
authorize the specific physical cane for that navigator first. The server never
assigns an arbitrary unclaimed Firebase child or cane from shared inventory.
Multiple authorized canes are offered in preparation order, one registration at
a time. Existing clients using explicit physical claim proof remain supported.

Existing **Assign to me**, transfer, release, caregiver pairing, Firebase
connections and sensor monitoring are preserved. Registration does not
automatically assign the cane; use the existing assignment action afterward.
The original claim endpoint remains compatible with existing clients.

## Deployment

Review `app_mobile_backend/database/migrations/009_cane_registration_codes.sql`
against the intended database using the existing explicit migration runner:

```powershell
cd app_mobile_backend
node scripts/migratePairing.js --migration=009_cane_registration_codes
# After reviewing the SQL and intended target:
$env:AKAY_MIGRATION_APPROVED = 'yes'
node scripts/migratePairing.js --migration=009_cane_registration_codes --apply
Remove-Item Env:AKAY_MIGRATION_APPROVED
```

Requires the existing pairing/integrity schema. Reapply 009 after creating the
runtime privilege role if necessary. Then review/apply migration
`010_cane_registration_authorizations` using the same command pattern.

An operator prepares an already-provisioned, unowned cane for a known navigator:

```powershell
node scripts/authorizeCaneRegistration.js CANE_SERIAL NAVIGATOR_FIREBASE_UID
```

Replace both placeholders with actual values. To diagnose eligibility without
changing records, run the same command with `--check`:

```powershell
node scripts/authorizeCaneRegistration.js $caneSerial $navigatorUid --check
```

The script distinguishes missing inputs, missing backend navigator profiles,
caregiver roles, unprovisioned/already-owned canes, missing claim proof, missing
migrations and operator permissions without printing account identifiers or
credentials. `PostgreSQL Connected` alone confirms only database connectivity.

This creates a 24-hour server-side authorization; it does not register the cane
or expose a firmware key. Reauthorization invalidates earlier pending codes.
Without an authorization, the modal reports that no cane is ready for this
account. The runtime role may read/consume authorizations but cannot create them.

Restart/deploy the backend and rebuild the
app. No production database migration or real device registration was performed
during implementation. Provisioning a cane remains an operator step; this flow
does not invent canes from arbitrary serials or expose firmware credentials.

## Local verification

25 focused Flutter tests passed, covering automatic request/display/manual confirmation,
wrong-code rejection, cancellation, the existing responsive panel layout, API
contracts, and caregiver/account boundaries. Nine disposable-PostgreSQL tests
passed for expiry, replacement codes, account/device binding, concurrent
confirmation, authorization expiry/revocation, multiple prepared canes, rate
limits, runtime privileges and migration reapplication.
Changed Dart files were formatted. `flutter analyze` reported only the two
existing informational notices in `blob_painter.dart` and `gabay_page_route.dart`.
Real deployment, a production account and physical cane registration remain
unverified; tests used synthetic accounts, fake HTTP responses and localhost SQL.
