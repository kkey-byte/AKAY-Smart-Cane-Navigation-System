# Caregiver consent and multiple smart canes

## Scope and verified original behavior

The Flutter repository and the separate backend at `C:/Users/Asus/app_mobile_backend` were inspected. The configured PostgreSQL database was queried for **schema metadata only**, never user rows. No live migration or Firebase deployment was performed.

Confirmed schema: `"Users"` uses UUID account keys and Firebase UID mappings; `smartcanes` already has a UUID `device_id` primary key, unique `serial_number`, and nullable `registered_user_id`. `pairings` holds device, navigator and caregiver foreign keys together with a unique pairing code and status. Its inspected constraints do not enforce a unique caregiver/navigator pair or one active navigator assignment per device. The schema can hold many rows per caregiver; it does not itself establish secure consent or physical ownership. `devicelogs` identifies a device without an immutable navigator assignment. `navigationsessions.deviceid` is a string without a physical-cane foreign key, while its user key references `"Users"`.

Original application paths:

- `FirebaseBreadcrumbRepository.share` previously wrote both `breadcrumb_shares` and `breadcrumb_links` directly. `BreadcrumbHistoryPage._share` accepted a permanent caregiver Firebase UID and an entered name. The navigator's grant was the only confirmation: no expiring invitation, caregiver redemption, pending identity confirmation, role verification or application pairing backend was involved.
- The owner could remove both indexes through `revoke`. The old Firebase rules guarded breadcrumb reads by the existence of a share, while `navigation_live` allowed any authenticated reader/writer. The inspected rule file is evidence of repository configuration, not proof of the currently running server's state.
- The source of `LiveLocationService.ensureDeviceId` generated a phone/account-derived identifier and stored it in preferences. That identifier was also sent as a navigation session device ID. It did not establish a registered physical cane, a private device credential, or custody.
- Existing HTTP auth/profile/navigation routes accepted client-supplied UID/account/session fields. They did not verify Firebase ID tokens before protected operations. Registration could update an existing email account's identity/role. These routes have been hardened rather than leaving a parallel authorization bypass.

## Implemented model and policy

The existing Users record remains authoritative. `akay_connections` models a unique navigator/caregiver relationship with pending, active, rejected, expired and revoked states. It is separate from `akay_devices`, `akay_ownership_history`, `akay_assignments`, immutable-attribution readings and alerts, invitations, transfers, audit events and rate counters.

A registered **owner** means the navigator who has verified physical custody through a privately provisioned claim code. It is an operational custodian, not a legal-title determination. Caregivers can monitor after consent but cannot claim, assign or transfer canes. Navigators assign their owned canes only to themselves; lending to someone else requires a recipient-accepted custody transfer. This avoids allowing an authorized monitoring caregiver to silently reassign another person's hardware. Multiple active canes per navigator, multiple caregivers per navigator and multiple navigators per caregiver are supported. Each cane has one active assignment, enforced by a partial unique index and device-row transactions. Unpairing never releases ownership or deletes accounts/history.

### Pairing lifecycle

1. Navigator creates a cryptographically random 256-bit invitation, valid for 10 minutes. Only its SHA-256 digest is stored. The displayed code contains no identity or permanent credential.
2. A signed-in caregiver redeems it once. Redemption is limited to five attempts per account/minute and 30 per source IP/minute using committed PostgreSQL counters, including unsuccessful attempts.
3. Redemption creates a pending request, not access. The navigator sees the caregiver's current database name and the exact sharing scope: name/photo, phone GPS track history, assigned cane readings and alerts. No health-profile access is implied.
4. The navigator accepts or rejects; pending requests expire after 24 hours. Acceptance and revocation record the acting account and time. Both participants can revoke. A new invitation and consent are required after revocation/rejection/expiry.
5. Advisory locks serialize competing invitations for the same pair; row locks and database uniqueness serialize competing device claims. Repeated same-owner claims and assignments are safe. No assisted/proxy consent is implemented; a caregiver cannot accept on the navigator's behalf.

### Devices, history and firmware contract

Trusted physical provisioning assigns a new UUID Device ID and serial exactly once, a private claim code for the owner, and a **separate** random firmware key. Device IDs are public identifiers, never authentication secrets. The operator tools write private material only to a new `.private.json` output, not console logs or this repository. Windows operators must restrict the output file ACL and handle the firmware component separately from the printed owner claim QR. The mobile interface supports private manual code entry; camera scanning/NFC/Bluetooth discovery is not claimed.

