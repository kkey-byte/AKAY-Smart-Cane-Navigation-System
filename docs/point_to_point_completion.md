# Point-to-Point completion and recorded reports

Navigation now starts a named `Point-to-Point: destination` breadcrumb trip.
It uses the existing session-owned GPS recorder, movement filtering, local
durable outbox, authenticated trip-upload API and Reports list. No new screen,
card, control or database schema is introduced.

The existing daily track closes at the route boundary. Valid GPS fixes during
the route are recorded under the Point-to-Point name, with the actual captured
coordinates and timestamps. Existing track-length/time/gap limits may split a
long route into bounded segments bearing the same destination name.

Arrival requires a location within the existing 35-metre radius, GPS accuracy of
35 metres or better, and a sample no more than 45 seconds old or 30 seconds in
the future. Arrival is checked before reverse geocoding and also when route
startup finishes, so a delayed address lookup or session-start response does not
require the user to move again after reaching the destination.

On arrival, the app closes the Point-to-Point breadcrumb record as completed and
requests a Completed navigation-session end. The existing details panel opens;
its existing Cancel Destination button reads **Finish Navigation**. Pressing it
clears the finished route without sending a destination-cancel request or
changing the completed outcome to Cancelled. Completion and repeated taps share
one in-flight end request. An unsuccessful session end remains retryable.
Backend completion retries return the already-saved outcome without changing
the original finish time; a conflicting outcome is rejected.

The completed breadcrumb is retained locally before upload and included in the
existing navigator Reports merge. Failed uploads stay in the durable queue and
retry through the current sync mechanism. Only server acknowledgement establishes
remote upload success. Existing consent checks continue to govern caregiver
Reports. No planned route points or synthetic locations are saved as travelled
breadcrumbs.

Cancelling before arrival retains the existing cancellation behavior and marks
the route breadcrumb interrupted. Daily tracking continues after a completed
route for users who already had it enabled. If recording was paused before the
route, the previous pause is restored afterward. Explicit recording controls,
role routing, caregiver destinations, cane signals, Firebase connections and
report layouts are preserved.

## Verification and deployment

Use the updated Flutter build and restart/deploy the backend for retry-safe
navigation completion. No new migration is needed. Focused tests use synthetic
GPS fixes, fake HTTP/repository boundaries and a localhost test server; they do
not verify outdoor arrival, physical GPS accuracy or production synchronization.
Device acceptance should check an assigned destination, actual walking samples,
arrival/Finish, the completed named track in Reports, offline upload recovery,
and cancelling before arrival. Keep personal route data out of shared logs and
screenshots.

Local verification: 52 focused Flutter tests passed for fresh/accurate arrival,
the existing Finish button, single in-flight completion, failed-end retry,
Point-to-Point path saving, offline outbox recovery, recording preferences,
account isolation, GPS/start flows and unchanged report/map layouts. Four
backend HTTP tests passed for idempotent completion, conflicting outcomes,
ordinary cancellation and ownership/role checks. Changed Dart files were
formatted. `flutter analyze --no-pub` reported only the two existing informational
notices in `blob_painter.dart` and `gabay_page_route.dart`. The regular analyze
command initially hit a Windows permission error in generated iOS package files;
the no-pub check completed using the installed dependencies.
