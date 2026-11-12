# Assigned destination notifications

Caregiver-assigned destinations now retain progress separately from delivery
acknowledgement. Accepted phone GPS publications confirm arrival within 35 metres,
with reported accuracy of 35 metres or better and a fresh capture timestamp.
Assignment cancellation or replacement reports not arrived; a recent arrival fix
takes precedence. Ongoing trips, GPS loss and offline status do not imply failure.
Only the assigning caregiver with an active connection receives these outcomes.

The existing caregiver notification feed displays the outcome and retains read
and dismiss receipts. Firebase Messaging uses the existing device registration.
A persisted push queue retries failures and checks caregiver access again before
sending. Jobs expire after 24 hours; registered devices are required for push.
Push delivery is at least once across crashes; stable notification IDs allow
deduplication. No layout or controls were added.

Continuous account-owned breadcrumb capture, local offline outbox, Recent Trips,
caregiver map updates and path review already exist and remain in place. Capture
requires navigator authentication, GPS permission and recording not being paused.
Force-stopping the application does not guarantee recording.

Deploy the updated `app_mobile_backend` and Firebase rules/indexes in
`firebase/breadcrumbs.rules.json`, then build the updated Flutter application.
An older running backend cannot deliver this new notification flow. Device GPS,
Firebase Messaging delivery, deployed database permissions and synchronization
between physical devices require separate end-to-end validation.
