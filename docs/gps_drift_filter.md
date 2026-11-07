# GPS history drift filtering

Only breadcrumb filtering and endpoint persistence are changed. Live GPS
publication, permissions, settings, UI, and map rendering are unchanged.
Existing saved tracks are not rewritten or cleaned.

- Keep existing coordinate, freshness, and maximum 50 m accuracy validation.
- Require displacement greater than `max(8 m, anchor accuracy + fix accuracy)`
  and at least 5 seconds since the last accepted movement vertex. A fixed anchor
  lets slow walking accumulate displacement instead of resetting on every fix.
- After a stop, require two spatially consistent departures at least 5 seconds
  and at most 30 seconds apart. Buffer the first candidate until confirmed.
- Reject jumps exceeding `12 m/s * elapsed + both reported accuracies`. This is
  a generous sanity bound, not a minimum walking speed or measured activity.
- After 30 seconds without displacement beyond uncertainty, require confirmation
  again. Stationary fixes add no coordinates. At most every 30 seconds, aggregate
  freshness at the fixed endpoint by updating its timestamp, retaining its
  coordinate and original accuracy. An aggregate endpoint represents the stop;
  it does not claim every raw fix had that exact coordinate.
- Re-upload the last endpoint along with new points, retaining the existing
  schema. Confirmation restores its original anchor timestamp if needed to keep
  chronological order. Keep the existing 500-point cap and account isolation.
- After a GPS gap longer than 90 seconds, start a separate segment using the
  existing trip mechanism. Do not draw a line across unobserved movement.

GPS accuracy is estimated, not a hard bound. Sustained biased GPS positions can
still resemble movement. Conservative thresholds can omit short excursions and
path detail under poor accuracy. Validate these constants on actual devices,
including slow walking, indoor stops, and signal recovery. This algorithm cannot
prove that someone walked between vertices or reconstruct missing observations.

No dependencies or native permissions were added. Geolocator already provides
native speed and accuracy information; missing speed should not imply a stop.
An accuracy-weighted Kalman filter could smooth accepted fixes after outlier
rejection. Douglas-Peucker simplifies a validated path; it cannot establish that
movement occurred. Native activity recognition could add independent movement
evidence, but its permissions and integration belong to a separate change.

Automated checks cover jitter, slow movement, departure confirmation, spikes,
freshness aggregation, uploads, GPS gaps, offline storage, account isolation,
and existing breadcrumb UI behavior. They do not verify device GPS, live backend
synchronization, or hardware integration.
