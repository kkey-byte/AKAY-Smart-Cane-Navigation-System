# Cane GPS data flow

The existing backend Firebase Admin configuration reads numeric `latitude` and
`longitude` from `Device_Location/{assigned cane serial}`. Coordinates are validated
independently of battery and alert fields. No credentials, Firebase rules, firmware
records, or Flutter UI were changed.

Monitoring prefers the assigned firmware coordinates when available. Existing phone
GPS and authenticated cane projections remain fallbacks. Firmware coordinates have
no capture timestamp: they are explicitly last reported (`live: false`), with the
read time representing database observation only. Polling must not imply a fresh fix.

The running backend listener saves changed firmware observations in PostgreSQL even
without the phone app. When no explicit cane trip is available, monitoring retrieves
up to 500 persisted coordinate observations for the selected current assignment.
These are observation history, not reconstructed offline trips. Existing explicit
cane sessions, phone trips, consent checks, and UI remain in place.

Restart/deploy the backend to activate these changes. Existing device-location and
history migrations must already be installed; no new migration is introduced.

Read-only verification with the configured Firebase credentials confirmed a record
with valid numeric coordinates and no timestamp on 16 November 2026. Coordinate
values were redacted; no production writes or alert triggers were performed.

The latest-value Firebase record cannot recover intermediate positions overwritten
while the backend/cane network was offline. Phone-free, disconnected breadcrumbing
still requires cane-side persistent storage, capture timestamps, sequence/session
identifiers and later upload. A physical walking test, deployed backend verification,
and offline firmware recording remain necessary before claiming complete tracking.
