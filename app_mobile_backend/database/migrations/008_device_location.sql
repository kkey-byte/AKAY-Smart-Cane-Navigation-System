-- Read-only RTDB ingestion; existing machine-authenticated telemetry is preserved.
BEGIN;
ALTER TABLE akay_readings ADD COLUMN IF NOT EXISTS source text NOT NULL DEFAULT 'hardware';
ALTER TABLE akay_readings ALTER COLUMN credential_id DROP NOT NULL;
ALTER TABLE akay_readings DROP CONSTRAINT IF EXISTS akay_reading_source;
ALTER TABLE akay_readings ADD CONSTRAINT akay_reading_source CHECK (
 (source='hardware' AND credential_id IS NOT NULL) OR
 (source='device_location' AND credential_id IS NULL));
CREATE UNIQUE INDEX IF NOT EXISTS akay_rtdb_reading_sequence
 ON akay_readings(assignment_id,sequence) WHERE source='device_location';
CREATE TABLE IF NOT EXISTS akay_device_location_state (
 assignment_id uuid PRIMARY KEY REFERENCES akay_assignments(id),
 sequence bigint NOT NULL DEFAULT 0,
 sos_active boolean NOT NULL DEFAULT false,
 fall_started_at timestamptz,
 fall_notified boolean NOT NULL DEFAULT false,
 payload jsonb,
 observed_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname='akay_runtime') THEN
  GRANT SELECT,INSERT,UPDATE ON akay_device_location_state TO akay_runtime;
 END IF;
END $$;
COMMIT;
