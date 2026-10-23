---
name: akay-authentication-onboarding
description: Implement or debug AKAY registration, login, logout, role routing, and onboarding in the Flutter app. Use for Firebase authentication, backend identity synchronization, and persisted onboarding state; profile and health field editing belongs to the profile workflow.
---

# AKAY authentication and onboarding

Work from the repository root. AKAY retains Gabay names in its widgets and routes; preserve those names unless renaming is requested.

## Trace identity before changing screens

Read the affected entry points in `lib/pages/login_page.dart`, `lib/pages/signup_page.dart`, and `lib/pages/splash_page.dart`, then trace `lib/services/auth_service.dart`, `lib/services/app_session_service.dart`, and `lib/models/app_user.dart`.

Authentication is split: Firebase authenticates credentials, while the HTTP backend supplies PostgreSQL user profiles and roles. Firebase UID and backend user ID are different identifiers. A Firebase login alone does not establish a usable backend profile. Read `lib/config/api_config.dart` for configured endpoints rather than hardcoding a development address.

`AuthService` accepts an HTTP client, base URL, and FirebaseAuth instance, providing seams for isolated tests. Registration currently handles an existing Firebase email by authenticating and retrying profile synchronization; a backend 409 triggers profile lookup. When changing recovery, distinguish newly created accounts from existing accounts and uncertain network outcomes. Do not treat a timeout as proof that a profile was never saved, or delete an existing account as generic cleanup.

## Keep routing and persistence consistent

- `lib/models/user_role.dart` stores the navigator role locally as `navigator`, but its backend value is `visually_impaired`. Use the model conversions instead of comparing display labels.
- `lib/navigation/role_router.dart` clears the authentication stack after successful routing and rejects unrecognized roles. `lib/pages/onboarding/onboarding_router.dart` currently defaults non-navigator roles to caregiver; account for this difference when changing role validation instead of assuming both routers reject null roles.
- Onboarding pages and widgets are in `lib/pages/onboarding/` and `lib/widgets/onboarding/`; setup data is defined in `lib/models/onboarding_data.dart`.
- Logged-in, onboarding-complete, and profile-complete are separate states. Inspect their callers: login/signup route directly through RoleRouter, while splash also consults persisted onboarding state. Verify both immediate navigation and navigation after restarting the app.
- `AuthService.signOut()` signs out of Firebase; `AppSessionService.logout()` clears local identity, profile, and setup data. Trace both when implementing logout or recovering from a failed role lookup.

The current auth result can fall back to a Firebase UID as its token value. A UID is an identifier, not proof of authorization; do not build new protected API behavior on that fallback. Check the actual backend contract for changes involving authorization. Keep passwords, tokens, and full authentication responses out of new logs and fixtures.

## Verify the changed flow

For behavior changes, use injected fakes and isolated preferences to cover the relevant success and failure paths: both roles, failed backend lookup after Firebase login, incomplete registration recovery, unknown roles, restart during onboarding, or logout followed by another account. Assert observable routing and persisted state, not just service calls.

Format changed Dart files, run `flutter analyze`, and run focused tests when Flutter is available. The existing `test/widget_test.dart` is a starter counter test, not authentication coverage. Report any emulator or backend checks that remain unverified; use synthetic accounts in an authorized test environment for integration checks.
