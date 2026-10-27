# Consent-based live tracking

Navigator GPS recording belongs to the signed-in app session, rather than a map
page or destination. With location permission and recording enabled, accepted
GPS fixes publish to the existing account-owned `phone_location` record as well
as the local breadcrumb recorder. Historical jitter filtering and cloud upload
acknowledgments do not block live publication or local recording. Fixes retain
their sampling timestamp, so reconnecting cannot make an old fix appear new.

Caregiver Home and Track maps share the existing consent-checked dashboard API,
polled every two seconds. That API reads phone GPS separately from saved paths
and checks connection authorization before and after reading data. The Track
map retains its subscriptions when the approved connection list is unchanged,
follows the selected Navigator by default, and labels unavailable or stale fixes.
Polling adds network and backend latency; it is not an instantaneous guarantee.

The Navigator retains pause/resume, saved-track visibility, and access-revocation
controls. Pause stops new live publication and recording and clears the live
record; previously shared history remains available to approved caregivers.
Completing a navigation route does not end session-owned live sharing. Android's
foreground notification and Apple's background-location indicator remain enabled
while background recording runs.

No schema or authentication changes are required. The deployed backend must
already provide `/v2/navigators/:uid/dashboard`, and Firebase must permit the
Navigator's own writes to `phone_location` using the repository's existing rules.
Caregivers continue to read through the authorized API, not directly from Firebase.

Before release, validate on two authorized test accounts and physical phones:
movement on both caregiver maps, background/locked-screen delivery, denied GPS
permission, network loss/recovery, pause/resume, account switching, and revoked
access. Operating-system permissions, battery restrictions, and connectivity can
delay or prevent background delivery. No physical GPS, backend deployment, cane,
or LiDAR behavior is established by mocked tests.
