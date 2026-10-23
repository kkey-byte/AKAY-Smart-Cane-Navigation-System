---
name: akay-profiles-health
description: Implement or debug AKAY profile editing and health information display, including account fields, patient data, profile photos, and profile completion. Use for Flutter profile forms and their API/cache integration, not medical advice or authentication changes.
---

# AKAY profiles and health information

Paths are relative to the repository root. Keep the requested form or data change scoped to the appropriate user and role.

## Locate the data source

Read `lib/pages/shared/edit_profile_page.dart`, `lib/services/profile_service.dart`, and `lib/models/patient_profile.dart` for persisted editing. Account fields belong to Users; patient fields belong to PatientProfiles through the combined `/profile` API. ProfileService fetches with GET, saves with PUT, and updates the local profile cache from the returned ProfileBundle.

Read `lib/pages/shared/information_health_status_page.dart` and `lib/models/navigator_health_profile.dart` for health display. NavigatorHealthProfile includes static sample profiles and has a different shape from PatientProfile: separate allergy categories and multiple emergency contacts versus combined string fields in the API model. Do not present those samples as fetched records or silently invent a lossless conversion. If wiring the display to persistence, explicitly map supported fields and identify missing backend fields.

Trace callers in `lib/pages/caregiver/caregiver_profile.dart` and `lib/pages/visually_impaired/visually_impaired_profile.dart`. The current ProfileService obtains the signed-in user's identity; it is not a general service for editing a linked navigator. Do not substitute another user's ID without an explicit feature and verified backend access rules.

## Preserve field and cache semantics

- PatientProfile supports age, gender, birthdate, medical conditions, allergies, blood type, emergency contact, and address. Inspect `fromJson` aliases and `toJson` before changing request names. Birthdate serializes as a date-only value.
- Null patient fields are omitted from requests. Omission is not necessarily deletion. Confirm API behavior before implementing clear/remove actions, and preserve untouched fields in partial form edits.
- ProfileBundle carries the backend's `profileComplete` flag. Keep profile completion separate from onboarding completion. Inspect callers that infer completion locally before changing the completion flow.
- `lib/services/app_session_service.dart` caches name, phone, picture, and completion status. Its cache updater ignores null arguments; large picture data URLs are kept in memory instead of preferences. A successful cache update alone is not proof of durable backend storage.
- Photos currently use data URLs, not Firebase Storage. `encodeProfilePictureDataUrl` labels bytes as JPEG; check actual image encoding when changing image selection or conversion. Do not introduce a storage migration as a side effect of a form edit.

Validate input according to the existing form and backend contract. Preserve a user's entered data on save failure and distinguish unknown health information from an explicit value such as no known allergies. Do not infer diagnoses or fill missing health fields with sample values. Use synthetic health data in tests and keep personal records and image payloads out of logs.

Reuse `lib/widgets/profile/`, `lib/widgets/shared/`, and `lib/theme/gabay_theme.dart` for changed UI. Provide labeled fields, accessible errors, and layouts that tolerate large text. Guard async updates after disposal and prevent duplicate submissions.

## Verify persistence, not just appearance

For changed behavior, select focused model/service/widget tests covering relevant JSON aliases, date serialization, omitted versus cleared fields, fetch/save failures, or cache refresh after success. For photo changes, check supported image sources and reopening the profile after a restart. For role changes, verify that the intended person's record is displayed or edited.

Format changed Dart files, run `flutter analyze`, and run relevant tests when available. Use a mocked API or authorized test environment; distinguish mocked results from backend persistence checks. Report missing schema support rather than claiming a display-only field has been saved.
