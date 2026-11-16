# Navigation cancellation

Cancelling a destination saves an account-scoped cancellation record on the
phone before clearing the active route, navigation panels, voice guidance and
local session. Cancelled assignment IDs are excluded from polling results,
including responses that were already in flight. They remain excluded after
the app restarts. A failure to save locally leaves the trip available for retry.

The existing destination polling retries pending server cancellations. Each job
contains only the cancelled destination ID and the specific navigation session
IDs captured for that trip. A delayed session-start response queues its own
session for cancellation rather than restoring the route. New destinations and
new sessions are not cancelled by an older job.

The backend records a terminal marker for the cancelled assignment and removes
only its matching pending delivery. This also handles old assignments whose
progress record is missing, and prevents late delivery writes from reviving
them. Cancelling one's own assignment remains possible after caregiver consent
is revoked; notification delivery is suppressed in that case. Completed trips
retain their existing completion behavior.

Cancellation preserves breadcrumb/report history and current-location tracking.
It makes no changes to UI styles, layouts or controls.

Deploy the updated backend and rebuild/restart the app together. No database
migration is required. A previously stale assignment can be cancelled again
with the existing Cancel Destination button.

Verification uses mocked Flutter services and local backend tests covering
offline cancellation, reopening, in-flight responses, account isolation,
orphaned delivery cleanup and revoked consent. Real-device GPS, interrupted
network behavior and caregiver synchronization require device validation.
