# AKAY Agent Instructions

## Project context
AKAY: A Smart Cane Navigation System with Caregiver Monitoring Using LiDAR Sensor.

Read [knowledge.md](knowledge.md) for the project purpose, technologies, source layout, and implementation scope before making changes.

## Working in this repository
- Inspect the affected implementation before editing. Preserve existing work outside the requested task.
- The mobile app uses Flutter and Dart. Many shared components use Gabay identifiers; preserve those names unless renaming is requested.
- Reuse widgets under lib/widgets/ and styles from lib/theme/ when building UI.
- Keep HTTP integrations in lib/services/ and structured data parsing in lib/models/.
- Trace role routing and session persistence before changing navigator or caregiver workflows.
- Support readable text scaling, semantic labels, and status indicators beyond color.
- Keep credentials, tokens, patient information, and personal location data out of logs, documentation, and screenshots.
- Do not describe GPS, backend synchronization, or LiDAR hardware as verified without actual evidence.

## Original project skills
Use the relevant existing skill when its workflow applies:

1. [akay-accessible-screens](.agents/skills/akay-accessible-screens/SKILL.md): Flutter screen layout, accessibility, shared widgets, and themes.
2. [akay-authentication-onboarding](.agents/skills/akay-authentication-onboarding/SKILL.md): registration, login, logout, role routing, and persisted onboarding.
3. [akay-navigation-tracking](.agents/skills/akay-navigation-tracking/SKILL.md): destination search, route planning, GPS sessions, and caregiver live tracking.
4. [akay-profiles-health](.agents/skills/akay-profiles-health/SKILL.md): profile forms, patient information, photos, and API/cache integration.

These four skills are the group's selected project skills. Do not add, replace, or remove skills unless requested.

## Verification
For Dart implementation changes, format changed files, run flutter analyze, and run relevant tests when the SDK is available. Report checks performed and any device, backend, or hardware validation that remains unavailable. Documentation-only changes do not establish app functionality.
