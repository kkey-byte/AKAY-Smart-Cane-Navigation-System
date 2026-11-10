BEGIN;
ALTER TABLE akay_alerts DROP CONSTRAINT IF EXISTS akay_alerts_kind_check;
ALTER TABLE akay_alerts ADD CONSTRAINT akay_alerts_kind_check CHECK(kind IN ('sos','motion','obstacle','battery_low','device_fault'));
ALTER TABLE akay_alerts ADD COLUMN IF NOT EXISTS event_id text CHECK(length(event_id) BETWEEN 1 AND 128);
CREATE UNIQUE INDEX IF NOT EXISTS akay_hardware_incident ON akay_alerts(device_id,assignment_id,event_id) WHERE event_id IS NOT NULL;
ALTER TABLE akay_alerts ADD COLUMN IF NOT EXISTS acknowledged_at timestamptz;
ALTER TABLE akay_alerts ADD COLUMN IF NOT EXISTS acknowledged_by uuid REFERENCES __USERS_TABLE__(user_id);
ALTER TABLE akay_alerts ADD COLUMN IF NOT EXISTS resolved_at timestamptz;
ALTER TABLE akay_alerts ADD COLUMN IF NOT EXISTS resolved_by uuid REFERENCES __USERS_TABLE__(user_id);
ALTER TABLE akay_alerts ADD COLUMN IF NOT EXISTS resolution text CHECK(resolution IN ('resolved','false_alarm'));
CREATE TABLE IF NOT EXISTS akay_alert_receipts (
 alert_id uuid REFERENCES akay_alerts(id) ON DELETE CASCADE,
 caregiver_id uuid REFERENCES __USERS_TABLE__(user_id),
 read_at timestamptz, dismissed_at timestamptz,
 PRIMARY KEY(alert_id,caregiver_id)
);
CREATE TABLE IF NOT EXISTS akay_push_tokens (
 token_hash text PRIMARY KEY, token text NOT NULL,
 caregiver_id uuid NOT NULL REFERENCES __USERS_TABLE__(user_id),
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE TABLE IF NOT EXISTS akay_alert_deliveries (
 alert_id uuid REFERENCES akay_alerts(id) ON DELETE CASCADE,
 token_hash text REFERENCES akay_push_tokens(token_hash) ON DELETE CASCADE,
 caregiver_id uuid NOT NULL REFERENCES __USERS_TABLE__(user_id),
 attempts integer NOT NULL DEFAULT 0, sent_at timestamptz,
 next_attempt_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 PRIMARY KEY(alert_id,token_hash,caregiver_id)
);
CREATE INDEX IF NOT EXISTS akay_alert_pending ON akay_alerts(created_at DESC) WHERE kind IN ('sos','motion') AND resolved_at IS NULL;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname='akay_runtime') THEN
  GRANT UPDATE(acknowledged_at,acknowledged_by,resolved_at,resolved_by,resolution) ON akay_alerts TO akay_runtime;
  GRANT SELECT,INSERT,UPDATE,DELETE ON akay_alert_receipts,akay_push_tokens,akay_alert_deliveries TO akay_runtime;
 END IF;
END $$;
COMMIT;
