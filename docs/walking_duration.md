# Movement-based Walking Duration

The existing Walking Duration value now uses a separate GPS-estimated movement
counter. It no longer substitutes total trip elapsed time, the wall clock, GPS
heartbeat time or the gap between the first and last recorded point.

`WalkingDurationTracker` uses the existing conservative GPS movement filter to
require a corroborated departure beyond the reported accuracy margins. It then
credits only observed, forward-in-time intervals between confirmed locations
with at least 0.5 metres of displacement and a plausible walking speed (at most
3.5 m/s). Stationary updates, duplicate/out-of-order timestamps, unconfirmed
departure spikes, invalid/inaccurate/stale fixes and gaps over 30 seconds do not
add walking time. The first uncertain portion before movement confirmation is
not guessed; this is a conservative estimate, not a step counter or proof of
physical gait. Very short or poorly measured walks may be undercounted.

Breadcrumb geometry and live GPS publishing keep their existing behavior.
Stationary heartbeat updates can still maintain live tracking, but add zero to
Walking Duration. Stopping, pausing and finishing a route preserve measured time
without crediting the remaining idle wall-clock duration. Point-to-Point names,
arrival/Finish behavior, daily recording preferences, distances and report/card
layouts are unchanged.

`walkingDurationSeconds` is stored with each measured trip in the account-scoped
local outbox, uploaded in the existing summary request, and persisted in the
PostgreSQL JSONB trip metadata. Fractional seconds survive caching and retries.
The backend validates finite/nonnegative values, bounds them by actual elapsed
capture time, prevents a stale update from decreasing walking time and preserves
the walking metric after finalization. No new database column/migration is
required. Existing `durationSeconds` and timestamps remain elapsed-trip data;
the activity card continues using elapsed duration.

Reports sum the measured Walking Duration for today's trips using the existing
card and formatting. A new stationary trip has measured walking time zero.
Older trips and cane records without a measured walking counter retain their
history, but their elapsed time is not relabeled as walking; that metric remains
unknown until measured data is available. No historical values are invented or
backfilled from elapsed time.

## Deployment and checks

Restart/deploy the backend and rebuild/restart the Flutter app. No UI change,
new permission, pedometer dependency or Firebase connection change is involved.
Verify on a device with stationary GPS refreshes, a real walk, a stop followed
by resumed walking, slow walking, a temporary GPS outage, route completion,
offline saving and subsequent Reports synchronization. Physical walking/steps
are not verified by synthetic GPS tests, and GPS alone cannot reliably classify
all activities (such as walking indoors or slow vehicle movement).

Local checks: 72 focused Flutter tests passed for stationary refreshes/jitter,
confirmed and slow movement, stops/resume, spikes, invalid/gapped GPS, offline
recovery, report aggregation, unchanged layouts/activity cards and navigation
completion. Eight isolated PostgreSQL history tests passed, including measured
walking metadata, elapsed-time preservation, immutable finalized values and
legacy history compatibility. Changed Dart files were formatted;
`flutter analyze --no-pub` reported only the two existing informational notices
in `blob_painter.dart` and `gabay_page_route.dart`. Real walking/step validation,
deployed synchronization and physical GPS behavior remain device checks.