`POST /api/v2/telemetry` authenticates `Authorization: Device <deviceId>.<firmwareKey>`. It does not accept a user Firebase token as a device credential. Firmware first calls `/api/v2/device-assignment`; each sample includes the current assignment ID, monotonically increasing durable sequence and a fresh timestamp after that assignment started. The backend derives navigator attribution from the locked assignment, rejects old/replayed samples, and stores Device ID, assignment and navigator on both readings and alerts. Optional unavailable sensors remain null. Ended assignments and old readings are retained. Transfer ends the old assignment; the recipient starts a new one. Previous readings cannot become the new navigator's current readings.

Owner release consumes the claim and ends the assignment. Only an operator with physical possession can rearm that same Device ID and rotate its firmware key using `scripts/rearmCane.js`. Never create another identity just because a cane changes users. Firmware must support secure key storage, TLS with certificate verification, clock synchronization, assignment refresh and durable sequence storage. These are hardware/firmware dependencies, not verified mobile capabilities. A cane without GPS must omit GPS; LiDAR readings do not establish a GPS location. Device credentials should be rotated during physical servicing if compromise is suspected.

## Authentication and live access

All protected HTTP operations verify an SDK Firebase ID token with `verifyIdToken(token, true)` and look up one unambiguous current account/role in Users. The old development JWT secret/UID-only login path is removed. Existing account-email conflicts now require reconciliation instead of account takeover. The mobile API obtains the SDK ID token and discards responses across account revisions; saved UID-like session fields are never authorization credentials. Profile and legacy phone navigation endpoints use the verified actor, not arbitrary submitted account IDs. Session updates verify ownership. Phone source labels use `phone_<firebaseUid>` and are never registered cane IDs.

Caregiver track, profile-name, device, location and alert reads go through the authenticated backend. Each request checks the current active connection; trip/snapshot reads recheck after asynchronous data reads. The app polls at five-second intervals and clears readings on denied/error responses or selection/account changes. This is polling, not push delivery: display revocation detection is bounded by the next polling request and network timeout. Already delivered data cannot be recalled or erased from another person's device.

The prepared Firebase rules deny direct caregiver reads of another user's trips, deny client-written legacy sharing indexes, and close broad legacy live channels. Only an owner can write their own phone GPS/tracks. Firebase Admin reads historical phone tracks only after SQL consent checks. Phone GPS is explicitly distinguished from each physical cane's readings, source and last-update time. Unknown or older-than-45-second data is labeled unavailable/stale. Profile names are queried from Users, so new profile names do not depend on stale manual sharing labels.

Firebase Admin application-default credentials, project identity and `FIREBASE_DATABASE_URL` must be configured by the operator. Release mobile builds reject HTTP endpoints, and the backend rejects non-HTTPS requests in production mode. Set an explicit `TRUSTED_PROXY_CIDRS` allowlist only when terminating TLS at a trusted reverse proxy. Production transport must terminate HTTPS, including machine ingestion. A production reverse proxy must strip spoofed forwarding headers and apply request/body/global abuse limits; the application does not trust arbitrary forwarding headers for rate limits.

## Migration and rollout (reviewable; not applied live)

`backend_patch/database/migrations/001_pairing.sql` is the exact migration copied into the backend. `scripts/migratePairing.js` resolves `users` versus `"Users"` and prints SQL by default. `--apply` additionally requires `AKAY_MIGRATION_APPROVED=yes`. There is no automatic migration on server startup.

Impact:

- Creates additive v2 tables, foreign keys, permanent-ID trigger, unique identity and active-assignment indexes. Index creation may lock Users; schedule maintenance. Duplicate Firebase mappings or UUID/serial conflicts abort instead of arbitrarily choosing a record.
- Copies legacy smartcane UUIDs and serials as **unclaimed** inventory; it does not copy registered_user_id into verified ownership or fabricate a replacement Device ID. Physical reconciliation and credential provisioning are required before claims.
- Adds reconciliation entries for legacy devices, pairings, navigation sessions and accounts missing a usable identity/role. Old device logs and pairing rows remain untouched. Legacy pairing codes are not copied or treated as consent.
- Firebase legacy sharing must be exported privately for review before rule rollout. It cannot be migrated automatically into active consent. Known existing legacy pairings must complete the new invitation/acceptance flow.
- Closing legacy rules intentionally ends old caregiver direct access. Deploy the backend, database migration, rules and app as a coordinated maintenance release. Keep the old unauthenticated backend offline during cutover. Source application is not evidence that a running server has adopted it.

