-- Dedicated account/app pairing records. Does not change Users or patientprofiles.
BEGIN;
SET LOCAL lock_timeout='5s';
CREATE TABLE IF NOT EXISTS pairing_app_instances (
 device_id uuid PRIMARY KEY,
 vi_user_id uuid NOT NULL REFERENCES __USERS_TABLE__(user_id),
 registered_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(device_id,vi_user_id)
);
CREATE TABLE IF NOT EXISTS pairings (
 pairing_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 device_id uuid NOT NULL,
 vi_user_id uuid NOT NULL REFERENCES __USERS_TABLE__(user_id),
 caregiver_id uuid REFERENCES __USERS_TABLE__(user_id),
 pairing_code varchar(6) NOT NULL UNIQUE CHECK(pairing_code ~ '^[A-HJ-NP-Z2-9]{6}$'),
 pairing_method varchar(16) NOT NULL CHECK(pairing_method IN ('qr_code','alphanumeric')),
 status varchar(16) NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','active','unpaired')),
 paired_at timestamptz,
 unpaired_at timestamptz,
 CHECK(vi_user_id IS DISTINCT FROM caregiver_id),
 CHECK(status<>'active' OR (caregiver_id IS NOT NULL AND paired_at IS NOT NULL AND unpaired_at IS NULL))
);
CREATE INDEX IF NOT EXISTS pairings_navigator ON pairings(vi_user_id);
CREATE INDEX IF NOT EXISTS pairings_caregiver ON pairings(caregiver_id);
-- Adapt the original pairings table, if present. An unclaimed code has no
-- caregiver yet, and an app instance must not invent physical-cane ownership.
ALTER TABLE pairings ALTER COLUMN caregiver_id DROP NOT NULL;
ALTER TABLE pairings ALTER COLUMN status SET DEFAULT 'pending';
ALTER TABLE pairings ALTER COLUMN paired_at DROP DEFAULT;
DO $$ DECLARE item record; BEGIN
 FOR item IN SELECT conname FROM pg_constraint
  WHERE conrelid='pairings'::regclass AND
   ((contype='c' AND (pg_get_constraintdef(oid) LIKE '%pairing_method%' OR pg_get_constraintdef(oid) LIKE '%status%'))
    OR (contype='f' AND (SELECT attnum FROM pg_attribute WHERE attrelid='pairings'::regclass AND attname='device_id')=ANY(conkey)))
 LOOP EXECUTE format('ALTER TABLE pairings DROP CONSTRAINT %I',item.conname); END LOOP;
END $$;
UPDATE pairings SET status=lower(status),pairing_method=CASE pairing_method
 WHEN 'QR_CODE' THEN 'qr_code' WHEN 'MANUAL_CODE' THEN 'alphanumeric' ELSE pairing_method END;
-- Preserve old records; inconsistent legacy ownership aborts rather than being
-- silently reassigned. Legacy NFC/Bluetooth/expired rows remain representable.
INSERT INTO pairing_app_instances(device_id,vi_user_id)
 SELECT DISTINCT device_id,vi_user_id FROM pairings ON CONFLICT(device_id) DO NOTHING;
ALTER TABLE pairings ADD CONSTRAINT pairings_app_owner
 FOREIGN KEY(device_id,vi_user_id) REFERENCES pairing_app_instances(device_id,vi_user_id);
ALTER TABLE pairings ADD CONSTRAINT pairings_method_allowed
 CHECK(pairing_method IN ('qr_code','alphanumeric','NFC','BLUETOOTH'));
ALTER TABLE pairings ADD CONSTRAINT pairings_status_allowed
 CHECK(status IN ('pending','active','unpaired','expired'));
ALTER TABLE pairings ADD CONSTRAINT pairings_active_metadata
 CHECK(status<>'active' OR (caregiver_id IS NOT NULL AND paired_at IS NOT NULL AND unpaired_at IS NULL));
-- Existing revoke endpoints continue working and also close the new audit row.
CREATE OR REPLACE FUNCTION akay_close_pairing_record() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF OLD.status='active' AND NEW.status<>'active' THEN
  UPDATE pairings SET status='unpaired',unpaired_at=clock_timestamp()
   WHERE vi_user_id=NEW.navigator_id AND caregiver_id=NEW.caregiver_id AND status='active';
 END IF;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS akay_close_pairing_record ON akay_connections;
CREATE TRIGGER akay_close_pairing_record AFTER UPDATE OF status ON akay_connections
 FOR EACH ROW EXECUTE FUNCTION akay_close_pairing_record();
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname='akay_runtime') THEN
  GRANT SELECT,INSERT,UPDATE ON pairings TO akay_runtime;
  GRANT SELECT,INSERT ON pairing_app_instances TO akay_runtime;
 END IF;
END $$;
COMMIT;
