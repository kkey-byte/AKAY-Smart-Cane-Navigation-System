-- Apply with the migration/operator role before deploying the history service.
-- JSONB preserves existing wire models; each GPS point remains a separate row.
BEGIN;
SET LOCAL lock_timeout='5s';
CREATE TABLE IF NOT EXISTS akay_persistent_records (
  path text PRIMARY KEY,
  collection_path text NOT NULL,
  collection_name text NOT NULL CHECK (collection_name IN ('navigators','trips','points','records')),
  owner_uid text NOT NULL,
  data jsonb NOT NULL CHECK (jsonb_typeof(data)='object'),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX IF NOT EXISTS akay_persistent_parent ON akay_persistent_records(collection_path);
CREATE INDEX IF NOT EXISTS akay_trip_page ON akay_persistent_records
  (collection_path, ((data->>'startedAt')::bigint) DESC, path DESC) WHERE collection_name='trips';
CREATE INDEX IF NOT EXISTS akay_point_sequence ON akay_persistent_records
  (collection_path, ((data->>'sequence')::bigint)) WHERE collection_name='points';
CREATE INDEX IF NOT EXISTS akay_trip_retention ON akay_persistent_records
  (((data->>'endedAt')::bigint)) WHERE collection_name='trips';
CREATE INDEX IF NOT EXISTS akay_persistent_owner ON akay_persistent_records(owner_uid);
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname='akay_runtime') THEN
    GRANT SELECT,INSERT,UPDATE,DELETE ON akay_persistent_records TO akay_runtime;
  END IF;
END $$;
COMMIT;
