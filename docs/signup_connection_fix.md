# Chrome signup connection fix

The screenshot's message comes from `AuthService._postAuth` when all HTTP attempts throw or time out. It occurs after Firebase account creation/sign-in, before PostgreSQL profile synchronization. It does not indicate a navigator-role validation error. The original Chrome transport failure was not reproduced in a connected browser session; direct HTTP probes were available.

Verified during diagnosis:

- Port5000 was serving an older API than the source on disk. An empty registration returned400 asking for `email`, `firebase_uid`, `role` and `password`; the reviewed API requires a verified Firebase ID token and deliberately never accepts the user's password for synchronization.
- Flutter's running command had no explicit API address override. Default web API is localhost:5000.
- The revised startup previously made all authentication unavailable if patient-table selection was ambiguous. The configured database has two patient-profile table names. No table was selected, merged or changed to fix signup.
- Initially, Firebase Admin application-default credential validation failed because no usable credential was configured. No key/token values were logged or copied.

Changes:

- `backend_patch/services/httpPolicy.js`: development accepts Flutter localhost/loopback browser ports; production still requires explicit allowed origins. Account schema remains mandatory; optional patient/catalog schema failures gate their own routes with503 instead of stopping authentication. Ambiguous patient storage is never silently selected.
- `backend_patch/server.js`: uses that policy and gates optional routes. Root health identifies the current Firebase-token authentication contract through a non-sensitive response header.
- `lib/services/auth_service.dart`: unreachable-server messages now distinguish browser/backend configuration from a phone Wi-Fi issue and preserve a recoverable `auth_server_unreachable` code. Registration still keeps passwords within Firebase and preserves accounts after uncertain sync failures.
- Added startup/CORS regressions and both-role signup/network-recovery tests, including real SQL registration using synthetic Firebase identities.

Tested source was copied with backups into `C:/Users/Asus/app_mobile_backend`. Restarted only the verified AKAY server on port5000. Live health now200 with `firebase-id-token-v2` header; localhost Chrome preflight204 with allowed-origin header; unauthenticated signup401. No real account was created/modified for verification. No migration, profile-table selection, grant/credential change or Firebase deployment was performed.

Verification:29 backend tests passed using isolated synthetic PostgreSQL/mocks;14 focused Flutter tests passed. Flutter analyzer has no errors/warnings and three existing informational lints. These are not a completed real-account signup test.

Credential follow-up: the user supplied a Firebase Admin service-account file in Downloads. Its project matches the app configuration. The backend environment now references that external file through `GOOGLE_APPLICATION_CREDENTIALS`; the private key was not copied into this repository. An authenticated Admin lookup of a synthetic nonexistent UID returned `auth/user-not-found`, confirming usable credentials and account-lookup access without creating or modifying users. Restarted the verified backend to load this configuration. HTTP health200, Chrome localhost:54380 preflight acceptance and unauthenticated signup401 were rechecked successfully.

User next step: reload the app and retry using the same email/password. `AuthService.register` already recovers an existing Firebase account by authenticating and repeating the idempotent backend synchronization. No real-account signup was submitted during verification. Profile editing remains unavailable until the patient-table choice is explicitly resolved; this no longer blocks account creation.
