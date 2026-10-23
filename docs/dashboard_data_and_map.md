# Dashboard data and maps

Both dashboards use DashboardLiveSection and the existing interactive GabayTrackMap. The caregiver can select connected Navigators; markers include authorized peers and the selected Navigator's recent breadcrumb path. The Navigator uses their existing location and navigation services without depending on the navigation tab being open.

The authenticated GET /api/v2/navigators/:uid/dashboard reads the latest navigationsessions row from PostgreSQL and the existing breadcrumb_trips and phone_location paths from Firebase Realtime Database. Existing connection authorization is checked before and after asynchronous reads. Revoked connections are removed from the UI. Partial failures produce explicit fallback messages. No new database schema is required.

Navigation status, compass heading, destination/address and estimated arrival have explicit empty, stale and unavailable states. Active saved navigation expires after two minutes without an update. Arrival remains visible for ten minutes after completion. Walking-route geometry and remaining travel duration come from the existing route service, at most once per minute per selected target (and after 25 metres of movement following a successful estimate). ETA is an estimate, not a stored arrival promise.

Navigator foreground activity posts to /api/v2/dashboard/presence every 20 seconds and on lifecycle changes. Activity expires after 45 seconds; recent background GPS alone never proves the app is in use. This heartbeat is ephemeral in a single backend process. Restarting the backend yields unknown activity until the next heartbeat; multi-worker deployments require shared presence storage. GPS freshness also expires after 45 seconds. The shared API watcher polls dashboard snapshots every five seconds. Dashboard activity reporting does not start or stop GPS recording.

Verification: focused dashboard, pairing, session isolation and tracking Flutter tests; backend dashboard and schema regression tests; read-only EXPLAIN against the connected PostgreSQL schema. Widget tests use an injected map, so physical GPS, remote tile rendering and two-device caregiver updates remain device-validation work. No hardware verification is implied.