Recommended approved rollout: privately back up SQL/Firebase data; review rendered migration and reconciliation policy; configure Firebase Admin and HTTPS; apply the approved migration; physically verify/rearm existing inventory; deploy the prepared RTDB rules and secured backend; install the app; create fresh consents; verify two-device/two-navigator flows. No deletes, automatic identity assignment or live backfill were performed here. Do not revert to permissive rules as a rollback; leave monitoring disabled if secure rollout cannot complete.

## Changed implementation and verification

Backend: `routes/pairing.js`, `services/pairingService.js`, `middleware/identity.js`, `services/firebaseAdmin.js`, protected auth/profile/navigation routes, the v2 migration, provisioning/rearm/migration scripts and PostgreSQL/HTTP security tests. The reviewed source is retained in `backend_patch/`; `Apply-BackendPatch.ps1` backs up existing backend files and copies an explicit file manifest without migrating, restarting or deploying.

Flutter: `PairingService`, `SecureApi`, pairing/reading models, `PairingManagementPage`, `NavigatorDataCard`, caregiver/navigator profile entry points, onboarding, dashboard monitor entry, authenticated auth/profile/navigation services, account-scoped phone publisher and the breadcrumb repository/history entry point. Existing role routes and shared Gabay components are retained.

Tests use synthetic records and an isolated local PostgreSQL cluster, never the configured application database. Concurrency tests use separate PostgreSQL pool connections. HTTP tests inject a synthetic token verifier and verify the authorization boundaries; they do not prove live Firebase credentials are configured. Firebase demo-emulator tests exercise the actual prepared rules, including denying legacy-grant bypasses and unauthorized subscriptions. Flutter tests exercise ID-token headers, missing identity, account changes, mutation retry policy, consent confirmation, distinct navigator/device displays, revoked-data clearing, unknown readings and large text. Physical cane claims, real sensor delivery, production Firebase token verification, two physical phones, screen-reader device behavior and production deployment remain integration work.

Design references: [Firebase ID token verification](https://firebase.google.com/docs/auth/admin/verify-id-tokens), [session revocation checks](https://firebase.google.com/docs/auth/admin/manage-sessions), [PostgreSQL partial unique indexes](https://www.postgresql.org/docs/18/indexes-partial.html).

### Re-running verification locally

The PostgreSQL suite explicitly uses only `127.0.0.1:55439`, user `akay_test`, database `postgres`, and a generated isolated `akay_security_test_*` schema. It does not load the application database credentials. Start the workspace's disposable PostgreSQL cluster with `pg_ctl -D C:/Users/Asus/app_mobile/tmp/pairing_pg -o "-h 127.0.0.1 -p 55439" -l C:/Users/Asus/app_mobile/tmp/pairing_pg.log -w start`, then run `node --test test/security.test.js` from the backend. Stop that test cluster afterward. It contains synthetic records only. Never point this suite at the application database.

Run `npm --prefix firebase test` from the Flutter repository for the demo RTDB emulator suite. Run focused Flutter files including `test/pairing_security_test.dart` and `test/user_data_session_test.dart`; these use fakes and mock HTTP rather than hardware. Source formatting and `flutter analyze --no-pub` are separate checks.

### Recorded verification results

- 15 PostgreSQL/HTTP security tests passed in the actual backend folder using the isolated test database. This includes simultaneous claims, duplicate invitations, expired/reused codes, consent decisions, revocation, two navigators/two canes, multiple canes/caregivers, machine credential/sequence checks, replacement/transfer, preserved legacy identity and rejection of client identity spoofing.
- 5 Firebase demo-emulator rule tests passed. Denied caregiver reads/subscriptions and disabled legacy grants were exercised against the prepared rules, not deployed production rules.
- 32 focused Flutter security and regression tests passed, including accessible pending-request confirmation, account-switch mutation protection, data separation, revoked-data clearing and existing maps/reports/breadcrumb behavior.
- Changed Dart sources were formatted; final analyzer and diff-check results are reported in the task response. Physical hardware, real account Firebase Admin configuration and production rollout were not exercised.
