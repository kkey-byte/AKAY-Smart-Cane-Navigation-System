---
name: akay-accessible-screens
description: Build or refine Akay Flutter screens for navigators and caregivers using the project's shared Gabay widgets, themes, and role routing. Use for screen layout, accessibility, dashboard, profile, or onboarding changes in this repository.
---

# Akay accessible screens

Akay uses `Gabay` names in much of its Flutter code. Preserve those identifiers unless renaming is part of the request. Paths below are relative to the repository root; inspect current implementations before editing.

## Find the right surface

- Navigator screens live in `lib/pages/visually_impaired/`; caregiver screens live in `lib/pages/caregiver/`.
- Shared profile and information pages live in `lib/pages/shared/`; onboarding lives in `lib/pages/onboarding/`.
- Reuse components from `lib/widgets/shared/`, `lib/widgets/visually_impaired/`, and `lib/widgets/dashboard_widgets/` before introducing equivalent scaffolds, cards, headers, or bottom navigation.
- Read `lib/theme/gabay_theme.dart` and `lib/theme/theme_controller.dart` when styling. Use the existing semantic theme colors so changes work in light and dark modes.

## Preserve role and session behavior

Read `lib/models/user_role.dart` and `lib/navigation/role_router.dart` for navigation changes. The navigator role is stored locally as `navigator` but sent to the backend as `visually_impaired`. Do not interchange those representations. Successful role routing clears the authentication stack; unknown roles must not silently become caregivers or navigators.

For onboarding or profile changes, trace `lib/services/app_session_service.dart` and the relevant service before changing page-local state. Login, onboarding completion, and profile completion are distinct states. Keep their persistence consistent with the existing flow.

## Make the changed interaction accessible

Give icon-only actions meaningful semantic labels, preserve readable text when text scaling increases, and avoid communicating status through color alone. Ensure essential navigation and SOS actions remain reachable with a screen reader and without precise taps. Inspect the existing `lib/widgets/visually_impaired/vi_sos_button.dart` when changing emergency UI; a visual success state must correspond to the actual implemented action.

Use `lib/services/gabay_tts_service.dart` for existing speech behavior instead of creating competing TTS instances. Its `speak` method stops the previous utterance; avoid triggering it repeatedly from widget builds. Keep async UI updates guarded against disposed contexts and remove listeners owned by the page.

## Verify the requested change

Format changed Dart files and run `flutter analyze` when Flutter is available. For behavior changes, run focused widget tests that exercise the affected role and interaction. Check light/dark appearance, large text, and semantic labels for changed controls; report device-only checks that could not be performed.

Inspect `test/widget_test.dart` before treating it as useful coverage: the current file is a starter counter test, not a test of Akay's role dashboards. Do not rewrite unrelated tests merely to make a screen change appear verified.
