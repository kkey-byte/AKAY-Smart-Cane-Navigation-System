-- Additive migration. __USERS_TABLE__ is resolved by the review/apply script.
-- No legacy link or phone-derived device identity is imported as verified.
BEGIN;
-- Fail rather than choosing an arbitrary profile for a duplicated Firebase UID.
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_index i JOIN pg_attribute a ON a.attrelid=i.indrelid AND a.attnum=i.indkey[0]
   WHERE i.indrelid='__USERS_TABLE__'::regclass AND a.attname='firebase_uid' AND i.indisunique AND i.indisvalid
   AND i.indnkeyatts=1 AND i.indpred IS NULL AND i.indexprs IS NULL) THEN
  CREATE UNIQUE INDEX akay_users_firebase_uid_unique ON __USERS_TABLE__(firebase_uid);
 END IF;
END $$;
CREATE TABLE IF NOT EXISTS akay_invitations (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 navigator_id uuid NOT NULL REFERENCES __USERS_TABLE__(user_id),
 code_hash text NOT NULL UNIQUE,
 expires_at timestamptz NOT NULL,
 redeemed_by uuid REFERENCES __USERS_TABLE__(user_id),
 redeemed_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS akay_connections (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 navigator_id uuid NOT NULL REFERENCES __USERS_TABLE__(user_id),
 caregiver_id uuid NOT NULL REFERENCES __USERS_TABLE__(user_id),
 status text NOT NULL CHECK(status IN ('pending','active','rejected','revoked','expired')),
 invitation_id uuid NOT NULL REFERENCES akay_invitations(id),
 requested_at timestamptz NOT NULL DEFAULT now(),
 expires_at timestamptz NOT NULL,
 consented_at timestamptz,
 revoked_at timestamptz,
 UNIQUE(navigator_id,caregiver_id),
 CHECK(navigator_id <> caregiver_id)
);
CREATE TABLE IF NOT EXISTS akay_rate_limits (
 actor text NOT NULL, action text NOT NULL, bucket bigint NOT NULL,
 attempts integer NOT NULL, PRIMARY KEY(actor,action,bucket)
);
CREATE TABLE IF NOT EXISTS akay_devices (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 serial text NOT NULL UNIQUE CHECK(length(serial) BETWEEN 1 AND 100),
 owner_id uuid REFERENCES __USERS_TABLE__(user_id),
 claim_hash text,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS akay_device_credentials (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 device_id uuid NOT NULL REFERENCES akay_devices(id),
 secret_hash text NOT NULL,
 last_sequence bigint NOT NULL DEFAULT -1,
 revoked_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS akay_one_device_credential ON akay_device_credentials(device_id) WHERE revoked_at IS NULL;
CREATE TABLE IF NOT EXISTS akay_ownership_history (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 device_id uuid NOT NULL REFERENCES akay_devices(id),
 owner_id uuid NOT NULL REFERENCES __USERS_TABLE__(user_id),
 started_at timestamptz NOT NULL DEFAULT now(), ended_at timestamptz
);
CREATE UNIQUE INDEX IF NOT EXISTS akay_one_owner ON akay_ownership_history(device_id) WHERE ended_at IS NULL;
CREATE TABLE IF NOT EXISTS akay_assignments (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 device_id uuid NOT NULL REFERENCES akay_devices(id),
 navigator_id uuid NOT NULL REFERENCES __USERS_TABLE__(user_id),
 assigned_by uuid NOT NULL REFERENCES __USERS_TABLE__(user_id),
 started_at timestamptz NOT NULL DEFAULT now(), ended_at timestamptz,
 UNIQUE(id,device_id,navigator_id)
);
CREATE UNIQUE INDEX IF NOT EXISTS akay_one_device_assignment ON akay_assignments(device_id) WHERE ended_at IS NULL;
-- Multiple canes per navigator and multiple caregivers per navigator are allowed.
CREATE TABLE IF NOT EXISTS akay_transfers (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 device_id uuid NOT NULL REFERENCES akay_devices(id),
 from_id uuid NOT NULL REFERENCES __USERS_TABLE__(user_id),
 to_id uuid NOT NULL REFERENCES __USERS_TABLE__(user_id),
 code_hash text NOT NULL UNIQUE, expires_at timestamptz NOT NULL,
created_at timestamptz NOT NULL DEFAULT now(),
 accepted_at timestamptz, CHECK(from_id <> to_id)
);
CREATE TABLE IF NOT EXISTS akay_readings (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 device_id uuid NOT NULL REFERENCES akay_devices(id),
 assignment_id uuid NOT NULL REFERENCES akay_assignments(id),
 navigator_id uuid NOT NULL REFERENCES __USERS_TABLE__(user_id),
 credential_id uuid NOT NULL REFERENCES akay_device_credentials(id),
 sequence bigint NOT NULL, received_at timestamptz NOT NULL DEFAULT now(),
 sampled_at timestamptz NOT NULL,
 latitude double precision CHECK(latitude BETWEEN -90 AND 90),
 longitude double precision CHECK(longitude BETWEEN -180 AND 180),
 battery integer CHECK(battery BETWEEN 0 AND 100),
 status text CHECK(status IN ('idle','moving','fault')),
 CHECK((latitude IS NULL) = (longitude IS NULL)),
 UNIQUE(credential_id,sequence),
 FOREIGN KEY(assignment_id,device_id,navigator_id) REFERENCES akay_assignments(id,device_id,navigator_id)
);
CREATE INDEX IF NOT EXISTS akay_reading_assignment ON akay_readings(assignment_id,received_at DESC);
CREATE TABLE IF NOT EXISTS akay_alerts (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 reading_id uuid NOT NULL REFERENCES akay_readings(id),
 navigator_id uuid NOT NULL REFERENCES __USERS_TABLE__(user_id),
 device_id uuid NOT NULL REFERENCES akay_devices(id),
 assignment_id uuid NOT NULL REFERENCES akay_assignments(id),
 kind text NOT NULL CHECK(kind IN ('sos','obstacle','battery_low','device_fault')),
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS akay_audit_events (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), actor_id uuid REFERENCES __USERS_TABLE__(user_id),
 action text NOT NULL, record_id uuid NOT NULL, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS akay_reconciliation (
 source text NOT NULL, legacy_key text NOT NULL, reason text NOT NULL,
 resolved_at timestamptz, PRIMARY KEY(source,legacy_key)
);
INSERT INTO akay_reconciliation(source,legacy_key,reason)
 SELECT 'users',user_id::text,'Missing Firebase identity or unrecognized role; reconcile without assigning another account'
 FROM __USERS_TABLE__ WHERE firebase_uid IS NULL OR role NOT IN ('caregiver','visually_impaired') ON CONFLICT DO NOTHING;
-- Preserve existing physical identities without asserting unverified ownership.
DO $$ BEGIN
 IF to_regclass('smartcanes') IS NOT NULL THEN
   IF EXISTS(SELECT 1 FROM smartcanes s JOIN akay_devices d
     ON d.id=s.device_id OR d.serial=s.serial_number
     WHERE d.id<>s.device_id OR d.serial<>s.serial_number) THEN
     RAISE EXCEPTION 'Legacy device identity conflict: reconcile UUID/serial mapping before migration';
   END IF;
   INSERT INTO akay_devices(id,serial)
     SELECT device_id,serial_number FROM smartcanes ON CONFLICT(id) DO NOTHING;
   INSERT INTO akay_reconciliation(source,legacy_key,reason)
     SELECT 'smartcanes',device_id::text,'Physical claim and credential provisioning required; registered_user_id is not imported as verified custody'
     FROM smartcanes ON CONFLICT DO NOTHING;
 END IF;
 IF to_regclass('pairings') IS NOT NULL THEN
   INSERT INTO akay_reconciliation(source,legacy_key,reason)
     SELECT 'pairings',pairing_id::text,'Renew invitation and navigator consent; old status/code does not prove new authorization'
     FROM pairings ON CONFLICT DO NOTHING;
 END IF;
 IF to_regclass('navigationsessions') IS NOT NULL THEN
   INSERT INTO akay_reconciliation(source,legacy_key,reason)
     SELECT 'navigationsessions',sessionid::text,'Keep historical user attribution; deviceid may identify a phone, not a physical cane'
     FROM navigationsessions ON CONFLICT DO NOTHING;
 END IF;
END $$;
CREATE OR REPLACE FUNCTION akay_permanent_device_id() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF NEW.id<>OLD.id THEN RAISE EXCEPTION 'Device ID is permanent'; END IF;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS akay_permanent_device_id ON akay_devices;
CREATE TRIGGER akay_permanent_device_id BEFORE UPDATE ON akay_devices FOR EACH ROW EXECUTE FUNCTION akay_permanent_device_id();
COMMIT;
