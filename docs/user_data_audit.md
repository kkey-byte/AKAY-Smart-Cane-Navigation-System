# Caregiver and navigator user-data audit

## Findings verified in source

- `LinkedNavigatorService` contained sample people, addresses, device batteries and activity states. `NotificationService` seeded alerts. The navigator notification and emergency-contact pages also held samples.
- Dashboard widgets and both report bodies showed fixed totals, events, charts and recent trips. `MapPlaceService` supplied sample saved/recent destinations and synthetic route fallbacks. `ViNavigationBanner` supplied a sample destination, duration and distance.
- `ProfileService.fetchProfile` and `saveProfile` use the existing signed-in-user `/profile` contract. The health screen previously used separate sample health models, not these persisted fields.
- `FirebaseBreadcrumbRepository.watchLinks`, `watchShares` and `watchTrips` are existing sources for track-sharing labels and recorded trips. They are not evidence of physical cane pairing, device telemetry, or permission to read another person's health profile.
- Profile requests could finish after an account switch. Profile/setup caches and destination history needed account isolation. Logout previously cleared local session state without signing Firebase out.

## Changes

- Removed fabricated user records, readings, notifications, places, charts, trips and device IDs. Unknown values are explicitly unavailable; an empty trip collection reports zero recorded trips without inventing distance or movement.
- `RecordedReports` subscribes to the authenticated account's trips, or a selected navigator from the caregiver's sharing stream. It clears data on account/owner changes and stream failures. Summaries explicitly cover the latest 100 recorded trips; distance is approximate GPS path length, not verified walking distance. Report headings remain visible.
- `AuthorizedUsersCard` uses the existing sharing indexes with loading, empty, failure and retry states. Names are saved sharing labels, not a live linked-user profile lookup.
- Health information loads only the signed-in user's supported fields. Combined allergies and emergency-contact text are displayed directly; no allergy categories, height, weight, diagnoses or relationships are inferred. Missing fields say Not provided.
- Emergency contacts come from the current account's onboarding setup. Profile pages and dashboard headers expose refresh failures and retries. Missing profile photos use a neutral person icon.
- `AppSessionService` invalidates identity revisions, clears account-specific caches on switching users, resets navigation state, clears local identity on logout, stops location tracking and signs Firebase out. Profile responses validate account revision and returned backend identity. Profile refreshes cannot replace a profile changed by a completed save.
- Search and sent-destination histories are stored under account-specific preference keys. Unowned legacy history is not imported. Navigation banners receive actual active-route values. Failed directions now produce an error instead of a fabricated route.
- Simulated pairing, password-change and SOS success messages were replaced with unavailable states. No pairing/notification/password backend was invented.

## Verification and limits

Focused Flutter tests cover account switching, stale and mismatched profile responses, logout, missing profile fields, search-history isolation, absent telemetry, report data, Home map transitions, and existing breadcrumb/tracking layouts. Mock HTTP, preferences and synthetic records do not verify production persistence or authorization.

Remaining integration blockers: no verified cane telemetry or physical pairing API; no connected alert delivery source; no verified caregiver health-profile endpoint. Track-sharing labels do not automatically follow linked users' profile-name changes. Device GPS, deployed Firebase access rules, revoked-access synchronization, live backend persistence, screen-reader behavior and LiDAR hardware require authorized integration/device testing. Generic static labels and instructional examples are intentional UI text.
